#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
  import AppKit
  import SwiftUI
  import Testing
  @testable import Textual

  @Suite(.serialized) @MainActor
  struct TextContextMenuTests {
    private func event() throws -> NSEvent {
      try #require(NSEvent.mouseEvent(
        with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0
      ))
    }

    private func view(_ model: TextSelectionModel) -> NSTextInteractionView {
      NSTextInteractionView(model: model, exclusionRects: [], openURL: OpenURLAction { _ in .handled })
    }

    @Test func rightClickWithoutSelectionCopiesBothParagraphs() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let view = view(model)
      let menu = try #require(view.menu(for: event()))
      let range = TextRange(start: model.startPosition, end: model.endPosition)
      #expect(model.selectedRange == range)
      let copy = try #require(menu.items.first { $0.title == "Copy" })
      view.perform(try #require(copy.action), with: nil)
      #expect(NSPasteboard.general.string(forType: .string) == Formatter(model.attributedText(in: range)).plainText())
      #expect(NSPasteboard.general.string(forType: .html) != nil)
    }

    @Test func rightClickPreservesSelectionAndCopyAllDoesNotChangeIt() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let selection = try #require(model.wordRange(for: model.startPosition))
      model.selectedRange = selection
      let view = view(model)
      let menu = try #require(view.menu(for: event()))
      #expect(model.selectedRange == selection)
      let copy = try #require(menu.items.first { $0.title == "Copy" })
      view.perform(try #require(copy.action), with: nil)
      #expect(NSPasteboard.general.string(forType: .string) == Formatter(model.attributedText(in: selection)).plainText())
      let copyAll = try #require(menu.items.first { $0.title == "Copy All" })
      view.perform(try #require(copyAll.action), with: nil)
      let range = TextRange(start: model.startPosition, end: model.endPosition)
      #expect(NSPasteboard.general.string(forType: .string) == Formatter(model.attributedText(in: range)).plainText())
      #expect(model.selectedRange == selection)
    }

    @Test func emptyContentHasNoCopyActions() throws {
      let model = try TextSelectionModel(fixtureName: "empty")
      #expect(try view(model).menu(for: event())?.items.isEmpty == true)
    }

    @Test func doubleClickDragTripleClickDragShiftClickAndLinkMouseUp() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      var openedURLs: [URL] = []
      let view = NSTextInteractionView(
        model: model,
        exclusionRects: [],
        openURL: OpenURLAction { url in
          openedURLs.append(url)
          return .handled
        }
      )
      view.frame = NSRect(x: 0, y: 0, width: 400, height: 200)

      func mouseEvent(
        _ type: NSEvent.EventType,
        at point: CGPoint,
        clickCount: Int = 1,
        modifiers: NSEvent.ModifierFlags = []
      ) throws -> NSEvent {
        try #require(
          NSEvent.mouseEvent(
            with: type,
            location: view.convert(point, to: nil),
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: clickCount,
            pressure: 1
          )
        )
      }

      // 1. Double-click on "This" and drag to "sample" expands word-by-word
      view.mouseDown(with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 20, y: 25), clickCount: 2))
      #expect(model.selectedRange.map { model.text(in: $0) } == "This")
      view.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 95, y: 25), clickCount: 2))
      view.mouseUp(with: try mouseEvent(.leftMouseUp, at: CGPoint(x: 95, y: 25), clickCount: 2))
      #expect(model.selectedRange.map { model.text(in: $0) } == "This is a sample")

      // 2. Shift+click extends selection
      view.mouseDown(
        with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 160, y: 25), clickCount: 1, modifiers: [.shift])
      )
      view.mouseUp(
        with: try mouseEvent(.leftMouseUp, at: CGPoint(x: 160, y: 25), clickCount: 1, modifiers: [.shift])
      )
      #expect(model.selectedRange.map { model.text(in: $0) } == "This is a sample paragraph")

      // 3. Triple-click on first paragraph and drag to second paragraph selects both blocks
      view.mouseDown(with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 20, y: 25), clickCount: 3))
      let firstBlock = try #require(model.blockRange(for: model.startPosition))
      #expect(model.selectedRange == firstBlock)
      view.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 30, y: 82), clickCount: 3))
      view.mouseUp(with: try mouseEvent(.leftMouseUp, at: CGPoint(x: 30, y: 82), clickCount: 3))
      #expect(model.selectedRange == TextRange(start: model.startPosition, end: model.endPosition))

      // 4. Dragging across a link selects text without opening URL; clicking without dragging opens on mouseUp
      let linkPoint = CGPoint(x: 276, y: 25)
      view.mouseDown(with: try mouseEvent(.leftMouseDown, at: linkPoint, clickCount: 1))
      #expect(openedURLs.isEmpty)
      view.mouseDragged(with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 20, y: 25), clickCount: 1))
      view.mouseUp(with: try mouseEvent(.leftMouseUp, at: CGPoint(x: 20, y: 25), clickCount: 1))
      #expect(openedURLs.isEmpty)
      #expect(model.selectedRange?.isCollapsed == false)

      view.mouseDown(with: try mouseEvent(.leftMouseDown, at: linkPoint, clickCount: 1))
      #expect(openedURLs.isEmpty)
      view.mouseUp(with: try mouseEvent(.leftMouseUp, at: linkPoint, clickCount: 1))
      #expect(openedURLs == [URL(string: "https://example.com")!])
    }
  }
#endif
