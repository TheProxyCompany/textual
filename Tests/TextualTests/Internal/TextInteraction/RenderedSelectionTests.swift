#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit)
import AppKit
import SwiftUI
import Testing
@testable import Textual

@Suite(.serialized) @MainActor struct RenderedSelectionTests {
    @Test func highlightRemainsVisibleInNonKeyPanel() throws {
        _ = NSApplication.shared
        for dark in [true, false] {
            let content = StructuredText(markdown: "## A party worth sharing\n\nSelect a few words, or copy this entire response. Your selection stays visible even when this panel is not the key window.\n\n- First finding\n- Second finding")
                .font(.system(size: 16))
                .foregroundStyle(dark ? Color.white : Color.black)
                .textual.textSelection(.enabled)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 320)
                .background(dark ? Color(red: 0.1, green: 0.07, blue: 0.09) : Color(red: 0.89, green: 0.86, blue: 0.74))
                .environment(\.colorScheme, dark ? .dark : .light)
            let host = NSHostingView(rootView: content)
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 320), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.contentView = host
            window.orderBack(nil)
            defer { window.orderOut(nil) }
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            func find(_ view: NSView) -> NSTextInteractionView? {
                if let text = view as? NSTextInteractionView { return text }
                return view.subviews.lazy.compactMap { find($0) }.first
            }
            let interaction = try #require(find(host))
            #expect(interaction.acceptsFirstMouse(for: nil))
            #expect(interaction.model.hasText)
            func bluePixelCount() throws -> Int {
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                var count = 0
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                    for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                        if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                           color.blueComponent > color.redComponent + 0.1,
                           color.blueComponent > color.greenComponent + 0.03 {
                            count += 1
                        }
                    }
                }
                return count
            }
            let before = try bluePixelCount()
            interaction.selectAll(nil)
            #expect(interaction.model.selectedRange != nil)
            #expect(!interaction.model.selectionRects(for: interaction.model.selectedRange!).isEmpty)
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            #expect(try bluePixelCount() > before + 100)
            for width in [430.0, 560.0, 500.0] {
                window.setContentSize(NSSize(width: width, height: 320))
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                #expect(interaction.model.selectedRange != nil)
                #expect(try bluePixelCount() > before + 100)
                let rect = try #require(interaction.model.textContentRects().dropFirst().first)
                let start = interaction.convert(CGPoint(x: rect.minX + 4, y: rect.minY + 8), to: nil)
                let end = interaction.convert(CGPoint(x: rect.minX + min(180, rect.width - 4), y: rect.minY + 8), to: nil)
                func event(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
                    try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                }
                interaction.mouseDown(with: try event(.leftMouseDown, start))
                interaction.mouseDragged(with: try event(.leftMouseDragged, end))
                interaction.mouseUp(with: try event(.leftMouseUp, end))
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                #expect(try bluePixelCount() > before + 30)
                window.orderOut(nil)
                window.orderBack(nil)
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                #expect(try bluePixelCount() > before + 30)
                interaction.model.selectedRange = nil
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                #expect(try bluePixelCount() <= before + 5)
                interaction.selectAll(nil)
            }
        }
    }
}
#endif
