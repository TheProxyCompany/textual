import SwiftUI
import Testing

import Textual

extension StructuredText {
  @MainActor
  struct ListMarkerAlignmentTests {
    // A list marker sits beside the first line of its item. It used to center on the whole
    // item, so the marker of a wrapped item floated down to the middle of the paragraph.
    @Test func markerOfWrappedBulletSitsOnFirstLine() throws {
      let position = try markerPosition(
        markdown: "- \(Self.longItem)",
        view: { $0.textual.unorderedListMarker(RedMarker()) }
      )
      #expect(position.markerCenter < position.height / 3)
    }

    @Test func markerOfWrappedNumberedItemSitsOnFirstLine() throws {
      let position = try markerPosition(
        markdown: "1. \(Self.longItem)",
        view: { $0.textual.orderedListMarker(RedOrderedMarker()) }
      )
      #expect(position.markerCenter < position.height / 3)
    }

    @Test func markerOfItemWithNestedListSitsOnFirstLine() throws {
      let position = try markerPosition(
        markdown: """
          1. Parent
             - Child one
             - Child two
             - Child three
          """,
        view: {
          $0.textual.orderedListMarker(RedOrderedMarker())
            .textual.unorderedListMarker(ClearMarker())
        }
      )
      #expect(position.markerCenter < position.height / 3)
    }

    private static let longItem = Array(repeating: "wrapping words", count: 40)
      .joined(separator: " ")

    private func markerPosition(
      markdown: String,
      @ViewBuilder view: (StructuredText) -> some View
    ) throws -> (markerCenter: CGFloat, height: CGFloat) {
      let content = view(StructuredText(markdown: markdown))
        .foregroundStyle(.black)
        .frame(width: 300)
        .background(Color.white)
        .environment(\.colorScheme, .light)
      let renderer = ImageRenderer(content: content)
      renderer.scale = 1
      let image = try #require(renderer.cgImage)
      let rows = try #require(redRows(in: image))
      return (CGFloat(rows.lowerBound + rows.upperBound) / 2, CGFloat(image.height))
    }

    /// The range of pixel rows, counted from the top, that hold a pure red pixel.
    private func redRows(in image: CGImage) -> ClosedRange<Int>? {
      let width = image.width
      let height = image.height
      var pixels = [UInt8](repeating: 0, count: width * height * 4)
      let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard
          let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
      }
      guard drawn else { return nil }

      var first: Int?
      var last: Int?
      for row in 0..<height {
        for column in 0..<width {
          let offset = (row * width + column) * 4
          if pixels[offset] > 200, pixels[offset + 1] < 80, pixels[offset + 2] < 80 {
            first = first ?? row
            last = row
            break
          }
        }
      }
      guard let first, let last else { return nil }
      return first...last
    }
  }
}

private struct RedMarker: StructuredText.UnorderedListMarker {
  func makeBody(configuration: Configuration) -> some View {
    Color(red: 1, green: 0, blue: 0).frame(width: 6, height: 6)
  }
}

private struct RedOrderedMarker: StructuredText.OrderedListMarker {
  func makeBody(configuration: Configuration) -> some View {
    Color(red: 1, green: 0, blue: 0).frame(width: 6, height: 6)
  }
}

private struct ClearMarker: StructuredText.UnorderedListMarker {
  func makeBody(configuration: Configuration) -> some View {
    Color.clear.frame(width: 6, height: 6)
  }
}
