import Foundation

@main struct Checks {
    @inline(never) static func status(_ sdk: NoaIMSDKManager, serverID: String) -> Int {
        let old: NoaIMChatMessageModel? = !serverID.isEmpty
            ? sdk.toolGetOneChatMessage(withServiceMessageID: serverID, sessionID: "test")
            : sdk.toolGetOneChatMessage(withMessageID: "missing", sessionID: "test")
        let latest = old.map { $0.messageStatus }
        if let old, let latest, latest != 1 { return old.messageStatus }
        return 1
    }
    static func main() {
        let sdk = NoaIMSDKManager()
        let a = status(sdk, serverID: "missing")
        let b = status(sdk, serverID: "")
        print("Missing SDK rows: server=\(a), local=\(b), expected remote status=1")
        if a != 1 || b != 1 { exit(1) }
    }
}
