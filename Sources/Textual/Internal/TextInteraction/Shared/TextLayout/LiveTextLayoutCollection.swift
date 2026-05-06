#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  final class LiveTextLayoutCollection: TextLayoutCollection {
    private(set) lazy var layouts: [any TextLayout] = makeLayouts()
    private lazy var selectionStructureSignature = SelectionStructureSignature(layouts: layouts)

    private let base: Text.LayoutKey.Value
    private let geometry: GeometryProxy

    init(base: Text.LayoutKey.Value, geometry: GeometryProxy) {
      self.base = base
      self.geometry = geometry
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      selectionStructureSignature
        != (other as? LiveTextLayoutCollection)?.selectionStructureSignature
    }

    func index(of layout: Text.Layout) -> Int? {
      layouts.firstIndex { textLayout in
        (textLayout as? LiveTextLayout)?.base == layout
      }
    }

    private func makeLayouts() -> [any TextLayout] {
      base
        // We are only interested in text fragments
        .filter(\.layout.isTextFragment)
        .map { anchoredLayout in
          LiveTextLayout(
            anchoredLayout: anchoredLayout,
            geometry: geometry
          )
        }
    }
  }

  final class LiveTextLayout: TextLayout {
    var attributedString: NSAttributedString {
      joinedAttributedString.joined
    }

    let origin: CGPoint

    private(set) lazy var bounds: CGRect = makeBounds()
    private(set) lazy var lines: [any TextLine] = makeLines()

    let base: Text.Layout

    private lazy var contents = base.materializeContents()
    private lazy var joinedAttributedString = contents.attributedStrings.joined()

    convenience init(
      anchoredLayout: Text.LayoutKey.AnchoredLayout,
      geometry: GeometryProxy
    ) {
      self.init(
        base: anchoredLayout.layout,
        origin: geometry[anchoredLayout.origin]
      )
    }

    init(base: Text.Layout, origin: CGPoint) {
      self.base = base
      self.origin = origin
    }

    private func makeBounds() -> CGRect {
      base.map(\.typographicBounds.rect)
        .reduce(CGRect.null, CGRectUnion)
    }

    private func makeLines() -> [any TextLine] {
      guard contents.attributedStrings.count > 1 else {
        return base.map {
          LiveTextLine(base: $0)
        }
      }

      // Get the offset mappings on the layout strings to maintain object identity
      let (_, characterOffsets) = contents.layoutAttributedStrings.joined()

      return zip(base, contents.lineFragments).compactMap { line, lineFragment in
        guard let offset = characterOffsets[.init(lineFragment.attributedString)] else {
          return nil
        }

        return LiveTextLine(base: line, offset: offset)
      }
    }
  }

  final class LiveTextLine: TextLine {
    var origin: CGPoint {
      base.origin
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    private(set) lazy var runs: [any TextRun] = makeRuns()

    let base: Text.Layout.Line
    let offset: Int

    init(base: Text.Layout.Line, offset: Int = 0) {
      self.base = base
      self.offset = offset
    }

    private func makeRuns() -> [any TextRun] {
      if base.isEmpty {
        // Return a newline run for empty lines
        return [
          EmptyRun(
            typographicBounds: base.typographicBounds.rect,
            slice: .init(
              typographicBounds: base.typographicBounds.rect,
              characterRange: offset..<(offset + 1)
            )
          )
        ]
      } else {
        return base.map { run in
          LiveTextRun(base: run, offset: offset)
        }
      }
    }
  }

  final class LiveTextRun: TextRun {
    var layoutDirection: LayoutDirection {
      base.layoutDirection
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    var url: URL? {
      base.url
    }

    private(set) lazy var slices: [any TextRunSlice] = makeRunSlices()

    let base: Text.Layout.Run
    let offset: Int

    init(base: Text.Layout.Run, offset: Int) {
      self.base = base
      self.offset = offset
    }

    private func makeRunSlices() -> [any TextRunSlice] {
      zip(base, base.characterRanges).map { slice, characterRange in
        LiveTextRunSlice(
          base: slice,
          characterRange: characterRange.offset(by: offset)
        )
      }
    }
  }

  struct EmptyRun: TextRun {
    let layoutDirection: LayoutDirection = .localeBased()
    let typographicBounds: CGRect
    let url: URL? = nil
    let slice: EmptyRunSlice

    var slices: [any TextRunSlice] {
      [slice]
    }
  }

  final class LiveTextRunSlice: TextRunSlice {
    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    let characterRange: Range<Int>
    let base: Text.Layout.RunSlice

    init(base: Text.Layout.RunSlice, characterRange: Range<Int>) {
      self.base = base
      self.characterRange = characterRange
    }
  }

  struct EmptyRunSlice: TextRunSlice {
    let typographicBounds: CGRect
    let characterRange: Range<Int>
  }

  private struct SelectionStructureSignature: Equatable {
    let layouts: [LayoutStructureSignature]

    init(layouts: [any TextLayout]) {
      self.layouts = layouts.map(LayoutStructureSignature.init)
    }
  }

  private struct LayoutStructureSignature: Equatable {
    let length: Int
    let bounds: QuantizedRect
    let lines: [LineStructureSignature]

    init(_ layout: any TextLayout) {
      self.length = layout.attributedString.length
      self.bounds = QuantizedRect(layout.bounds)
      self.lines = layout.lines.map(LineStructureSignature.init)
    }
  }

  private struct LineStructureSignature: Equatable {
    let origin: QuantizedPoint
    let bounds: QuantizedRect

    init(_ line: any TextLine) {
      self.origin = QuantizedPoint(line.origin)
      self.bounds = QuantizedRect(line.typographicBounds)
    }
  }

  private struct QuantizedPoint: Equatable {
    let x: Int64
    let y: Int64

    init(_ point: CGPoint) {
      self.x = Self.quantize(point.x)
      self.y = Self.quantize(point.y)
    }

    private static func quantize(_ value: CGFloat) -> Int64 {
      Int64((value * 1_000).rounded())
    }
  }

  private struct QuantizedRect: Equatable {
    let x: Int64
    let y: Int64
    let width: Int64
    let height: Int64

    init(_ rect: CGRect) {
      self.x = Self.quantize(rect.origin.x)
      self.y = Self.quantize(rect.origin.y)
      self.width = Self.quantize(rect.size.width)
      self.height = Self.quantize(rect.size.height)
    }

    private static func quantize(_ value: CGFloat) -> Int64 {
      Int64((value * 1_000).rounded())
    }
  }
#endif
