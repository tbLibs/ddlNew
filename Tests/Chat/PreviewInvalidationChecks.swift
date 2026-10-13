import Foundation

// 测试只替代系统音频/网络对象，生产失效、关闭和身份判断方法原样执行。
@MainActor final class URLSession {
    var cancelled = false
    func invalidateAndCancel() { cancelled = true }
}
@MainActor final class AVAudioPlayer {
    var stopped = false
    func stop() { stopped = true }
}
@MainActor final class AVAudioSession {
    struct Options: OptionSet { let rawValue: Int; static let notifyOthersOnDeactivation = Options(rawValue: 1) }
    static let shared = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { shared }
    func setActive(_ active: Bool, options: Options) throws {}
}

@main struct PreviewInvalidationChecks {
    /// 验证后台、删除范围和取消状态，不声称测试了系统播放器或真实下载。
    @MainActor static func main() {
        let context = ChatContext(userUID: "u", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "g", kind: .group, title: "", avatarURL: ""))
        let preview = ProductionPreview()
        let network = URLSession(); let player = AVAudioPlayer()
        preview.prepare(context: context, senderID: "peer", session: network, player: player)
        preview.invalidateDeletedMessages(["other"], context: context)
        precondition(!preview.isInvalidated && !network.cancelled, "其他作者删除不能停止当前附件")
        var foreign = context
        foreign = ChatContext(userUID: context.userUID, tenantID: context.tenantID, sessionID: UUID(), route: context.route)
        preview.invalidateDeletedMessages(["peer"], context: foreign)
        precondition(!preview.isInvalidated && !network.cancelled, "另一认证轮次不能停止当前附件")
        preview.invalidateDeletedMessages(["peer"], context: context)
        precondition(preview.isInvalidated && preview.file == nil && !preview.loading && !preview.playing, "被删作者附件必须退出所有可使用状态")
        precondition(network.cancelled && player.stopped, "删除同时停止网络和音频对象")
        let background = ProductionPreview()
        background.prepare(context: context, senderID: "peer", session: URLSession(), player: AVAudioPlayer())
        background.close()
        background.invalidateDeletedMessages(["peer"], context: context)
        precondition(background.isInvalidated, "后台停播后仍需响应原消息删除，阻止回前台重新下载")
        let cleared = ProductionPreview()
        cleared.prepare(context: context, senderID: "peer", session: URLSession(), player: AVAudioPlayer())
        cleared.close(); cleared.invalidateMessage(nil, context: foreign)
        precondition(!cleared.isInvalidated, "其他身份清空不能让当前附件失效")
        cleared.invalidateMessage(nil, context: context)
        precondition(cleared.isInvalidated, "同会话清空必须让后台附件失效")
        let single = ProductionPreview()
        single.prepare(context: context, senderID: "peer", session: URLSession(), player: AVAudioPlayer())
        var message = ChatMessageRecord(localID: "other", serverID: "", conversationID: "g", senderID: "peer", senderName: "", timestamp: 0)
        single.invalidateMessage(message, context: context)
        precondition(!single.isInvalidated, "删除其他单条消息不应停止当前附件")
        message.localID = "m"; single.invalidateMessage(message, context: context)
        precondition(single.isInvalidated, "删除当前原条必须让附件失效")
        print("Preview invalidation checks: 9 passed")
    }
}
