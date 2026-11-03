#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  extension TextLayoutCollection {
    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordRange(for position: TextPosition) -> TextRange? {
      guard layouts.indices.contains(position.indexPath.layout) else {
        return nil
      }
      let layout = layouts[position.indexPath.layout]
      let characterIndex = localCharacterIndex(at: position)

      guard
        let range = layout.wordRange(containing: characterIndex),
        let start = self.position(
          at: position.indexPath.layout,
          localCharacterIndex: range.lowerBound
        ),
        let end = self.position(
          at: position.indexPath.layout,
          localCharacterIndex: range.upperBound
        )
      else { return nil }

      return TextRange(start: start, end: end)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordRange(at point: CGPoint) -> TextRange? {
      guard !layouts.isEmpty else { return nil }
      let layoutIndex = layoutIndex(closestTo: point)
      let layout = layouts[layoutIndex]
      guard !layout.lines.isEmpty else { return nil }

      let localPoint = CGPoint(x: point.x - layout.origin.x, y: point.y - layout.origin.y)
      let lineIndex = layout.lineIndex(closestToY: localPoint.y)
      let line = layout.lines[lineIndex]

      // Native NSTextView returns empty selection when double-clicking past line bounds
      guard localPoint.x <= line.typographicBounds.maxX else { return nil }

      guard let charRange = characterRange(at: point) else { return nil }
      return wordRange(for: charRange.start)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordDraggedRange(anchor: TextRange, to position: TextPosition) -> TextRange? {
      if position < anchor.start {
        guard let targetWord = wordRange(for: position) else { return anchor }
        return TextRange(start: min(anchor.start, targetWord.start), end: anchor.end)
      } else if position > anchor.end {
        let probePosition = self.position(from: position, offset: -1) ?? position
        guard let targetWord = wordRange(for: probePosition) else { return anchor }
        return TextRange(start: anchor.start, end: max(anchor.end, targetWord.end))
      } else {
        return anchor
      }
    }

    func blockRange(for position: TextPosition) -> TextRange? {
      guard layouts.indices.contains(position.indexPath.layout) else {
        return nil
      }

      let layout = layouts[position.indexPath.layout]

      guard
        let line = layout.lines.last,
        let run = line.runs.last
      else {
        return nil
      }

      return TextRange(
        start: .init(
          indexPath: .init(layout: position.indexPath.layout),
          affinity: .downstream
        ),
        end: .init(
          indexPath: .init(
            runSlice: run.slices.endIndex - 1,
            run: line.runs.endIndex - 1,
            line: layout.lines.endIndex - 1,
            layout: position.indexPath.layout
          ),
          affinity: .upstream
        )
      )
    }

    func clampRange(_ range: TextRange, layoutIndex: Int) -> TextRange? {
      guard layouts.indices.contains(layoutIndex) else {
        return nil
      }

      let layout = layouts[layoutIndex]

      guard
        let lastLine = layout.lines.last,
        let lastRun = lastLine.runs.last
      else {
        return nil
      }

      let start = TextPosition(
        indexPath: .init(layout: layoutIndex),
        affinity: .downstream
      )
      let end = TextPosition(
        indexPath: .init(
          runSlice: lastRun.slices.endIndex - 1,
          run: lastLine.runs.endIndex - 1,
          line: layout.lines.endIndex - 1,
          layout: layoutIndex
        ),
        affinity: .upstream
      )

      guard range.end > start && range.start < end else {
        return nil
      }

      return TextRange(
        start: Swift.max(range.start, start),
        end: Swift.min(range.end, end)
      )
    }
  }
#endif
