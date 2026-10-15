//
//  GameStickerChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
@main struct GameStickerChecks {
    /// 游戏结果域、旧资源映射和动画完成标记使用生产模型，不依赖网络或设备。
    static func main() {
        for game in ChatGameSticker.allCases {
            for _ in 0..<1000 { precondition(game.isValid(game.randomResult()), "结果必须在旧端范围内") }
        }
        precondition(ChatGameSticker.rockPaperScissors.rawValue == 1 && ChatGameSticker.dice.rawValue == 2)
        precondition(ChatGameSticker.rockPaperScissors.resultName("1") == "石头")
        precondition(ChatGameSticker.rockPaperScissors.resultName("2") == "剪刀")
        precondition(ChatGameSticker.rockPaperScissors.resultName("3") == "布")
        precondition(ChatGameSticker.dice.resultImage("6") == "icon_chat_message_dice6")
        for invalid in ["", "0", "7", "01", "bad", "-1"] { precondition(!ChatGameSticker.dice.isValid(invalid)) }
        var played = ChatMessageRecord(localID: "game", conversationID: "g", senderID: "u", senderName: "", type: 21, text: "3", timestamp: 100)
        played.gameType = 2; played.gameAnimationPlayed = true
        let wire = productionGameEncode(played)
        precondition(wire.gameSticekersType == 2 && wire.gameStickersResut == "3" && wire.gameStickersExt == "", "SDK模型必须填写type21的真实类型和结果字段")
        let decoded = productionGameDecode(wire)
        precondition(decoded.gameType == 2 && decoded.text == "3" && decoded.gameAnimationPlayed, "SDK接收和历史保留同一个游戏结果与播放标记")
        var ack = played; ack.gameAnimationPlayed = false; ack.state = .sent; ack.serverID = "s"
        let merged = ChatMessageMerge.merge([played], with: [ack], ack: true)
        precondition(merged.first?.gameAnimationPlayed == true, "相同结果ACK不能回退已播放标记")
        var reroll = played; reroll.text = "6"; reroll.timestamp = 200; reroll.gameAnimationPlayed = false
        precondition(ChatMessageMerge.merge([played], with: [reroll]).first?.gameAnimationPlayed == false, "重试新结果允许重播动画")
        var historical = ack; historical.gameAnimationPlayed = true
        precondition(ChatMessageMerge.merge([], with: [historical]).first?.gameAnimationPlayed == true, "SDK历史的已播放标记原样保留")
        print("Game sticker ranges, results and animation merge checks passed")
    }
}
