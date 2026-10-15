//
//  ChatComposerMode.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

/// 输入模式不由选中数量推断，取消最后一条选择仍能继续多选。
nonisolated struct ChatComposerMode: Equatable {
    enum Panel { case text, stickers, voice, selection }
    enum PrimaryAction { case send, voice }
    private(set) var panel = Panel.text

    /// 表情和语音只能展开一个，再点当前入口回到文字模式。
    mutating func toggle(_ panel: Panel) { self.panel = self.panel == panel ? .text : panel }
    /// 键盘与自定义输入面板互斥，多选中的迟到焦点事件不恢复编辑器。
    mutating func beginTyping() { if panel != .selection { panel = .text } }
    /// 多选独占输入区，不能留下隐藏但仍在录制的面板。
    mutating func selectMessages() { panel = .selection }
    /// 用户明确退出多选后才恢复原文本草稿。
    mutating func endSelection() { panel = .text }
    /// 有文字或键盘正在编辑时显示发送，空闲空输入显示语音。
    static func primaryAction(input: String, focused: Bool) -> PrimaryAction {
        focused || !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .send : .voice
    }
}
