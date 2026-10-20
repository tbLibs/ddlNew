import Foundation
import Combine

struct ChatContext { let route = Route(); struct Route { let id = "chat" } }
struct ChatMessageRecord { let id: String }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var current = true
    func makePreviewStore() -> ChatMediaPreviewStore { ChatMediaPreviewStore() }
    func isCurrent(_ context: ChatContext) -> Bool { current }
    func registerCleanup(owner: AnyObject, conversationID: String, action: @escaping @MainActor () -> Void) {}
}
@MainActor final class ChatMediaPreviewStore {
    var loading = false, playing = false, isInvalidated = false
    var file: URL?
    var errorMessage: String?
    var pending: [String: CheckedContinuation<Void, Never>] = [:]
    var loaded = ""
    var plays: [String] = []
    func load(_ message: ChatMessageRecord, context: ChatContext) async {
        loaded = message.id; loading = true
        await withCheckedContinuation { pending[message.id] = $0 }
        loading = false
        file = URL(fileURLWithPath: "/tmp/anonymous-voice")
    }
    func complete(_ id: String) { pending.removeValue(forKey: id)?.resume() }
    func playVoice() throws -> Bool { plays.append(loaded); playing = true; return true }
    func close() { playing = false; loading = false; file = nil }
}

@main struct VoicePlaybackChecks {
    @MainActor static func wait(_ condition: () -> Bool) async {
        for _ in 0..<10_000 { if condition() { return }; await Task.yield() }
        preconditionFailure("等待生产状态超时")
    }
    @MainActor static func main() async {
        var press = ChatVoicePressState()
        precondition(press.begin() && !press.begin())
        press.move(inside: false)
        precondition(!press.isInside && press.release(inside: false) == false)
        precondition(press.release(inside: true) == nil)
        _ = press.begin(); press.move(inside: false); press.move(inside: true)
        precondition(press.isInside && press.release(inside: true) == true)
        _ = press.begin(); precondition(press.reachLimit() && press.release(inside: true) == nil)
        _ = press.begin(); press.cancel(); precondition(!press.reachLimit())

        let owner = ChatVoicePlayback(), context = ChatContext()
        var reads: [String] = []
        func toggle(_ id: String) { owner.toggle(ChatMessageRecord(id: id), context: context, onPlayed: { reads.append(id) }, onError: { _ in preconditionFailure("意外错误") }) }
        toggle("a")
        await wait { owner.preview.pending["a"] != nil }
        precondition(reads.isEmpty, "下载前不能已读")
        toggle("b")
        await wait { owner.preview.pending["b"] != nil }
        owner.preview.complete("a")
        for _ in 0..<10 { await Task.yield() }
        precondition(reads.isEmpty && owner.preview.plays.isEmpty, "旧下载迟到不能抢播或上报已读")
        owner.preview.complete("b")
        await wait { reads == ["b"] }
        precondition(owner.preview.plays == ["b"])
        toggle("b")
        precondition(owner.messageID == nil && !owner.preview.playing, "再次点同条停止")

        toggle("cancel")
        await wait { owner.preview.pending["cancel"] != nil }
        owner.stop(); owner.preview.complete("cancel")
        for _ in 0..<10 { await Task.yield() }
        precondition(reads == ["b"] && owner.preview.plays == ["b"], "离页或开始录音后迟到不能播放")

        toggle("deleted")
        await wait { owner.preview.pending["deleted"] != nil }
        owner.preview.isInvalidated = true; owner.preview.complete("deleted")
        for _ in 0..<10 { await Task.yield() }
        precondition(reads == ["b"], "原消息删除不能播放或已读")
        owner.preview.isInvalidated = false; owner.stop()

        toggle("auth")
        await wait { owner.preview.pending["auth"] != nil }
        ChatRuntime.shared.current = false; owner.preview.complete("auth")
        for _ in 0..<10 { await Task.yield() }
        precondition(reads == ["b"], "旧AUTH不能在下载完成后播放")
        print("Voice press and playback checks: passed")
    }
}
