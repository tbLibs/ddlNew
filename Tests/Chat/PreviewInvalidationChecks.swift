import Foundation

// 测试只替代系统音频/网络对象，生产失效、关闭和身份判断方法原样执行。
@MainActor final class URLSession {
    var cancelled = false
    /// 记录生产关闭逻辑是否取消网络，不建立真实连接。
    func invalidateAndCancel() { cancelled = true }
}
@MainActor final class AVAudioPlayer {
    var stopped = false
    /// 记录生产关闭逻辑是否停止播放，不打开实际媒体。
    func stop() { stopped = true }
}
@MainActor final class AVAudioSession {
    struct Options: OptionSet { let rawValue: Int; static let notifyOthersOnDeactivation = Options(rawValue: 1) }
    static let shared = AVAudioSession()
    /// 返回离线音频会话替身，避免修改系统音频路由。
    static func sharedInstance() -> AVAudioSession { shared }
    /// 离线目标保留生产调用形状，不激活系统音频会话。
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
        // 失效预览在系统再次转入后台时仍须解释不可用原因，不能变成空白页。
        single.close()
        precondition(single.isInvalidated && single.errorMessage?.isEmpty == false, "失效附件后台关闭后必须保留原因提示")
        single.close()
        precondition(single.isInvalidated && single.errorMessage?.isEmpty == false, "重复关闭不能清除失效原因")
        let active = ProductionPreview()
        active.errorMessage = "临时下载错误"
        active.close()
        precondition(active.errorMessage == nil, "普通关闭仍应清除可重试临时错误")
        print("Preview invalidation checks: 12 passed")
    }
}
