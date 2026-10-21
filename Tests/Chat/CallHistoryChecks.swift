import Foundation

@main struct CallHistoryChecks {
    static func main() {
        precondition(ChatCallSummary.liveKit(type: 101, content: #"{"state":"discard","mode":0,"from_id":"A","discard_reason":"","duration":83}"#, userUID: "A") == "01:23 通话结束")
        precondition(ChatCallSummary.liveKit(type: 101, content: #"{"state":"request","mode":0}"#, userUID: "A").isEmpty)
        precondition(ChatCallSummary.liveKit(type: 103, content: #"{"mode":1,"action":"new"}"#, userUID: "A") == "语音通话")
        precondition(ChatCallSummary.liveKit(type: 103, content: #"{"mode":0,"action":"discard"}"#, userUID: "A") == "视频通话已经结束")
        precondition(ChatCallSummary.liveKit(type: 102, content: #"{"action":"new"}"#, userUID: "A").isEmpty)
        precondition(ChatCallSummary.zego(chatType: 1, kind: 1, status: 4, duration: 0, outgoing: true) == "对方已拒绝")
        precondition(ChatCallSummary.zego(chatType: 1, kind: 2, status: 7, duration: -10, outgoing: false) == "通话中断 00:00")
        precondition(ChatCallSummary.zego(chatType: 1, kind: 1, status: 8, duration: 0, outgoing: true).isEmpty)
        precondition(ChatCallSummary.zego(chatType: 1, kind: 1, status: 8, duration: 0, outgoing: false) == "已在其他设备接听")
        precondition(ChatCallSummary.zego(chatType: 2, kind: 2, status: 11, duration: 0, outgoing: false) == "视频通话已经结束")
        for status in [3, 4, 5, 6, 7, 8, 9, 10, 12] {
            precondition(ChatCallSummary.zego(chatType: 2, kind: 1, status: status, duration: 0, outgoing: false).isEmpty)
        }
        print("Call history checks: passed")
    }
}
