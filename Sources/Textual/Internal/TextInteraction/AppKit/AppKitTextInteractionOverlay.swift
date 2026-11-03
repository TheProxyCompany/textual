#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
  import SwiftUI

  // MARK: - Overview
  //
  // `AppKitTextInteractionOverlay` bridges the shared `TextSelectionModel` into an `NSView`.
  //
  // The overlay reads exclusion rectangles for hit-testing. This allows embedded scrollable regions (like
  // code blocks) to receive touch events while the parent handles text selection. The view also
  // manages selection gestures, keyboard-driven updates, and context menus while SwiftUI renders
  // the text.

  struct AppKitTextInteractionOverlay: NSViewRepresentable {
    private let model: TextSelectionModel
    private let overflowFrames: [CGRect]

    init(model: TextSelectionModel, overflowFrames: [CGRect]) {
      self.model = model
      self.overflowFrames = overflowFrames
    }

    func makeNSView(context: Context) -> NSTextInteractionView {
      NSTextInteractionView(
        model: model,
        exclusionRects: overflowFrames,
        openURL: context.environment.openURL
      )
    }

    func updateNSView(_ nsView: NSTextInteractionView, context: Context) {
      if nsView.model !== model {
        nsView.model = model
        nsView.window?.invalidateCursorRects(for: nsView)
      }
      if nsView.exclusionRects != overflowFrames {
        nsView.exclusionRects = overflowFrames
        nsView.window?.invalidateCursorRects(for: nsView)
      }
      nsView.openURL = context.environment.openURL
    }
  }

  struct AppKitTextInteractionBackground: NSViewRepresentable {
    private let model: TextSelectionModel
    private let overflowFrames: [CGRect]

    init(model: TextSelectionModel, overflowFrames: [CGRect]) {
      self.model = model
      self.overflowFrames = overflowFrames
    }

    func makeNSView(context: Context) -> NSTextSelectionBackgroundView {
      NSTextSelectionBackgroundView(
        model: model,
        exclusionRects: overflowFrames
      )
    }

    func updateNSView(_ nsView: NSTextSelectionBackgroundView, context: Context) {
      if nsView.model !== model {
        nsView.model = model
      }
      if nsView.exclusionRects != overflowFrames {
        nsView.exclusionRects = overflowFrames
        nsView.needsDisplay = true
      }
    }
  }

  final class NSTextSelectionBackgroundView: NSView {
    var model: TextSelectionModel {
      didSet {
        guard oldValue !== model else { return }
        oldValue.selectionDidChange = nil
        oldValue.layoutDidChange = nil
        observeSelection()
        needsDisplay = true
      }
    }
    var exclusionRects: [CGRect]

    override var isFlipped: Bool { true }

    init(model: TextSelectionModel, exclusionRects: [CGRect]) {
      self.model = model
      self.exclusionRects = exclusionRects
      super.init(frame: .zero)
      self.wantsLayer = true
      observeSelection()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }

    private func observeSelection() {
      model.selectionDidChange = { [weak self] in self?.needsDisplay = true }
      model.layoutDidChange = { [weak self] in self?.needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
      guard let range = model.selectedRange, !range.isCollapsed else { return }
      NSGraphicsContext.saveGraphicsState()
      defer { NSGraphicsContext.restoreGraphicsState() }
      let clip = NSBezierPath(rect: bounds)
      for rect in exclusionRects { clip.appendRect(rect) }
      clip.windingRule = .evenOdd
      clip.addClip()

      effectiveAppearance.performAsCurrentDrawingAppearance {
        NSColor.selectedTextBackgroundColor.setFill()
      }
      for selection in model.selectionRects(for: range, containerWidth: bounds.width) {
        var r = selection.rect
        let minY = floor(r.minY)
        let maxY = ceil(r.maxY)
        r.origin.y = minY
        r.size.height = max(0, maxY - minY)
        r.fill()
      }
    }
  }
#endif
