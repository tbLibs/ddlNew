import XCTest
import SwiftUI
import UIKit

@MainActor final class EmojiRenderingTests: XCTestCase {
    func testThousandsOfInlineEmojiRenderWithoutStackOverflow() throws {
        XCTAssertEqual(ChatEmojiCatalog.items.count, 157)
        let item = try XCTUnwrap(ChatEmojiCatalog.items.first)
        XCTAssertNotNil(UIImage(named: item.image), "Exercise image Text, not missing-image fallback")
        var previousHeight: CGFloat = 0
        for count in [1, 1_000, 5_000, 10_000] {
            let text = String(repeating: item.token, count: count)
            let height = render(text, dynamicType: .large)
            XCTAssertGreaterThan(height, previousHeight, "Must retain all emoji, not truncate to avoid the crash")
            previousHeight = height
            print("Emoji render passed: count=\(count), height=\(height)")
        }
    }

    func testMixedTextUnknownTokensAndAccessibilitySize() {
        let text = String(repeating: "中文🙂[微笑]\n[快乐][未知表情] English ", count: 1_000)
        let runs = ChatEmojiCatalog.runs(in: text)
        XCTAssertEqual(runs.map(\.text).joined(), text)
        XCTAssertEqual(runs.compactMap(\.emoji).count, 2_000)
        let normal = render(text, dynamicType: .large)
        let accessible = render(text, dynamicType: .accessibility3)
        XCTAssertGreaterThan(accessible, normal)
    }

    func testEmptyPlainAndOddNumberOfFragments() {
        for text in ["", "中文🙂\nEnglish [未知]", "前[微笑]中[快乐]后", "[微笑][快乐][微笑]"] {
            _ = render(text, dynamicType: .large)
        }
    }

    /// Forces the production SwiftUI Text resolver and layout, the original crash site.
    private func render(_ value: String, dynamicType: DynamicTypeSize) -> CGFloat {
        let controller = UIHostingController(rootView: ChatEmojiText(value: value)
            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            .environment(\.dynamicTypeSize, dynamicType))
        let size = controller.sizeThatFits(in: CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertTrue(size.height.isFinite)
        XCTAssertGreaterThanOrEqual(size.height, 0)
        return size.height
    }
}
