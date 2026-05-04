#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  struct EmptyTextLayoutCollection: TextLayoutCollection {
    var layouts: [any TextLayout] {
      []
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      false
    }

    func index(of layout: Text.Layout) -> Int? {
      nil
    }
  }
#endif
