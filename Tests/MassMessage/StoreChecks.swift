import Foundation
import Combine

struct ChatContext: Equatable { let userUID: String; let tenantID: String; let sessionID: UUID }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    func isCurrent(_ context: ChatContext) -> Bool { true }
    func registerCleanup(owner: AnyObject, action: @escaping @MainActor () -> Void) {}
}
@MainActor final class UserRoleAuthorityStore {
    static let shared = UserRoleAuthorityStore()
    var current: Authority? = Authority()
    struct Authority { func allows(_ key: String) -> Bool { true } }
}
@MainActor enum SDKMassMessagePreview { static func update(_ records: [MassMessageRecord], context: ChatContext) {} }
@MainActor class FakeClient: MassMessageClient {
    var pages: [Int: MassMessagePage<MassMessageRecord>] = [:]
    var loaded: [Int] = []
    var loadError = false, sendError = false, deleteError = false
    var createCount = 0, sendCount = 0
    var sentLabel = "", sentBody = ""
    var onCreate: (() -> Void)?
    var suspendedLoad: CheckedContinuation<MassMessagePage<MassMessageRecord>, Error>?
    var suspend = false
    func load(page: Int) async throws -> MassMessagePage<MassMessageRecord> {
        loaded.append(page)
        if suspend { return try await withCheckedThrowingContinuation { suspendedLoad = $0 } }
        if loadError { throw MassMessageError.message("offline") }
        return pages[page] ?? .init(records: [], total: 0)
    }
    func recipients(record: MassMessageRecord, failures: Bool, page: Int) async throws -> MassMessagePage<MassMessageRecipient> {
        .init(records: [.init(uid: "same", isGroup: false, name: "user"), .init(uid: "same", isGroup: true, name: "group")], total: 2)
    }
    func create(label: String, recipients: [MassMessageRecipient]) async throws -> String { createCount += 1; onCreate?(); return "created" }
    func send(labelID: String, type: Int, body: String) async throws { sendCount += 1; sentLabel = labelID; sentBody = body; if sendError { throw MassMessageError.message("send failed") } }
    func delete(_ record: MassMessageRecord) async throws { if deleteError { throw MassMessageError.message("delete failed") } }
    func cancel() {}
}
@MainActor final class SDKMassMessageClient: FakeClient { init(context: ChatContext) {} }
@MainActor final class SDKChatMediaClient: ChatMediaClient {
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment { .init(resource: "https://example.invalid/file", thumbnail: "https://example.invalid/thumb") }
    func cancel() {}
}

