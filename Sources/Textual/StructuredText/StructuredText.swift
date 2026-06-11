import Foundation
import SwiftUI

/// A view that displays rich, structured text.
///
/// `StructuredText` renders block elements like paragraphs, headings, lists, block quotes, code
/// blocks, and tables from a markup string. The markup is parsed with a ``MarkupParser`` into an
/// `AttributedString` that Textual can lay out and display.
///
/// The simplest way to create a `StructuredText` view is to pass Markdown:
///
/// ```swift
/// let markdown = """
/// ## Getting Started
///
/// Before making changes, check a few things:
///
/// - Skim recent commits
/// - Run the tests
/// - Make your changes
///
/// Leave a note if something needs attention later.
/// """
///
/// var body: some View {
///   StructuredText(markdown: markdown)
/// }
/// ```
///
/// ### Customizing Text Appearance
///
/// `StructuredText` supports standard SwiftUI text modifiers like `.font()`, `.foregroundStyle()`,
/// and `.multilineTextAlignment()`. Note that `.lineLimit()` is explicitly disabled to prevent
/// per-block truncation, which would break the document layout.
///
/// ```swift
/// StructuredText(markdown: "## Hello\n\nThis is a paragraph.")
///   .font(.callout)
///   .foregroundStyle(.blue)
///   .multilineTextAlignment(.center)
/// ```
///
/// ### Styling Structured Text
///
/// You can apply a full style preset using the ``TextualNamespace/structuredTextStyle(_:)`` modifier.
///
/// ```swift
/// StructuredText(markdown: markdown)
///   .textual.structuredTextStyle(.gitHub)
/// ```
///
/// For more control, you can customize individual block and inline styles. Inline styles
/// apply to spans like emphasis and links. Block styles apply to structural elements:
///
/// - ``TextualNamespace/headingStyle(_:)``, ``TextualNamespace/paragraphStyle(_:)``,
///   ``TextualNamespace/blockQuoteStyle(_:)``, ``TextualNamespace/thematicBreakStyle(_:)``
/// - ``TextualNamespace/listItemStyle(_:)``, ``TextualNamespace/unorderedListMarker(_:)``,
///   ``TextualNamespace/orderedListMarker(_:)``
/// - ``TextualNamespace/codeBlockStyle(_:)``, ``TextualNamespace/highlighterTheme(_:)``
/// - ``TextualNamespace/tableStyle(_:)``, ``TextualNamespace/tableCellStyle(_:)``
///
/// Code blocks and tables may overflow horizontally. You can choose between scrolling and
/// wrapping with ``TextualNamespace/overflowMode(_:)``.
///
/// ```swift
/// StructuredText(markdown: markdown)
///   .textual.overflowMode(.wrap)
/// ```
///
/// ### Interaction
///
/// When the markup contains links, `StructuredText` uses SwiftUI’s `openURL` environment. Provide a
/// custom `OpenURLAction` to intercept them (for example, to route in-app or to scroll to anchors).
///
/// You can enable text selection with ``TextualNamespace/textSelection(_:)`` to let users select
/// text in a platform-appropriate way.
///
/// ```swift
/// StructuredText(markdown: markdown)
///   .environment(
///     \.openURL,
///     OpenURLAction { url in
///       print("Open \(url)")
///       return .handled
///     }
///   )
///   .textual.textSelection(.enabled)
/// ```
///
/// ### Images, links, and relative URLs
///
/// If your Markdown includes relative image URLs or links, provide a `baseURL`. To render images,
/// configure an attachment loader using the ``TextualNamespace/imageAttachmentLoader(_:)``
/// modifier.
///
/// ```swift
/// let baseURL = URL(string: "https://example.com/repo/")!
///
/// StructuredText(markdown: readme, baseURL: baseURL)
///   .textual.imageAttachmentLoader(.image(relativeTo: baseURL))
/// ```
///
/// When you need to parse something other than Markdown, use ``init(_:parser:)`` with a custom
/// ``MarkupParser`` implementation.
public struct StructuredText: View {
  @State private var attributedString = AttributedString()

  private let markup: String
  private let parser: any MarkupParser
  private let cacheKey: String?

  /// Creates a structured-text view by parsing `markup` with a custom parser.
  ///
  /// Use this initializer when you want to provide your own `MarkupParser` implementation.
  public init(_ markup: String, parser: any MarkupParser) {
    self.init(markup, parser: parser, cacheKey: nil)
  }

  /// - Parameter cacheKey: When non-nil, the parsed result is cached and reused under this key.
  ///   The key must uniquely identify BOTH the markup content AND the parser configuration that
  ///   produced it; only the default-config `markdown` convenience path may safely supply one.
  init(_ markup: String, parser: any MarkupParser, cacheKey: String?) {
    self.markup = markup
    self.parser = parser
    self.cacheKey = cacheKey
    self._attributedString = State(
      initialValue: Self.parse(markup, parser: parser, cacheKey: cacheKey)
    )
  }

  public var body: some View {
    WithAttachments(attributedString) {
      BlockContent(content: $0)
        .modifier(TextSelectionInteraction())
        .modifier(TextSelectionCoordination())
    }
    .coordinateSpace(.textContainer)
    .onChange(of: markup) {
      markupDidChange(markup)
    }
    // Disable line limit to avoid per-fragment truncation
    .lineLimit(nil)
  }

  private func markupDidChange(_ markup: String) {
    let next = Self.parse(markup, parser: parser, cacheKey: cacheKey)
    if attributedString != next {
      attributedString = next
    }
  }

