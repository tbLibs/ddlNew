import Foundation
@main struct Checks {
 static func main() {
  precondition(MiniAppWebPolicy.url("https://example.com/a?q=1")?.host == "example.com")
  precondition(MiniAppWebPolicy.url("http://example.com") != nil)
  for (input, expected) in [
   ("example.com/path?q=1#part", "https://example.com/path?q=1#part"),
   ("  www.example.com  ", "https://www.example.com"),
   ("https://example.com/a", "https://example.com/a"),
   ("http://example.com/a", "http://example.com/a"),
   ("example.com:8080/a", "https://example.com:8080/a"),
   ("//example.com/a", "https://example.com/a")
  ] { precondition(MiniAppWebPolicy.entryURL(input)?.absoluteString == expected, input) }
  for input in ["", "/relative/path", "javascript:alert(1)", "file:///tmp/a", "mailto:a@example.com", "https://", "u:p@example.com", "not a website"] {
   precondition(MiniAppWebPolicy.entryURL(input) == nil, input)
  }
  precondition(MiniAppWebPolicy.url("example.com") == nil, "网页内部跳转仍使用严格协议校验")
  for value in ["javascript:alert(1)", "file:///private/data", "https://", "https://u:p@example.com", "data:text/html,x"] {
   precondition(MiniAppWebPolicy.url(value) == nil, "unsafe address accepted: \(value)")
  }
  print("PASS: webpage URL policy, HTTP(S), malformed URLs and credentials")
 }
}
