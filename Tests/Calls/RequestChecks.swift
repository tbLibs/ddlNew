import Foundation
struct ChatContext {}
typealias LingIMSuccessCallback = (Any?, String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
enum AccountLoginError: Error { case timedOut, invalidResponse }

@main struct RequestChecks {
    @MainActor static func main() async {
        var failures = 0, checks = 0
        func check(_ value: Bool, _ name: String) {
            checks += 1; if !value { failures += 1 }
            print("\(value ? "PASS" : "FAIL") \(name)")
        }
        let client = RequestHarness()
        for (code, message, expected) in [
            (910004, "", "用户不在线"),
            (910004, "User is offline", "用户不在线"),
            (910001, "", "对方正在通话中"),
            (900019, "", "你已经被拉黑"),
            (999999, "暂时无法呼叫", "暂时无法呼叫"),
            (999999, "   ", "通话请求失败，请稍后重试")
        ] {
            do {
                _ = try await client.request(context: ChatContext()) { _, fail in fail(code, message, nil) }
                check(false, "server rejection must throw")
            } catch { check(error.localizedDescription == expected, "server error \(code) preserves business feedback") }
        }
        do {
            let value = try await client.request(context: ChatContext()) { success, fail in
                success(["hash": "room"], nil); fail(910004, "", nil)
            }
            check(value["hash"] as? String == "room", "first successful callback wins")
        } catch { check(false, "success decoding") }
        do {
            _ = try await client.request(context: ChatContext()) { success, fail in
                fail(910004, nil, nil); success(["hash": "room"], nil)
            }
            check(false, "first rejection must not become success")
        } catch { check(error.localizedDescription == "用户不在线", "first failed callback wins") }
        do {
            _ = try await client.request(context: ChatContext()) { _, fail in
                client.valid = false; fail(910004, "", nil)
            }
            check(false, "stale response must be discarded")
        } catch { check(error is CancellationError, "identity change suppresses stale server error") }
        print("\(checks - failures)/\(checks) request checks passed")
        if failures > 0 { exit(1) }
    }
}
