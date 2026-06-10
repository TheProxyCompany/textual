import SwiftUI

// MARK: - Overview
//
// TextBuilder constructs SwiftUI.Text from attributed content with inline attachments.
// It caches Text values keyed by attachment sizes to avoid unnecessary rebuilds during
// resize. When the container size changes, attachment sizes are recomputed and the cache
// is consulted. If the new sizes hash to the same key, the cached Text is reused.
//
// The cache key is derived from the hash of [AttachmentKey: CGSize]. Since attachment
// sizes often remain constant or repeat during incremental resize (e.g., window resizing),
// this compact key enables effective caching without storing the full proposal or
// attributed string. The cache has a count limit of 10 to prevent unbounded growth.
//
// Runs with attachments are converted to placeholder images sized by the attachment's
// sizeThatFits(_:in:) result. Placeholders are tagged with AttachmentAttribute so overlays
// can identify and render the actual attachment views at the resolved layout positions.

extension TextFragment {
  @MainActor @Observable final class TextBuilder {
    var text: Text

    @ObservationIgnored private let content: Content
    @ObservationIgnored private let cache: NSCache<KeyBox<[AttachmentKey: CGSize]>, Box<Text>>
    @ObservationIgnored private var lastCacheKey: KeyBox<[AttachmentKey: CGSize]>

    init(_ content: Content, environment: TextEnvironmentValues) {
      let attachmentSizes = content.attachmentSizes(for: .unspecified, in: environment)
      let cacheKey = KeyBox(attachmentSizes)

      self.text = Text(
        attributedString: content,
        attachmentSizes: attachmentSizes,
        in: environment
      )
      self.content = content
      self.cache = NSCache()
      self.cache.countLimit = 10
      self.lastCacheKey = cacheKey

      self.cache.setObject(Box(self.text), forKey: cacheKey)
    }

    func sizeChanged(_ size: CGSize, environment: TextEnvironmentValues) {
      let attachmentSizes = content.attachmentSizes(for: .init(size), in: environment)
      let cacheKey = KeyBox(attachmentSizes)

      if cacheKey == lastCacheKey {
        return
      }
      lastCacheKey = cacheKey

      if let text = cache.object(forKey: cacheKey) {
        self.text = text.wrappedValue
      } else {
        let text = Text(
          attributedString: content,
          attachmentSizes: attachmentSizes,
          in: environment
        )
        cache.setObject(Box(text), forKey: cacheKey)

        self.text = text
      }
    }
  }
}

extension Text {
  @MainActor
  static func textualText(
    attributedString: some AttributedStringProtocol,
    in environment: TextEnvironmentValues
  ) -> Text {
    let key = TextFragmentCache.Key(
      content: AttributedString(attributedString),
      environment: environment
    )
    if let cached = TextFragmentCache.shared.value(forKey: key) {
      return cached
    }
    let text = Text(attributedString: attributedString, attachmentSizes: [:], in: environment)
    TextFragmentCache.shared.set(text, forKey: key)
    return text
  }

  fileprivate init(
    attributedString: some AttributedStringProtocol,
    attachmentSizes: [AttachmentKey: CGSize],
    in environment: TextEnvironmentValues
  ) {
    let textValues = attributedString.runs.map { run in
      var text: Text

      var runEnvironment = environment
      runEnvironment.font = run.font ?? environment.font

      let key = run.textual.attachment.map {
        AttachmentKey(attachment: $0, font: runEnvironment.font)
      }

      if let key, let size = attachmentSizes[key] {
        // Create placeholder
        text = Text(placeholderSize: size)
          .baselineOffset(key.attachment.baselineOffset(in: runEnvironment))
          .customAttribute(
            AttachmentAttribute(
              key.attachment,
              presentationIntent: run.presentationIntent
            )
          )
      } else {
        text = Text(AttributedString(attributedString[run.range]))
      }

      // Add link attribute for TextLinkInteraction
      if let link = run.link {
        text = text.customAttribute(LinkAttribute(link))
      }

      return text
    }

    self = textValues.reduce(Text(verbatim: "")) { partialResult, text in
      Text("\(partialResult)\(text)")
    }
  }

  private init(placeholderSize size: CGSize) {
    self.init(SwiftUI.Image(size: size) { _ in })
  }
}

extension AttributedStringProtocol {
  fileprivate func attachmentSizes(
    for proposal: ProposedViewSize, in environment: TextEnvironmentValues
  ) -> [AttachmentKey: CGSize] {
    Dictionary(
      self.runs.compactMap { run in
        guard let attachment = run.textual.attachment else {
          return nil
        }
        var environment = environment
        environment.font = run.font ?? environment.font
        return (
          AttachmentKey(
            attachment: attachment,
            font: environment.font
          ),
          attachment.sizeThatFits(proposal, in: environment)
        )
      },
      uniquingKeysWith: { existing, _ in existing }
    )
  }
}

private struct AttachmentKey: Hashable {
  let attachment: AnyAttachment
  let font: Font?
}

// MARK: - Attachment-free Text cache
//
// Building a SwiftUI.Text from attributed runs maps every run and folds them with nested
// string interpolation — O(runs) per call. For attachment-free content this Text is a pure
// value function of (content, environment), so it can be reused across view recreations
// (e.g. switching back to a conversation rebuilds every row's StructuredText from scratch).
// The cache is keyed on the full attributed content, so streaming deltas and edits miss
// cleanly and resolve to a fresh build.
@MainActor
final class TextFragmentCache {
  static let shared = TextFragmentCache()

  struct Key: Hashable {
    let content: AttributedString
    let environment: TextEnvironmentValues
  }

  private final class Box {
    let value: Text
    init(_ value: Text) { self.value = value }
  }

  private let storage = NSCache<KeyBox<Key>, Box>()

  private init() {
    storage.countLimit = 512
  }

  func value(forKey key: Key) -> Text? {
    storage.object(forKey: KeyBox(key))?.value
  }

  func set(_ value: Text, forKey key: Key) {
    storage.setObject(Box(value), forKey: KeyBox(key))
  }
}
