import XCTest
import SwiftUI
import UIKit

@MainActor final class ChatInputLimitTests: XCTestCase {
    final class Draft {
        var text: String
        var selection: NSRange
        var focused = false
        var notices = 0
        init(_ text: String) { self.text = text; selection = NSRange(location: text.utf16.count, length: 0) }
    }

    private func editor(_ draft: Draft) -> (EmojiTextView, ChatComposerTextInput.Coordinator) {
        let input = ChatComposerTextInput(text: Binding(get: { draft.text }, set: { draft.text = $0 }),
            selection: Binding(get: { draft.selection }, set: { draft.selection = $0 }),
            focused: Binding(get: { draft.focused }, set: { draft.focused = $0 }), maximumLines: 5,
            onLimitExceeded: { draft.notices += 1 })
        let owner = ChatComposerTextInput.Coordinator(input), view = EmojiTextView()
        view.delegate = owner
        owner.render(view)
        return (view, owner)
    }

    func testPasteClipsOnlyInsertionAndAllowsSelectionReplacement() {
        let draft = Draft(String(repeating: "中", count: 999))
        let (view, owner) = editor(draft)
        XCTAssertFalse(owner.textView(view, shouldChangeTextIn: NSRange(location: 10, length: 0), replacementText: "abc"))
        XCTAssertEqual(draft.text, String(repeating: "中", count: 10) + "a" + String(repeating: "中", count: 989))
        XCTAssertEqual(draft.selection, NSRange(location: 11, length: 0))
        XCTAssertEqual(draft.notices, 1)
        XCTAssertFalse(owner.textView(view, shouldChangeTextIn: NSRange(location: 10, length: 1), replacementText: "👨‍👩‍👧‍👦🙂"))
        XCTAssertEqual(ChatInputLimit.length(draft.text), 1_000)
        XCTAssertTrue(draft.text.contains("👨‍👩‍👧‍👦"))
        XCTAssertFalse(draft.text.contains("🙂"))
        XCTAssertEqual(draft.notices, 2, "Repeated overflow must present feedback again")
        XCTAssertTrue(owner.textView(view, shouldChangeTextIn: NSRange(location: 0, length: 1), replacementText: ""))
        XCTAssertEqual(draft.notices, 2, "Deleting at the limit must not show an overflow Toast")
    }

    func testInlineEmojiCountsAsOneAndDoesNotSplitTokens() {
        let text = String(repeating: "[微笑]", count: 999)
        let draft = Draft(text), (view, owner) = editor(draft)
        XCTAssertEqual(view.attributedText.length, 999)
        XCTAssertFalse(owner.textView(view, shouldChangeTextIn: NSRange(location: 999, length: 0), replacementText: "[微笑][快乐]"))
        XCTAssertEqual(draft.text, text + "[微笑]")
        XCTAssertEqual(view.attributedText.length, 1_000)
        XCTAssertEqual(draft.selection.location, draft.text.utf16.count)
        XCTAssertEqual(draft.notices, 1)
        XCTAssertFalse(owner.textView(view, shouldChangeTextIn: NSRange(location: 1_000, length: 0), replacementText: "x"))
        XCTAssertEqual(draft.notices, 2, "Typing at capacity must report the limit")
    }

    func testMarkedTextIsOnlyLimitedAfterCommit() throws {
        let original = String(repeating: "a", count: 999)
        let draft = Draft(original), (view, owner) = editor(draft)
        view.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNotNil(view.markedTextRange)
        owner.textViewDidChange(view)
        XCTAssertEqual(draft.text, original, "Uncommitted input must not be truncated or published")
        XCTAssertEqual(draft.notices, 0)
        XCTAssertTrue(owner.textView(view, shouldChangeTextIn: NSRange(location: 999, length: 2), replacementText: "汉字"))
        view.unmarkText()
        owner.textViewDidChange(view)
        XCTAssertEqual(draft.text, original + "中")
        XCTAssertEqual(EmojiTextView.wire(view.attributedText), draft.text)
        XCTAssertEqual(draft.notices, 1)
    }
}
