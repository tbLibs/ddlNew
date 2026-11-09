import Foundation
@main struct StatusChecks {
    static func main() {
        func status(_ network: Bool?, _ auth: Bool, _ retry: Bool, _ failed: Bool, _ local: String? = nil) -> MessageConnectionStatus {
            .resolve(network: network, authenticated: auth, retrying: retry, failed: failed, localFailure: local)
        }
        precondition(status(nil, false, false, false) == .connecting)
        precondition(status(false, true, false, false) == .offline)
        precondition(status(false, false, true, true, "storage") == .offline)
        precondition(status(true, false, false, false) == .connecting)
        precondition(status(true, false, true, false) == .reconnecting)
        precondition(status(true, false, true, true) == .retrying)
        precondition(status(true, true, true, true) == .online)
        precondition(status(true, false, true, true, "storage") == .localFailure)
        precondition(MessageConnectionStatus.online.title == "在线")
        precondition(MessageConnectionStatus.retrying.title == "连接失败，正在重连")
        print("Connection status checks passed (9)")
    }
}
