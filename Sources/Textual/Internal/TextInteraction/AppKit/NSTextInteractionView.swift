#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
  import SwiftUI

  // MARK: - Overview
  //
  // `NSTextInteractionView` implements selection and link interaction on macOS.
  //
  // The view sits in an overlay above one or more rendered `Text` fragments. It uses
  // `TextSelectionModel` for hit testing and range manipulation, and it respects `exclusionRects`
  // so embedded scrollable regions continue to receive input events. Link taps are forwarded to
  // `openURL`.

  final class NSTextInteractionView: NSView {
    private enum SelectionGranularity {
      case character
      case word
      case paragraph
    }

    var model: TextSelectionModel {
      didSet {
        guard oldValue !== model else { return }
        oldValue.interactionLayoutDidChange = nil
        observeLayout()
      }
    }
    var exclusionRects: [CGRect]
    var openURL: OpenURLAction

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    private var dragAnchorRange: TextRange?
    private var selectionGranularity: SelectionGranularity = .character
    private var selectionAnchor: TextPosition?
    private var pendingLinkURL: URL?

    init(
      model: TextSelectionModel,
      exclusionRects: [CGRect],
      openURL: OpenURLAction
    ) {
      self.model = model
      self.exclusionRects = exclusionRects
      self.openURL = openURL

      super.init(frame: .zero)
      self.wantsLayer = true
      observeLayout()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func observeLayout() {
      model.interactionLayoutDidChange = { [weak self] in
        if let self { self.window?.invalidateCursorRects(for: self) }
      }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      let localPoint = convert(point, from: superview)
      let isExcluded = exclusionRects.contains {
        $0.contains(localPoint)
      }

      if isExcluded {
        return nil
      }

      if !model.hitsTextContent(at: localPoint) {
        return nil
      }

      return super.hitTest(point)
    }

    override func resetCursorRects() {
      discardCursorRects()
      for layout in model.textContentRects() {
        addCursorRect(layout, cursor: .iBeam)
      }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      let location = convert(event.locationInWindow, from: nil)
      pendingLinkURL = nil

      if event.modifierFlags.contains(.shift), let existingRange = model.selectedRange {
        let anchor = selectionAnchor ?? existingRange.start
        selectionAnchor = anchor
        if dragAnchorRange == nil {
          dragAnchorRange = TextRange(start: anchor, end: anchor)
        }
        extendSelection(to: location)
        return
      }

      switch event.clickCount {
      case 1:
        pendingLinkURL = model.url(for: location)
        resetSelection()
        selectionGranularity = .character
        if let position = model.closestPosition(to: location) {
          let collapsed = TextRange(start: position, end: position)
          dragAnchorRange = collapsed
          selectionAnchor = position
          model.selectedRange = collapsed
        }
      case 2:
        selectionGranularity = .word
        if let wordRange = model.wordRange(at: location) {
          dragAnchorRange = wordRange
          selectionAnchor = wordRange.start
          model.selectedRange = wordRange
        } else {
          dragAnchorRange = nil
        }
      case 3:
        selectionGranularity = .paragraph
        if let position = model.closestPosition(to: location),
          let blockRange = model.blockRange(for: position)
        {
          dragAnchorRange = blockRange
          selectionAnchor = blockRange.start
          model.selectedRange = blockRange
        } else {
          dragAnchorRange = nil
        }
      default:
        break
      }
    }

    override func mouseDragged(with event: NSEvent) {
      pendingLinkURL = nil
      let location = convert(event.locationInWindow, from: nil)
      extendSelection(to: location)
      autoscroll(with: event)
    }

    override func mouseUp(with event: NSEvent) {
      if let url = pendingLinkURL, model.selectedRange?.isCollapsed ?? true {
        openURL(url)
      }
      pendingLinkURL = nil
    }

    private func extendSelection(to location: CGPoint) {
      guard let dragAnchorRange else {
        return
      }

      switch selectionGranularity {
      case .character:
        guard let currentPosition = model.closestPosition(to: location) else {
          return
        }
        selectionAnchor = dragAnchorRange.start
        model.selectedRange = TextRange(from: dragAnchorRange.start, to: currentPosition)
      case .word:
        guard let currentPosition = model.closestPosition(to: location) else {
          return
        }
        if let extended = model.wordDraggedRange(anchor: dragAnchorRange, to: currentPosition) {
          selectionAnchor =
            currentPosition < dragAnchorRange.start ? dragAnchorRange.end : dragAnchorRange.start
          model.selectedRange = extended
        }
      case .paragraph:
        guard
          let currentPosition = model.closestPosition(to: location),
          let targetBlock = model.blockRange(for: currentPosition)
        else {
          return
        }
        selectionAnchor =
          currentPosition < dragAnchorRange.start ? dragAnchorRange.end : dragAnchorRange.start
        model.selectedRange = TextRange(
          start: min(dragAnchorRange.start, targetBlock.start),
          end: max(dragAnchorRange.end, targetBlock.end)
        )
      }
    }

    override func rightMouseDown(with event: NSEvent) {
      let location = convert(event.locationInWindow, from: nil)
      updateSelectionForContextMenu(at: location)

      NSMenu.popUpContextMenu(makeContextMenu(), with: event, for: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
      let location = convert(event.locationInWindow, from: nil)
      updateSelectionForContextMenu(at: location)

      return makeContextMenu()
    }

    override func selectAll(_ sender: Any?) {
      let fullRange = TextRange(start: model.startPosition, end: model.endPosition)
      selectionGranularity = .character
      selectionAnchor = fullRange.start
      dragAnchorRange = TextRange(start: fullRange.start, end: fullRange.start)
      model.selectedRange = fullRange
    }

    override func keyDown(with event: NSEvent) {
      interpretKeyEvents([event])
    }

    override func moveRightAndModifySelection(_ sender: Any?) {
      modifySelection { position, _ in
        model.position(from: position, offset: 1)
      }
    }

    override func moveLeftAndModifySelection(_ sender: Any?) {
      modifySelection { position, _ in
        model.position(from: position, offset: -1)
      }
    }

    override func moveUpAndModifySelection(_ sender: Any?) {
      modifySelection { position, anchor in
        model.positionAbove(position, anchor: anchor)
      }
    }

    override func moveDownAndModifySelection(_ sender: Any?) {
      modifySelection { position, anchor in
        model.positionBelow(position, anchor: anchor)
      }
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
      modifySelection { position, _ in
        model.nextWord(from: position)
      }
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
      modifySelection { position, _ in
        model.previousWord(from: position)
      }
    }

    override func moveParagraphBackwardAndModifySelection(_ sender: Any?) {
      modifySelection { position, _ in
        model.blockStart(for: position)
      }
    }

    override func moveParagraphForwardAndModifySelection(_ sender: Any?) {
      modifySelection { position, _ in
        model.blockEnd(for: position)
      }
    }

    private func updateSelectionForContextMenu(at location: CGPoint) {
      window?.makeFirstResponder(self)
      // Right-click must not replace a deliberate selection with a single word.
      // With no selection, Copy operates on the entire rendered message.
      if let range = model.selectedRange, !range.isCollapsed { return }
      selectAll(nil)
    }

    private func makeContextMenu() -> NSMenu {
      let menu = NSMenu()
      guard model.hasText else { return menu }

      let copy = NSMenuItem(
        title: NSLocalizedString("Copy", bundle: .main, comment: ""),
        action: #selector(copy(_:)), keyEquivalent: ""
      )
      copy.target = self
      menu.addItem(copy)
      let copyAll = NSMenuItem(
        title: NSLocalizedString("Copy All", bundle: .main, comment: "Copy all rendered text"),
        action: #selector(copyAll(_:)), keyEquivalent: ""
      )
      copyAll.target = self
      menu.addItem(copyAll)
      let selectAll = NSMenuItem(
        title: NSLocalizedString("Select All", bundle: .main, comment: ""),
        action: #selector(selectAll(_:)), keyEquivalent: ""
      )
      selectAll.target = self
      menu.addItem(selectAll)
      menu.addItem(.separator())
      let share = NSMenuItem(
        title: NSSharingServicePicker(items: []).standardShareMenuItem.title,
        action: #selector(share(_:)), keyEquivalent: ""
      )
      share.target = self
      menu.addItem(share)
      return menu
    }

    private func modifySelection(
      _ transform: (_ position: TextPosition, _ anchor: TextPosition) -> TextPosition?
    ) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      // set anchor on first move
      selectionAnchor = selectionAnchor ?? selectedRange.start

      guard let selectionAnchor else {
        return
      }

      // modify the non-anchor end of the selection
      let position =
        selectionAnchor == selectedRange.start
        ? selectedRange.end
        : selectedRange.start

      guard let newPosition = transform(position, selectionAnchor) else {
        return
      }
      selectionGranularity = .character
      dragAnchorRange = TextRange(start: selectionAnchor, end: selectionAnchor)
      model.selectedRange = TextRange(from: selectionAnchor, to: newPosition)

      // scroll to make the new position visible
      let caretRect = model.caretRect(for: newPosition)
      scrollToVisible(caretRect)
    }

    private func resetSelection() {
      model.selectedRange = nil
      selectionAnchor = nil
      dragAnchorRange = nil
      selectionGranularity = .character
    }

    @objc private func share(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let transferableText = TransferableText(attributedString: attributedText)
      let itemProvider = NSItemProvider(object: transferableText)

      let sharingPicker = NSSharingServicePicker(items: [itemProvider])
      let rect =
        model.selectionRects(for: selectedRange)
        .last?.rect.integral ?? .zero

      sharingPicker.show(relativeTo: rect, of: self, preferredEdge: .maxY)
    }

    @objc private func copy(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      copy(range: selectedRange)
    }

    @objc private func copyAll(_ sender: Any?) {
      copy(range: TextRange(start: model.startPosition, end: model.endPosition))
    }

    private func copy(range: TextRange) {
      let attributedText = model.attributedText(in: range)

      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()

      let formatter = Formatter(attributedText)
      pasteboard.setString(formatter.plainText(), forType: .string)
      pasteboard.setString(formatter.html(), forType: .html)
    }
  }

  extension NSTextInteractionView: NSUserInterfaceValidations {
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
      switch item.action {
      case #selector(selectAll(_:)), #selector(copyAll(_:)):
        return model.hasText
      case #selector(copy(_:)):
        guard let selectedRange = model.selectedRange else {
          return false
        }
        return !selectedRange.isCollapsed
      case #selector(moveRightAndModifySelection(_:)),
        #selector(moveLeftAndModifySelection(_:)),
        #selector(moveUpAndModifySelection(_:)),
        #selector(moveDownAndModifySelection(_:)),
        #selector(moveWordRightAndModifySelection(_:)),
        #selector(moveWordLeftAndModifySelection(_:)),
        #selector(moveParagraphBackwardAndModifySelection(_:)),
        #selector(moveParagraphForwardAndModifySelection(_:)):
        return model.selectedRange != nil
      default:
        return true
      }
    }
  }
#endif
