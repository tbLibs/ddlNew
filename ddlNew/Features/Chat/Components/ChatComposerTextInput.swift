//
//  ChatComposerTextInput.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import UIKit

/// UIKit只负责富文本和光标，正文、焦点和成员UID仍由现有SwiftUI/ChatStore拥有。
struct ChatComposerTextInput: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var focused: Binding<Bool>
    var maximumLines: Int
    var onAtSign: ((NSRange) -> Void)?
    @Environment(\.isEnabled) private var isEnabled

    /// 使用原生文本编辑器保留中文输入法、选区与组合字素删除行为。
    func makeUIView(context: Context) -> EmojiTextView {
        let view = EmojiTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainer.lineFragmentPadding = 0
        view.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 0)
        view.adjustsFontForContentSizeCategory = true
        view.allowsEditingTextAttributes = false
        view.accessibilityLabel = "消息正文"
        view.accessibilityIdentifier = "chatMessageInput"
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    /// 外部插入表情/成员后映射光标；中文标记文本存在时不重建富文本。
    func updateUIView(_ view: EmojiTextView, context: Context) {
        let owner = context.coordinator; owner.parent = self
        view.isEditable = isEnabled
        if view.markedTextRange == nil { owner.render(view) }
        if focused.wrappedValue && isEnabled && !view.isFirstResponder { view.becomeFirstResponder() }
        else if !focused.wrappedValue && view.isFirstResponder { view.resignFirstResponder() }
    }

    /// iOS16原生测量按行增高，超过上限只滚动输入框，不挤走发送按钮。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: EmojiTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let limit = (uiView.font?.lineHeight ?? 20) * CGFloat(maximumLines) + 20
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        uiView.isScrollEnabled = size.height > limit
        return CGSize(width: width, height: min(max(44, size.height), max(44, limit)))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ChatComposerTextInput
        private var rendering = false
        private var lastWire: String?
        private var lastFont: UIFont?
        private var pendingAt: NSRange?
        init(_ parent: ChatComposerTextInput) { self.parent = parent }

        /// 每个旧表情在显示中只占一个附件，wire正文仍保留完整旧标记。
        func render(_ view: EmojiTextView) {
            let font = UIFont.preferredFont(forTextStyle: .body)
            rendering = true; defer { rendering = false }
            if lastWire != parent.text || lastFont != font {
                let value = NSMutableAttributedString(string: "")
                for run in ChatEmojiCatalog.runs(in: parent.text) {
                    if let item = run.emoji {
                        let attachment = ChatEmojiAttachment(); attachment.token = item.token
                        attachment.image = UIImage(named: item.image) ?? UIImage(systemName: "face.smiling")
                        attachment.bounds = CGRect(x: 0, y: font.descender, width: font.lineHeight, height: font.lineHeight)
                        value.append(NSAttributedString(attachment: attachment))
                    } else { value.append(NSAttributedString(string: run.text)) }
                }
                value.addAttributes([.font: font, .foregroundColor: UIColor.label], range: NSRange(location: 0, length: value.length))
                view.attributedText = value; lastWire = parent.text; lastFont = font
                view.font = font
            }
            let raw = parent.selection.location == NSNotFound ? NSRange(location: parent.text.utf16.count, length: 0) : parent.selection
            let start = ChatEmojiCatalog.displayOffset(raw.location, in: parent.text)
            let remaining = parent.text.utf16.count - min(max(0, raw.location), parent.text.utf16.count)
            let end = ChatEmojiCatalog.displayOffset(min(max(0, raw.location), parent.text.utf16.count) + min(max(0, raw.length), remaining), in: parent.text)
            let desired = NSRange(location: start, length: max(0, end - start))
            if view.selectedRange != desired { view.selectedRange = desired }
            view.typingAttributes = [.font: font, .foregroundColor: UIColor.label]
        }

        /// 原生编辑先完成，再将附件还原为wire文本；不拦截输入法的组合过程。
        func textViewDidChange(_ textView: UITextView) {
            guard !rendering else { return }
            parent.text = EmojiTextView.wire(textView.attributedText)
            updateSelection(textView)
            if let range = pendingAt { pendingAt = nil; parent.onAtSign?(range) }
        }

        /// 只对一次实际输入的@调起成员，粘贴整段带@的文本不误触发。
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "@", parent.onAtSign != nil {
                let prefix = textView.attributedText.attributedSubstring(from: NSRange(location: 0, length: range.location))
                pendingAt = NSRange(location: EmojiTextView.wire(prefix).utf16.count, length: 1)
            } else { pendingAt = nil }
            return true
        }
        func textViewDidChangeSelection(_ textView: UITextView) { if !rendering { updateSelection(textView) } }
        func textViewDidBeginEditing(_ textView: UITextView) { if !parent.focused.wrappedValue { parent.focused.wrappedValue = true } }
        func textViewDidEndEditing(_ textView: UITextView) { if parent.focused.wrappedValue { parent.focused.wrappedValue = false } }
        /// 选区由实际富文本反算，中文组合与表情附件均不猜字符长度。
        private func updateSelection(_ view: UITextView) {
            let range = view.selectedRange, value = view.attributedText ?? NSAttributedString(string: "")
            guard range.location <= value.length, range.length <= value.length - range.location else { return }
            let prefix = EmojiTextView.wire(value.attributedSubstring(from: NSRange(location: 0, length: range.location)))
            let selected = EmojiTextView.wire(value.attributedSubstring(from: range))
            parent.selection = NSRange(location: prefix.utf16.count, length: selected.utf16.count)
        }
    }
}

/// 附件带上原协议文本，复制和发送都不能把表情降级成U+FFFC占位符。
final class ChatEmojiAttachment: NSTextAttachment { var token = "" }

final class EmojiTextView: UITextView {
    static func wire(_ value: NSAttributedString) -> String {
        var result = ""
        value.enumerateAttributes(in: NSRange(location: 0, length: value.length)) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? ChatEmojiAttachment { result += attachment.token }
            else { result += value.attributedSubstring(from: range).string }
        }
        return result
    }
    override func copy(_ sender: Any?) {
        guard selectedRange.length > 0 else { return }
        UIPasteboard.general.string = Self.wire(attributedText.attributedSubstring(from: selectedRange))
    }
    override func cut(_ sender: Any?) { copy(sender); insertText("") }
    override func paste(_ sender: Any?) { if let value = UIPasteboard.general.string { insertText(value) } }
}
