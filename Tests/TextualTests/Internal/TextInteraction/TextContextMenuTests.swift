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
  }
#endif
