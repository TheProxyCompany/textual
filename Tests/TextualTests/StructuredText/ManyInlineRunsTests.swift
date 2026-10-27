import SwiftUI
import Testing

import Textual

extension StructuredText {
  @MainActor
  struct ManyInlineRunsTests {
    // A paragraph with thousands of styled runs used to overflow the stack
    // while SwiftUI resolved the joined Text.
    @Test func paragraphWithThousandsOfRunsRenders() {
      let markdown = (0..<3000).map { "**b\($0)** `c\($0)`" }.joined(separator: " ")
      let view = StructuredText(markdown: markdown).frame(width: 800)
      let renderer = ImageRenderer(content: view)
      #expect(renderer.cgImage != nil)
    }
  }
}