  private static func parse(
    _ markup: String,
    parser: any MarkupParser,
    cacheKey: String?
  ) -> AttributedString {
    if let cacheKey, let cached = ParsedMarkupCache.shared.value(forKey: cacheKey) {
      return cached
    }
    let parsed = (try? parser.attributedString(for: markup)) ?? .init()
    if let cacheKey {
      ParsedMarkupCache.shared.set(parsed, forKey: cacheKey)
    }
    return parsed
  }
}

/// Bounded process-wide cache of parsed markup, keyed by a caller-supplied identity.
///
/// `AttributedString` is `Sendable` and immutable once produced, so a fully-parsed value can be
/// reused across view recreations (for example, when a list rebuilds its rows). The cache only
/// stores results the caller has explicitly opted into via a `cacheKey`; the key must uniquely
/// identify both the markup content and the parser configuration that produced it.
final class ParsedMarkupCache: @unchecked Sendable {
  static let shared = ParsedMarkupCache()

  private final class Box {
    let value: AttributedString
    init(_ value: AttributedString) { self.value = value }
  }

  private let storage = NSCache<NSString, Box>()

  private init() {
    storage.countLimit = 512
  }

  func value(forKey key: String) -> AttributedString? {
    storage.object(forKey: key as NSString)?.value
  }

  func set(_ value: AttributedString, forKey key: String) {
    storage.setObject(Box(value), forKey: key as NSString)
  }
}

extension StructuredText {
  /// Parses `markdown` with the default Markdown configuration and stores the result in the shared
  /// cache under the same key `init(markdown:)` uses, so a later view creation is a cache hit.
  ///
  /// `AttributedString` is `Sendable` and the parse is pure, so callers may invoke this off the main
  /// thread (e.g. `Task.detached`) to warm rows before they enter a list. The parse runs the SAME
  /// default-config path as `init(markdown:)` (no `baseURL`, no syntax extensions), which is the only
  /// configuration whose cache key is the raw markdown string; non-default configs are not cached and
  /// this method has no effect for them.
  ///
  /// - Returns: `true` when a value was produced and cached (or was already cached); `false` only if
  ///   the parser threw.
  @discardableResult
  public nonisolated static func prewarm(markdown: String) -> Bool {
    let cacheKey = markdown
    if ParsedMarkupCache.shared.value(forKey: cacheKey) != nil {
      return true
    }
    // Reproduce the default-config parse `init(markdown:)` caches: no baseURL and no syntax
    // extensions, so the PatternProcessor pass is identity and the cached value is exactly this
    // `AttributedString(markdown:)`. Constructing it directly (rather than through the @MainActor
    // `MarkupParser` protocol method) keeps prewarm callable off the main thread.
    guard let parsed = try? AttributedString(
      markdown: markdown,
      including: \.textual,
      options: .init(),
      baseURL: nil
    ) else {
      return false
    }
    ParsedMarkupCache.shared.set(parsed, forKey: cacheKey)
    return true
  }

  /// Creates a structured-text view from a Markdown string.
  ///
  /// This is a convenience initializer that uses Textual’s Markdown parser. To render other
  /// markup formats, use ``init(_:parser:)`` with a custom ``MarkupParser``.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown source to render.
  ///   - baseURL: A base URL used to resolve relative links and image URLs.
  ///   - syntaxExtensions: Custom syntax extensions applied after markdown parsing.
  ///
  /// Math expressions are supported when you include `.math` in `syntaxExtensions`:
  ///
  /// ```swift
  /// StructuredText(
  ///   markdown: "The area is $A = \\pi r^2$.",
  ///   syntaxExtensions: [.math]
  /// )
  /// ```
  public init(
    markdown: String,
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) {
    let cacheKey: String? =
      baseURL == nil && syntaxExtensions.isEmpty ? markdown : nil
    self.init(
      markdown,
      parser: .markdown(
        baseURL: baseURL,
        syntaxExtensions: syntaxExtensions
      ),
      cacheKey: cacheKey
    )
  }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
#Preview(traits: .fixedLayout(width: 400, height: 600)) {
  @Previewable @State var width: CGFloat = 200

  VStack {
    GroupBox {
      HStack {
        Text("Width")
        Slider(value: $width, in: 100...320)
      }
    }
    Spacer()

    StructuredText(
      markdown: """
        Morty, do you know what _“wubba lubba dub dub”_ means?

        ![Hamster in Butt World](https://rickandmortyapi.com/api/character/avatar/153.jpeg)

        I mean, why would a [Pop-Tart](https://en.wikipedia.org/wiki/Pop-Tarts) \
        want to live inside a toaster, Rick? I mean, that would be like the \
        scariest place for them to live. You know what I mean?
        """
    )
    .frame(width: width)
    .border(Color.red)
    .environment(
      \.openURL,
      OpenURLAction { url in
        print("Opening \(url)")
        return .handled
      }
    )
    .padding()
    .textual.textSelection(.enabled)

    Spacer()
  }
}

#Preview("Custom Emoji") {
  let emoji: Set<Emoji> = [
    Emoji(shortcode: "dog", url: URL(string: "https://picsum.photos/id/237/32/32")!),
    Emoji(shortcode: "cat", url: URL(string: "https://picsum.photos/id/1025/32/32")!),
  ]

  ScrollView {
    StructuredText(
      markdown: """
        # Working with Custom Emoji

        You can substitute shortcodes with inline images. For example, :dog: and :cat: render \
        as small inline attachments that flow with the surrounding text.
        """,
      syntaxExtensions: [.emoji(emoji)]
    )
    .padding()
  }
}
