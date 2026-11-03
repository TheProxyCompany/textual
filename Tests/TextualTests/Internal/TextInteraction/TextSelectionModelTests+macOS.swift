#if TEXTUAL_ENABLE_TEXT_SELECTION
  import Foundation
  import SwiftUI
  import Testing

  @testable import Textual

  extension TextSelectionModelTests {
    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordRange() throws {
      // given
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = TextPosition(
        indexPath: .init(runSlice: 2, run: 1, line: 0, layout: 0),
        affinity: .downstream
      )  // The 'm' in "sample"
      let expected = TextRange(
        start: .init(
          indexPath: .init(runSlice: 9, run: 0, line: 0, layout: 0),
          affinity: .upstream
        ),
        end: .init(
          indexPath: .init(runSlice: 5, run: 1, line: 0, layout: 0),
          affinity: .upstream
        )
      )

      // when
      let range = model.wordRange(for: position)

      // then
      #expect(range == expected)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func nextWordWithinLayout() throws {
      // given
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = TextPosition(
        indexPath: .init(runSlice: 2, run: 1, line: 0, layout: 0),
        affinity: .downstream
      )  // The 'm' in "sample"
      let expected = TextPosition(
        indexPath: .init(runSlice: 5, run: 1, line: 0, layout: 0),
        affinity: .upstream
      )

      // when
      let next = model.nextWord(from: position)

      // then
      #expect(next == expected)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func nextWordAcrossLayouts() throws {
      // given
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = TextPosition(
        indexPath: .init(runSlice: 0, run: 2, line: 1, layout: 0),
        affinity: .upstream
      )
      let expected = TextPosition(
        indexPath: .init(runSlice: 0, run: 0, line: 0, layout: 1),
        affinity: .downstream
      )

      // when
      let next = model.nextWord(from: position)

      // then
      #expect(next == expected)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func previousWordWithinLayout() throws {
      // given
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = TextPosition(
        indexPath: .init(runSlice: 0, run: 2, line: 0, layout: 0),
        affinity: .downstream
      )
      let expected = TextPosition(
        indexPath: .init(runSlice: 9, run: 0, line: 0, layout: 0),
        affinity: .upstream
      )

      // when
      let prev = model.previousWord(from: position)

      // then
      #expect(prev == expected)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func previousWordAcrossLayouts() throws {
      // given
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = TextPosition(
        indexPath: .init(runSlice: 0, run: 0, line: 0, layout: 1),
        affinity: .downstream
      )
      let expected = TextPosition(
        indexPath: .init(runSlice: 3, run: 0, line: 1, layout: 0),
        affinity: .upstream
      )

      // when
      let prev = model.previousWord(from: position)

      // then
      #expect(prev == expected)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordRangeAtPointAndPastLineBounds() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      // Hit inside "This" on line 0
      let wordHit = try #require(model.wordRange(at: CGPoint(x: 20, y: 25)))
      #expect(model.text(in: wordHit) == "This")

      // Past line bounds on line 1 (which ends well before x=280) returns nil
      #expect(model.wordRange(at: CGPoint(x: 280, y: 47)) == nil)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordDraggedRangeForwardAndBackward() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let samplePos = TextPosition(
        indexPath: .init(runSlice: 2, run: 1, line: 0, layout: 0),
        affinity: .downstream
      )
      let anchor = try #require(model.wordRange(for: samplePos))
      #expect(model.text(in: anchor) == "sample")

      let backwardTarget = model.startPosition
      let backwardRange = try #require(model.wordDraggedRange(anchor: anchor, to: backwardTarget))
      #expect(model.text(in: backwardRange) == "This is a sample")

      let forwardTarget = try #require(model.position(from: anchor.end, offset: 3))
      let forwardRange = try #require(model.wordDraggedRange(anchor: anchor, to: forwardTarget))
      #expect(model.text(in: forwardRange) == "sample paragraph")
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func multiLineSelectionRectsExtendToContainerWidth() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let range = TextRange(
        start: model.startPosition,
        end: TextPosition(
          indexPath: .init(runSlice: 0, run: 2, line: 1, layout: 0),
          affinity: .upstream
        )
      )
      let rects = model.selectionRects(for: range, containerWidth: 400)
      let firstLineRect = try #require(rects.first)
      #expect(firstLineRect.rect.maxX == 400)
    }

    @Test
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func closestPositionClampsAboveFirstAndBelowLastLine() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      #expect(model.closestPosition(to: CGPoint(x: 150, y: -10)) == model.startPosition)
      #expect(model.closestPosition(to: CGPoint(x: 50, y: 500)) == model.endPosition)
    }
  }
#endif
