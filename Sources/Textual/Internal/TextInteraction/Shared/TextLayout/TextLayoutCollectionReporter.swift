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
        onUpdate(layoutCollection)
      }

      final class ReportingView: NSView {
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
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
      }

      func updateUIView(_ uiView: UIView, context: Context) {
        onUpdate(layoutCollection)
      }
    }
  #endif
#endif
