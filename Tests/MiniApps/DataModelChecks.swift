import Foundation
@main struct Checks {
 static func main() throws {
  let row: [String: Any] = ["qaUuid": 42, "appType": "1"]
  for pages: Any in [2, "2"] {
   let result = try MiniAppPage.parse(["items": [row], "pages": pages], page: 1)
   precondition(result.hasMore && result.items.first?.id == "42")
  }
  let last = try MiniAppPage.parse(["items": [], "pages": 1], page: 1)
  precondition(!last.hasMore)
  for bad: Any in [NSNull(), [], ["records": [], "pages": 0]] {
   do { _ = try MiniAppPage.parse(bad, page: 1); fatalError("accepted invalid payload") } catch {}
  }
  let unknown = try MiniAppPage.record(["qaUuid": "x", "allowUserDelete": 1])
  precondition(!unknown.canEdit && !unknown.canDelete)
  var draft = MiniAppDraft(); draft.name = "test"; draft.url = "https://u:p@example.com"
  precondition(draft.validationMessage != nil)
  draft.url = "https://example.com"; draft.passwordEnabled = true; draft.password = "  "
  precondition(draft.validationMessage != nil)
  for value in ["1", "中文", String(repeating: "x", count: 2048)] {
   draft.password = value
   precondition(draft.validationMessage == nil, "应用密码不限制长度")
  }
  draft.url = "example.com/path?q=1"
  precondition(draft.validationMessage == nil, "网站地址不要求手动输入协议")
  print("MiniApp model checks passed")
 }
}
