#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  #if canImport(AppKit)
    import AppKit

    struct TextLayoutCollectionReporter: NSViewRepresentable {
      let layoutCollection: any TextLayoutCollection
      let onUpdate: (any TextLayoutCollection) -> Void

      func makeNSView(context: Context) -> ReportingView {
        ReportingView()
      }

      func updateNSView(_ nsView: ReportingView, context: Context) {
        // Identity guards are useless here: `LiveTextLayoutCollection` is allocated
        // fresh per body, so ObjectIdentifier always differs. Compare by structure
        // signature instead — if the layouts didn't meaningfully change, skip the work.
        if let existing = nsView.layoutCollection,
          !layoutCollection.needsPositionReconciliation(with: existing) {
          nsView.layoutCollection = layoutCollection
          return
        }
        nsView.layoutCollection = layoutCollection
        onUpdate(layoutCollection)
      }

      final class ReportingView: NSView {
        var layoutCollection: (any TextLayoutCollection)?

        override func hitTest(_ point: NSPoint) -> NSView? {
          nil
        }
      }
    }
  #elseif canImport(UIKit)
    import UIKit

    struct TextLayoutCollectionReporter: UIViewRepresentable {
      let layoutCollection: any TextLayoutCollection
      let onUpdate: (any TextLayoutCollection) -> Void

      func makeUIView(context: Context) -> UIView {
        let view = ReportingView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
      }

      func updateUIView(_ uiView: UIView, context: Context) {
        guard let reportingView = uiView as? ReportingView else {
          return
        }
        if let existing = reportingView.layoutCollection,
          !layoutCollection.needsPositionReconciliation(with: existing) {
          reportingView.layoutCollection = layoutCollection
          return
        }
        reportingView.layoutCollection = layoutCollection
        onUpdate(layoutCollection)
      }

      final class ReportingView: UIView {
        var layoutCollection: (any TextLayoutCollection)?
      }
    }
  #endif
#endif
