#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import Textual

@MainActor
struct TextBuilderLayoutTests {
  @Test(arguments: [0, 1, 3, 10_001])
  func attributedRunsCanBeLaidOut(count: Int) {
    var content = AttributedString()
    for index in 0..<count {
      var run = AttributedString("word ")
      run.foregroundColor = index.isMultiple(of: 2) ? .red : .blue
      content.append(run)
    }
    let text = Text.textualText(attributedString: content, in: .init())
    let view = NSHostingView(rootView: text.frame(width: 600))
    let size = view.fittingSize
    #expect(size.width == 600)
    let reference = NSHostingView(rootView: Text(content).frame(width: 600)).fittingSize
    #expect(size.height.isFinite)
    #expect(abs(size.height - reference.height) < 1)
  }
}
#endif
