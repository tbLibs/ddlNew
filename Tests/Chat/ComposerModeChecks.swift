//
//  ComposerModeChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

@main struct ComposerModeChecks {
    /// 模拟文字、表情、录音和零选择的多选切换，不调用SDK或麦克风。
    static func main() {
        var mode = ChatComposerMode()
        precondition(mode.panel == .text)
        mode.toggle(.stickers)
        precondition(mode.panel == .stickers)
        mode.toggle(.voice)
        precondition(mode.panel == .voice, "表情与录音必须互斥")
        mode.toggle(.voice)
        precondition(mode.panel == .text, "再次点击关闭展开面板")
        mode.toggle(.stickers); mode.beginTyping()
        precondition(mode.panel == .text, "系统键盘出现时关闭自定义面板")
        mode.toggle(.voice); mode.selectMessages()
        precondition(mode.panel == .selection, "多选取代输入区且不依赖选中数量")
        mode.beginTyping()
        precondition(mode.panel == .selection, "迟到焦点变化不能退出多选")
        mode.endSelection()
        precondition(mode.panel == .text)
        precondition(ChatComposerMode.primaryAction(input: "", focused: false) == .voice)
        precondition(ChatComposerMode.primaryAction(input: " \n", focused: false) == .voice)
        precondition(ChatComposerMode.primaryAction(input: "", focused: true) == .send)
        precondition(ChatComposerMode.primaryAction(input: "中文🙂", focused: false) == .send)
        print("Chat composer transition checks passed")
    }
}