@main struct Checks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ name: String) { guard value else { fatalError("FAIL: \(name)") }; count += 1; print("PASS: \(name)") }
        let context = ChatContext(userUID: "test", tenantID: "tenant", sessionID: UUID())
        let row: [String: Any] = ["id": "9007199254740993", "labelId": "label", "mtype": "0", "status": "2", "sendTime": "2026-10-23 12:34:56", "body": "{\"content\":\"你好🙂\\n第二行\"}", "totalCount": "3", "errorCount": 1]
        let parsed = try MassMessagePayload.records(["records": [row], "total": "1"])
        let record = parsed.records[0]
        check(record.id == "9007199254740993" && record.summary == "你好🙂\n第二行", "large ID, string body and Unicode preserved")
        check(record.statusText == "部分发送失败" && record.total == 3, "server status counts")
        check((try? MassMessagePayload.records(["records": [[:]]])) == nil, "malformed page rejected")
        check((try? MassMessagePayload.records(["unexpected": []])) == nil, "missing records rejected")
        check(!parsed.hasMore(page: 1), "server total ends pagination")
        let selected = [MassMessageRecipient(uid: "same", isGroup: false, name: "user"), MassMessageRecipient(uid: "same", isGroup: true, name: "group")]
        check(Set(selected.map(\.id)).count == 2, "group and user IDs remain distinct")
        check((try? MassMessagePayload.validate(text: "hi", label: "", recipients: [], reusing: nil, type: 0)) == nil, "empty recipients rejected")
        check((try? MassMessagePayload.validate(text: "  \n", label: "", recipients: selected, reusing: nil, type: 0)) == nil, "blank text rejected")
        check((try? MassMessagePayload.validate(text: "hi", label: String(repeating: "🙂", count: 9), recipients: selected, reusing: nil, type: 0)) == nil, "label UTF16 limit enforced")
        let client = FakeClient(); client.pages[1] = .init(records: [record], total: 30)
        let store = MassMessageStore(context: context, client: client, updatePreview: { _ in })
        await store.reload(); check(store.records.count == 1 && store.hasMore, "history loads")
        client.loadError = true; await store.loadMore(); check(store.records.count == 1 && store.errorMessage == "offline", "page failure preserves records")
        client.loadError = false; client.pages[2] = .init(records: [record], total: 30)
        await store.loadMore(); check(client.loaded == [1, 2, 2] && store.records.count == 1, "failed page retried without duplicate rows")
        client.deleteError = true; let failedDelete = await store.delete(record); check(!failedDelete && store.records.count == 1, "delete failure preserves record")
        client.deleteError = false; let deleted = await store.delete(record); await store.reload()
        check(deleted && store.records.isEmpty, "late history cannot resurrect deleted task")
        client.suspend = true
        let pending = Task { await store.reload() }
        while client.suspendedLoad == nil { await Task.yield() }
        store.close(); client.suspendedLoad?.resume(returning: .init(records: [record], total: 1)); client.suspendedLoad = nil
        await pending.value; check(store.records.isEmpty && !store.loading, "closed history ignores late callback")
        let recipients = MassMessageRecipientsStore(context: context, record: record, failures: true, client: FakeClient())
        await recipients.reload(); check(recipients.recipients.count == 2 && !recipients.hasMore, "recipient page keeps both target kinds")
        let sendClient = FakeClient(); sendClient.sendError = true
        let composer = MassMessageComposerStore(context: context, client: sendClient)
        composer.selection = selected; composer.text = "你好🙂\n第二行"; composer.label = "测试"
        let failed = await composer.send()
        check(!failed && composer.text == "你好🙂\n第二行" && composer.selection.count == 2, "failed send preserves draft and recipients")
        sendClient.sendError = false; let success = await composer.send()
        check(success && sendClient.createCount == 1 && sendClient.sendCount == 2, "retry reuses confirmed recipient group")
        let duplicate = await composer.send(); check(!duplicate && sendClient.sendCount == 2, "accepted submission cannot be duplicated")
        let body = try JSONSerialization.jsonObject(with: Data(sendClient.sentBody.utf8)) as! [String: Any]
        check(body["content"] as? String == "你好🙂\n第二行", "wire preserves text and newline")
        let againClient = FakeClient(); let again = MassMessageComposerStore(context: context, reusing: record, client: againClient)
        check(again.canSubmit, "resend uses existing receiver group")
        let resent = await again.send(); check(resent && againClient.createCount == 0 && againClient.sentLabel == "label", "resend does not recreate label")
        var allowed = true
        let revokeClient = FakeClient(); revokeClient.onCreate = { allowed = false }
        let revoke = MassMessageComposerStore(context: context, client: revokeClient, allowed: { allowed })
        revoke.selection = selected; revoke.text = "hello"; let revoked = await revoke.send()
        check(!revoked && revokeClient.sendCount == 0, "permission revoked between create and send blocks submission")
        var current = true
        let staleClient = FakeClient(); staleClient.onCreate = { current = false }
        let stale = MassMessageComposerStore(context: context, client: staleClient, isCurrent: { _ in current })
        stale.selection = selected; stale.text = "hello"; let staleResult = await stale.send()
        check(!staleResult && staleClient.sendCount == 0, "AUTH change between requests blocks send")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try Data("sample".utf8).write(to: file)
        let attachment = ChatAttachment(file: file, type: 5, name: "报告.pdf", bytes: 6)
        let attachmentBody = MassMessageComposerStore.attachmentBody(attachment, uploaded: .init(resource: "cloud/file", thumbnail: ""))
        check(attachmentBody["path"] as? String == "cloud/file" && attachmentBody["name"] as? String == "报告.pdf", "file wire keeps name separate from resource")
        let mediaComposer = MassMessageComposerStore(context: context, client: FakeClient()); mediaComposer.replaceAttachment(attachment); mediaComposer.close()
        check(!FileManager.default.fileExists(atPath: file.path), "closing draft releases temporary attachment")
        print("\(count) mass message checks passed")
    }
}
