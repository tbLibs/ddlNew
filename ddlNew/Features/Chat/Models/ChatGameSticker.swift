//
//  ChatGameSticker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

/// 旧SDK游戏类型与图片序号保持一致，结果只生成一次后随消息发送。
nonisolated enum ChatGameSticker: Int, CaseIterable, Identifiable, Sendable {
    case rockPaperScissors = 1, dice = 2
    var id: Int { rawValue }
    var title: String { self == .dice ? "骰子" : "石头剪刀布" }
    var icon: String { self == .dice ? "emoji_collect_playDice" : "emoji_collect_stoneScissorCloth" }
    var maximum: Int { self == .dice ? 6 : 3 }
    var frames: [String] {
        self == .dice ? (1...4).map { "icon_chat_message_dice_animation\($0)" }
            : (1...3).map { "icon_chat_message_stoneScissorCloth\($0)" }
    }
    var frameInterval: Double { self == .dice ? 0.1 : 0.3 }
    func randomResult() -> String { String(Int.random(in: 1...maximum)) }
    func isValid(_ result: String) -> Bool {
        guard let value = Int(result), String(value) == result else { return false }
        return (1...maximum).contains(value)
    }
    func resultImage(_ result: String) -> String? {
        guard isValid(result) else { return nil }
        return (self == .dice ? "icon_chat_message_dice" : "icon_chat_message_stoneScissorCloth") + result
    }
    func resultName(_ result: String) -> String {
        guard isValid(result) else { return "结果未知" }
        return self == .dice ? result + "点" : ["1": "石头", "2": "剪刀", "3": "布"][result] ?? "结果未知"
    }
}
