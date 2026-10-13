import Foundation
@objc final class OriginalMessageDelegate: NSObject {
    var received = 0
    var acknowledged = 0
    let events: ForwardingEvents
    /// 测试真实Objective-C转发顺序。
    init(events: ForwardingEvents) { self.events = events }
    /// 原SDK聊天接收selector必须继续可达。
    @objc(noaMessageChatReceiveWith:) func receive(_ value: NSObject?) { received += 1 }
    /// ACK不由观察者截断。
    @objc(noaMessageSendSuccess:) func ack(_ value: NSObject?) { acknowledged += 1 }
    /// 昵称同步先运行原SDK方法。
    @objc(noaMessageSystemMessageSynchroMessageWith:) func sync(_ value: NSObject?) { events.append("sdk") }
}
final class ForwardingEvents: @unchecked Sendable {
    private let lock = NSLock(); private var values: [String] = []
    /// 并发安全记录原SDK与观察者顺序。
    func append(_ value: String) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    /// 返回不可变测试快照。
    func snapshot() -> [String] { lock.lock(); defer { lock.unlock() }; return values }
}
@main struct ForwarderChecks {
    /// 用ObjC实际selector验证响应查询、ACK/接收透传以及同步先SDK后观察。
    static func main() {
        let events = ForwardingEvents(); let original = OriginalMessageDelegate(events: events)
        let proxy = SDKChatMessageForwarder(original: original) { _ in events.append("observer") }
        let receive = NSSelectorFromString("noaMessageChatReceiveWith:"); let ack = NSSelectorFromString("noaMessageSendSuccess:")
        precondition(proxy.responds(to: receive) && proxy.responds(to: ack), "未知SDKselector必须继续响应")
        _ = proxy.perform(receive, with: NSObject()); _ = proxy.perform(ack, with: NSObject())
        precondition(original.received == 1 && original.acknowledged == 1, "消息和ACK必须透传一次")
        _ = proxy.perform(NSSelectorFromString("noaMessageSystemMessageSynchroMessageWith:"), with: NSObject())
        precondition(events.snapshot() == ["sdk", "observer"], "原SDK处理后才能观察同步")
        precondition(!proxy.responds(to: NSSelectorFromString("unsupportedMessage:")), "不伪造SDK未知能力")
        print("Message forwarder checks: 4 passed")
    }
}
