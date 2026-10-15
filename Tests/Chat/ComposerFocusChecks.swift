//
//  ComposerFocusChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
import SwiftUI

@MainActor final class EmojiTextView {
    var isEditable = true
    var isFirstResponder = false
    var markedTextRange: Int?
    var becomes = 0
    var resigns = 0
    func becomeFirstResponder() { becomes += 1; isFirstResponder = true }
    func resignFirstResponder() { resigns += 1; isFirstResponder = false }
}
typealias UITextView = EmojiTextView

@main struct ComposerFocusChecks {
    @MainActor final class StateBox { var focused = false }
    /// UIKit焦点必须双向写回普通状态，正文刷新不能因未注册SwiftUI焦点目标而收键盘。
    @MainActor static func main() {
        let state = StateBox()
        let binding = Binding(get: { state.focused }, set: { state.focused = $0 })
        var input = ProductionFocusInput(focused: binding)
        let owner = ProductionFocusInput.Coordinator(input)
        let context = ProductionFocusInput.Context(coordinator: owner)
        let view = EmojiTextView()
        input.updateUIView(view, context: context)
        view.isFirstResponder = true
        owner.textViewDidBeginEditing(view)
        precondition(state.focused)
        for text in ["a", "a中", "a中🙂", "a中🙂[微笑]"] {
            input.text = text; input.updateUIView(view, context: context)
            precondition(state.focused && view.isFirstResponder && view.resigns == 0, "正文刷新不得撤销用户键盘焦点")
        }
        view.markedTextRange = 1
        let renders = owner.renders
        input.text += "拼音"; input.updateUIView(view, context: context)
        precondition(owner.renders == renders && view.isFirstResponder, "组合输入期间保留原编辑器与焦点")
        binding.wrappedValue = false; input.updateUIView(view, context: context)
        precondition(!view.isFirstResponder && view.resigns == 1, "用户切面板时仍可明确收键盘")
        view.markedTextRange = nil
        binding.wrappedValue = true; input.updateUIView(view, context: context)
        precondition(view.isFirstResponder && view.becomes == 1, "取消成员选择或切回文字可恢复键盘")
        view.isFirstResponder = false; owner.textViewDidEndEditing(view)
        precondition(!state.focused, "用户原生收键盘同步回页面")
        binding.wrappedValue = true; input.isEnabled = false; input.updateUIView(view, context: context)
        precondition(!view.isEditable && !view.isFirstResponder && view.becomes == 1, "禁言时不能强行恢复编辑器")
        print("Composer focus binding and synchronization checks passed")
    }
}
