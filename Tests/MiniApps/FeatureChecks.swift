import Foundation
import Combine

struct ChatRoute: Equatable { let id: String; let kind: Int; let title: String; let avatarURL: String }
extension Int { static var single: Int { 0 } }
struct ChatContext: Equatable { let userUID: String; let tenantID: String; let sessionID: UUID; let route: ChatRoute }
@MainActor final class ChatRuntime {
 static let shared = ChatRuntime()
 var user = "test"; var session = UUID(); var enabled = true
 func context(for route: ChatRoute) -> ChatContext? { enabled ? ChatContext(userUID:user,tenantID:"test",sessionID:session,route:route) : nil }
 func isCurrent(_ c: ChatContext) -> Bool { enabled && c.userUID == user && c.sessionID == session }
 func registerCleanup(owner: AnyObject, action: @escaping @MainActor () -> Void) {}
}
final class WKWebsiteDataStore { static func nonPersistent() -> WKWebsiteDataStore { .init() } }
@MainActor final class MiniAppWebSession: Identifiable {
 let id: String; let title: String; let icon: String; let entryURL: URL; let currentURL: URL
 var closed = false; var suspended = false
 init(id:String,title:String,icon:String,url:URL,entryURL:URL? = nil,dataStore:WKWebsiteDataStore) { self.id=id;self.title=title;self.icon=icon;self.entryURL=entryURL ?? url;currentURL=url }
 func close() { closed=true }
 func suspend(_ value:Bool) { suspended=value }
}
@MainActor final class SDKMiniAppClient: MiniAppClient {
 static var records: [MiniAppRecord] = []
 func list(page:Int,context:ChatContext) async throws -> MiniAppPage { MiniAppPage(items:Self.records,hasMore:false) }
 func save(_ draft:MiniAppDraft,editing:MiniAppRecord?,context:ChatContext) async throws {}
 func delete(_ record:MiniAppRecord,context:ChatContext) async throws {}
 func detail(id:String,password:String,context:ChatContext) async throws -> MiniAppRecord {
  guard let record=Self.records.first(where:{$0.id==id}) else {throw MiniAppError.invalid("missing")};return record
 }
 func upload(_ file:URL,context:ChatContext) async throws -> String { "" }
 func cancel() {}
}
@MainActor final class SDKMiniAppFloatClient: MiniAppFloatClient {
 var values:[MiniAppFloatRecord]=[];var fail=false
 func load(context:ChatContext) throws -> [MiniAppFloatRecord] {values}
 func save(_ record:MiniAppFloatRecord,context:ChatContext) throws {if fail {throw MiniAppError.invalid("failed")};values.removeAll{$0.id==record.id};values.append(record)}
 func delete(id:String,context:ChatContext) throws {values.removeAll{$0.id==id}}
 func clear(context:ChatContext) throws {values=[]}
}
@main struct Checks {
 @MainActor static func main() async {
  func app(_ id:String="a",_ url:String="https://example.com",_ password:Bool=false)->MiniAppRecord {MiniAppRecord(id:id,name:id,url:url,icon:"",passwordEnabled:password,appType:1,allowUserDelete:1)}
  let client=SDKMiniAppFloatClient();let feature=MiniAppsFeature(floatClient:client);feature.activate()
  feature.open(app("a", "example.com"));let first=feature.active!
  precondition(first.entryURL.absoluteString == "https://example.com", "省略协议的网站打开时补https")
  feature.finish(minimized:true)
  precondition(feature.active==nil && feature.floats.count==1 && first.suspended && !first.closed)
  feature.open(app());precondition(feature.active === first,"same session must restore history")
  feature.open(app("a","https://other.example.com"));precondition(first.closed && feature.active !== first,"edited URL must evict old webpage")
  feature.finish(minimized:true)
  feature.close();feature.activate()
  feature.open(app(),restoring:MiniAppFloatRecord(id:"a",title:"a",url:"https://example.com/nested",icon:""))
  let nested=feature.active!;feature.finish(minimized:true);feature.open(app())
  precondition(feature.active === nested,"restored subpath must retain history on next open")
  client.fail=true;let last=feature.active!;feature.finish(minimized:false)
  precondition(feature.active==nil && last.closed,"failed persistence must not trap Close")
  client.fail=false
  SDKMiniAppClient.records=[app("a","https://example.com",true)]
  feature.selectFloat(feature.floats[0]);feature.floatListDismissed()
  for _ in 0..<100 where feature.passwordRequest == nil {try? await Task.sleep(nanoseconds:1_000_000)}
  precondition(feature.passwordRequest?.id=="a" && feature.active==nil,"protected restore must require password")
  feature.acceptRestore(SDKMiniAppClient.records[0]);precondition(feature.active==nil,"wait for sheet dismissal")
  feature.passwordDismissed();precondition(feature.active?.id=="a")
  let old=feature.active!;ChatRuntime.shared.session=UUID();feature.activate()
  precondition(old.closed && feature.active==nil,"same UID new AUTH must release webpage")
  feature.open(app());ChatRuntime.shared.enabled=false;feature.close()
  feature.open(app());precondition(feature.active==nil && feature.floats.isEmpty,"closed auth cannot reopen")
  print("PASS: float lifecycle, same-session history, edited URL eviction, close escape, password restore, AUTH isolation")
 }
}
