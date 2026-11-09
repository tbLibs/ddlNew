import Foundation
@MainActor final class FakeClient: PushClient {
 var binds:[String] = []; var removed:[String] = []; var settings = PushPreferences(); var fail = false
 var holdBind = false; var bindWaiter: CheckedContinuation<Void,Never>?
 var holdSave = false; var saveWaiter: CheckedContinuation<Void,Never>?
 var callback: ((PushEvent)->Void)?
 func bind(token:String, identity:PushIdentity) async throws { binds.append(identity.userUID+token); if holdBind { await withCheckedContinuation { bindWaiter=$0 } } }
 func unbind(token:String, identity:PushIdentity) async { removed.append(identity.userUID+token) }
 func loadPreferences(identity:PushIdentity) async throws -> PushPreferences { settings }
 func savePreferences(_ value:PushPreferences, identity:PushIdentity) async throws { if holdSave { await withCheckedContinuation { saveWaiter=$0 } }; if fail { throw NSError(domain:"test",code:1) }; settings=value }
 func observe(identity:PushIdentity, received:@escaping @MainActor (PushEvent)->Void) { callback=received }
 func stopObserving() { callback=nil }
}
@MainActor final class FakeSystem: PushSystemClient {
 var posted = 0; var sounds = 0; var clears = 0
 func requestPermission() async -> String { "已开启" }
 func permissionStatus() async -> String { "已开启" }
 func registerRemote() {}
 func post(_ event:PushEvent, identity:PushIdentity, sound:Bool) async { posted += 1 }
 func remove(_ event:PushEvent, identity:PushIdentity) {}
 func clear() { clears += 1 }
 func play(sound:Bool, vibration:Bool) { sounds += 1 }
 func badge(_ count:Int) {}
}
@main struct Checks {
 @MainActor static func main() async {
  let client=FakeClient(), system=FakeSystem()
  let defaults=UserDefaults(suiteName:"PushChecks.\(UUID())")!
  let c=PushCoordinator(client:client,system:system,defaults:defaults)
  let a=PushIdentity(userUID:"a",tenantID:"t",sessionID:UUID())
  c.receivedToken("token"); c.activate(identity:a)
  for _ in 0..<50 { await Task.yield() }
  precondition(client.binds == ["atoken"], "token first binds")
  c.receivedToken("token"); for _ in 0..<20 { await Task.yield() }
  precondition(client.binds.count == 1,"no duplicate bind")
  client.fail=true; await c.savePreferences(.init(enabled:false))
  precondition(c.preferences.enabled && c.errorMessage != nil,"failed save retains confirmed settings")
  await c.prepareSignOut(); c.close()
  precondition(client.removed == ["atoken"] && c.identity == nil,"unbind and revoke")
  let b=PushIdentity(userUID:"b",tenantID:"t",sessionID:UUID())
  c.activate(identity:b); for _ in 0..<50 { await Task.yield() }
  precondition(client.binds.last == "btoken","new account binds")
  c.receiveClick(PushPayload(destination:.friends,userUID:"a",tenantID:"t"), cachedOwner:nil)
  precondition(c.pendingNavigation == nil,"old account click discarded")
  c.receiveClick(PushPayload(destination:.friends,userUID:"b",tenantID:"t"), cachedOwner:nil)
  precondition(c.pendingNavigation != nil,"current click queued")
  c.close(); precondition(c.pendingNavigation == nil,"logout clears navigation")
  client.fail=false; client.holdBind=true
  c.activate(identity:a)
  for _ in 0..<30 { await Task.yield() }
  c.close(); c.activate(identity:b)
  client.holdBind=false; client.bindWaiter?.resume(); client.bindWaiter=nil
  for _ in 0..<80 { await Task.yield() }
  precondition(client.binds.last == "btoken","late old bind converges to current owner")
  client.holdSave=true
  let save=Task { await c.savePreferences(.init(enabled:false)) }
  for _ in 0..<30 { await Task.yield() }
  c.close(); let sameUserNewRun=PushIdentity(userUID:"b",tenantID:"t",sessionID:UUID()); c.activate(identity:sameUserNewRun)
  for _ in 0..<30 { await Task.yield() }
  client.holdSave=false; client.saveWaiter?.resume(); client.saveWaiter=nil; await save.value
  precondition(c.preferences.enabled,"old save cannot write new login state")
  c.setForeground(false)
  client.callback?(PushEvent(id:"live",destination:.friends,title:"好友",body:"申请",muted:false,fromSelf:false))
  for _ in 0..<20 { await Task.yield() }
  precondition(system.posted == 1,"background posts")
  client.callback?(PushEvent(id:"live",destination:.friends,title:"好友",body:"申请",muted:false,fromSelf:false))
  for _ in 0..<20 { await Task.yield() }
  precondition(system.posted == 1,"duplicate suppressed")
  c.close()
  c.receiveClick(PushPayload(destination:.friends),cachedOwner:(userUID:"b",tenantID:"t"))
  c.activate(identity:sameUserNewRun)
  precondition(c.pendingNavigation?.matches(sameUserNewRun) == true,"cold pending click survives same owner restoration")
  c.close()
  print("Push coordinator: 13 checks passed")
 }
}
