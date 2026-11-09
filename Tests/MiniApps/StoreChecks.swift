import Foundation
struct ChatContext { let userUID = "u"; let tenantID = "t" }
@MainActor final class Mock: MiniAppClient {
 var fail = false
 var calls = 0
 var saves = 0
 var suspended = false
 var pending: CheckedContinuation<MiniAppPage, Error>?
 var uploadPending: CheckedContinuation<String, Error>?
 var suspendUpload = false
 var password = ""
 func list(page: Int, context: ChatContext) async throws -> MiniAppPage { calls += 1; if suspended { return try await withCheckedThrowingContinuation { pending = $0 } }; if fail { throw MiniAppError.invalid("failed") }; return MiniAppPage(items: [], hasMore: false) }
 func save(_ draft: MiniAppDraft, editing: MiniAppRecord?, context: ChatContext) async throws { saves += 1; if fail { throw MiniAppError.invalid("failed") } }
 func delete(_ record: MiniAppRecord, context: ChatContext) async throws {}
 func detail(id: String, password: String, context: ChatContext) async throws -> MiniAppRecord { self.password = password; return MiniAppRecord(id: id, name: "", url: "", icon: "", passwordEnabled: true, appType: 1, allowUserDelete: 0) }
 func upload(_ file: URL, context: ChatContext) async throws -> String { if suspendUpload { return try await withCheckedThrowingContinuation { uploadPending = $0 } }; return "icon" }
 func cancel() {}
}
@main struct Checks {
 @MainActor static func main() async throws {
  let client = Mock(); var current = true
  let store = MiniAppsStore(context: ChatContext(), client: client, isCurrent: { _ in current })
  client.fail = true; await store.refresh(); precondition(!store.hasLoaded && store.feedback != nil)
  client.fail = false; await store.refresh(); precondition(store.hasLoaded && !store.hasMore && client.calls == 2)
  var draft = MiniAppDraft(); draft.name = "test"; draft.url = "https://example.com"
  client.fail = true; let failed = await store.save(draft); precondition(!failed)
  let record = try await store.detail(id: "a", password: " secret "); precondition(client.password == " secret " && record.id == "a")
  current = false; let invalid = await store.unlock(record, password: "p"); precondition(invalid == nil)
  store.close(); precondition(store.items.isEmpty && !store.isBusy)
  let c = Mock(); let active = MiniAppsStore(context: ChatContext(), client: c, isCurrent: { _ in true })
  c.suspended = true
  let saving = Task { await active.save(draft) }
  while c.pending == nil { await Task.yield() }
  precondition(active.isBusy)
  let duplicate = await active.save(draft)
  precondition(!duplicate && c.saves == 1)
  c.pending?.resume(throwing: MiniAppError.invalid("reload")); c.pending = nil
  let accepted = await saving.value
  precondition(accepted && active.feedback == "操作已完成，列表刷新失败，请刷新重试")
  let oldLoad = Task { await active.refresh() }
  while c.pending == nil { await Task.yield() }
  let old = c.pending; c.pending = nil
  let deleting = Task { await active.delete(record) }
  while c.pending == nil { await Task.yield() }
  c.pending?.resume(returning: MiniAppPage(items: [], hasMore: false)); c.pending = nil
  let deleted = await deleting.value
  precondition(deleted)
  old?.resume(returning: MiniAppPage(items: [record], hasMore: false))
  await oldLoad.value
  precondition(active.items.isEmpty && active.feedback == nil)
  let staleFail = Task { await active.refresh() }
  while c.pending == nil { await Task.yield() }
  let stale = c.pending; c.pending = nil
  let mutation = Task { await active.save(draft) }
  while c.pending == nil { await Task.yield() }
  c.pending?.resume(throwing: MiniAppError.invalid("new")); c.pending = nil
  _ = await mutation.value
  let expected = active.feedback
  stale?.resume(throwing: MiniAppError.invalid("stale")); await staleFail.value
  precondition(active.feedback == expected)
  let uploader = Mock(); uploader.suspendUpload = true
  let closing = MiniAppsStore(context: ChatContext(), client: uploader, isCurrent: { _ in true })
  let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try Data([1]).write(to: temporary)
  let upload = Task { await closing.save(draft, iconFile: temporary) }
  while uploader.uploadPending == nil { await Task.yield() }
  closing.close(); uploader.uploadPending?.resume(returning: "icon")
  let closedResult = await upload.value
  precondition(!closedResult && uploader.saves == 0)
  print("MiniApp store checks passed")
 }
}
