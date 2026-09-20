import SwiftUI

// MARK: - Overview
//
// `TextSelectionBackground` draws selection highlights behind a `Text` fragment.
//
// The platform selection interaction stores a `TextSelectionModel` in the environment at fragment
// scope. This modifier reads the fragment’s anchored `Text.Layout` and forwards it to the AppKit
// selection view so it can convert the current selected range into highlight rectangles.

struct TextSelectionBackground: ViewModifier {
  #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
    @Environment(TextSelectionModel.self) private var textSelectionModel: TextSelectionModel?
  #endif

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
      // Keep the layout-producing subtree stable when selection changes.
      // Inserting the background only after selection recreates Text.Layout;
      // the highlight then refers to a layout absent from the shared model.
      if textSelectionModel != nil {
        content
          .backgroundPreferenceValue(Text.LayoutKey.self) { value in
            if let anchoredLayout = value.first {
              GeometryReader { geometry in
                AppKitTextSelectionView(
                  layout: anchoredLayout.layout,
                  origin: geometry[anchoredLayout.origin]
                )
              }
            }
          }
      } else {
        content
      }
    #else
      content
    #endif
  }
}
