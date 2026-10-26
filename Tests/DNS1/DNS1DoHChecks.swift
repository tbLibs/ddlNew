import Foundation

nonisolated let dns1AccountId = "uid"
nonisolated let dns1AccessKey = "ak"
nonisolated let dns1AccessKeySecret = "secret"

@main struct DNS1DoHChecks {
    static func main() throws {
        let request = try DNS1DoHClient.request(domain: "tab1000.main.example", timestamp: "123",
            endpoint: "https://223.5.5.5/resolve", timeout: 5)
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        precondition(Set(query.keys) == ["name", "type", "uid", "ak", "ts", "key"])
        precondition(query["name"] == "tab1000.main.example" && query["type"] == "AAAA")
        precondition(query["key"] == "cf7c9b0ba765223dfde15646f229048eca2409b7ed2fdb2de1060944a58c81ec")
        let backup = try DNS1DoHClient.request(domain: "tab1000.backup.example", timestamp: "123",
            endpoint: "https://223.6.6.6/resolve", timeout: 3)
        precondition(URLComponents(url: backup.url!, resolvingAgainstBaseURL: false)!.queryItems!
            .first(where: { $0.name == "key" })!.value != query["key"])
        precondition(request.timeoutInterval == 5 && request.cachePolicy == .reloadIgnoringLocalCacheData)
        precondition(request.value(forHTTPHeaderField: "Accept") == "application/dns-json")
        func response(_ code: Int = 200) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        }
        let data = Data(#"{"Status":0,"Answer":[{"type":5,"data":"alias.example"},{"type":28,"data":"::1"}]}"#.utf8)
        let records = try DNS1DoHClient.decode(data, response: response())
        precondition(records == ["::1"])
        for invalid in [#"{"Status":3}"#, #"{"Status":0}"#, #"{"Answer":[{"type":28,"data":"::1"}]}"#, #"{"Status":0,"Answer":[{"type":1,"data":"192.0.2.1"}]}"#, "bad"] {
            do { _ = try DNS1DoHClient.decode(Data(invalid.utf8), response: response()); fatalError("Invalid DNS accepted") }
            catch {}
        }
        do { _ = try DNS1DoHClient.decode(data, response: response(503)); fatalError("HTTP error accepted") }
        catch {}
        print("DNS1 DoH checks passed: signed server-only AAAA query, backup signature, response filtering and errors")
    }
}
