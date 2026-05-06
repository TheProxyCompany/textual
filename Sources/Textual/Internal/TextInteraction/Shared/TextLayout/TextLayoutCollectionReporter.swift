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
        let layoutCollectionID = ObjectIdentifier(layoutCollection)
        guard nsView.layoutCollectionID != layoutCollectionID else {
          return
        }
        nsView.layoutCollectionID = layoutCollectionID
        onUpdate(layoutCollection)
      }

      final class ReportingView: NSView {
        var layoutCollectionID: ObjectIdentifier?

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
        let layoutCollectionID = ObjectIdentifier(layoutCollection)
        guard (uiView as? ReportingView)?.layoutCollectionID != layoutCollectionID else {
          return
        }
        (uiView as? ReportingView)?.layoutCollectionID = layoutCollectionID
        onUpdate(layoutCollection)
      }

      final class ReportingView: UIView {
        var layoutCollectionID: ObjectIdentifier?
      }
    }
  #endif
#endif
