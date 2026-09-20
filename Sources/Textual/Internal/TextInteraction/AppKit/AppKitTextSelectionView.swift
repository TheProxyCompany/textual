#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
  import SwiftUI

  // MARK: - Overview
  //
  // `AppKitTextSelectionView` renders selection highlights for a single `Text.Layout`.
  //
  // Each text fragment provides its own resolved layout and origin. The view reads the shared
  // `TextSelectionModel` from the environment, computes selection rectangles for the current
  // range within this layout, and paints them in a `Canvas` behind the text.

  struct AppKitTextSelectionView: View {
    @Environment(TextSelectionModel.self) private var textSelectionModel: TextSelectionModel?
    @State private var selectionRects: [TextSelectionRect] = []

    private let layout: Text.Layout
    private let origin: CGPoint

    init(layout: Text.Layout, origin: CGPoint) {
      self.layout = layout
      self.origin = origin
    }

    /// A fixed chromatic highlight stays visible in non-key panels, including
    /// when macOS uses the graphite accent. Never depend on key-window emphasis.
    static var selectionFillColor: NSColor {
      NSColor.systemBlue.withAlphaComponent(0.38)
    }

    var body: some View {
      Group {
        if selectionRects.isEmpty {
          Color.clear
        } else {
          Canvas { context, _ in
            context.translateBy(x: origin.x, y: origin.y)
            for selectionRect in selectionRects {
              context.fill(
                Path(selectionRect.rect.integral),
                with: .color(.init(nsColor: Self.selectionFillColor))
              )
              context.stroke(
                Path(selectionRect.rect.integral.insetBy(dx: 0.5, dy: 0.5)),
                with: .color(Color(nsColor: .systemBlue).opacity(0.65)),
                lineWidth: 1
              )
            }
          }
        }
      }
      .allowsHitTesting(false)
      .onChange(of: textSelectionModel?.selectedRange, initial: true, updateSelectionRects)
      .onChange(of: layout, initial: true, updateSelectionRects)
    }

    private func updateSelectionRects() {
      let nextRects: [TextSelectionRect]
      if let textSelectionModel,
        let selectedRange = textSelectionModel.selectedRange
      {
        nextRects = textSelectionModel.selectionRects(for: selectedRange, layout: layout)
      } else {
        nextRects = []
      }
      if selectionRects != nextRects {
        selectionRects = nextRects
      }
    }
  }
#endif
