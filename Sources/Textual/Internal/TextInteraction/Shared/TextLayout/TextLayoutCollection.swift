#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  protocol TextLayoutCollection {
    var layouts: [any TextLayout] { get }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool
    func index(of layout: Text.Layout) -> Int?
  }

  protocol TextLayout {
    var attributedString: NSAttributedString { get }
    var origin: CGPoint { get }
    var bounds: CGRect { get }
    var lines: [any TextLine] { get }
  }

  extension TextLayout {
    var frame: CGRect {
      bounds.offsetBy(dx: origin.x, dy: origin.y)
    }

    var runs: [any TextRun] {
      lines.flatMap(\.runs)
    }
  }

  protocol TextLine {
    var origin: CGPoint { get }
    var typographicBounds: CGRect { get }
    var runs: [any TextRun] { get }
  }

  protocol TextRun {
    var layoutDirection: LayoutDirection { get }
    var typographicBounds: CGRect { get }
    var url: URL? { get }
    var slices: [any TextRunSlice] { get }
  }

  protocol TextRunSlice {
    var typographicBounds: CGRect { get }
    var characterRange: Range<Int> { get }
  }

#endif
