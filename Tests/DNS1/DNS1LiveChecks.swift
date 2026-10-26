import Foundation

/// 只读查询服务器节点，不登录、不保存导航，也不输出鉴权参数或节点地址。
@main struct DNS1LiveChecks {
    @MainActor static func main() async {
        do {
            let license = try DNS1Payload.license(CommandLine.arguments[1])
            let domain = "t" + license.lowercased() + "." + dns1MainDomain
            let records = try await DNS1DoHClient.records(domain: domain)
            let dns = try DNS1Payload.records(records)
            let url = URL(string: dns1BinURLTemplate.replacingOccurrences(of: "%s", with: license))!
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 5
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_048_576 else { throw DNS1Error.unavailable }
            let bin = try DNS1Payload.bin(data, license: license)
            guard Set(dns.tcp.map(\.address)) == Set(bin.tcp.map(\.address)) else { throw DNS1Error.invalidPayload }
            print("Live DNS1 passed: AAAA=\(records.count), DNS TCP=\(dns.tcp.count), DNS HTTP=\(dns.http.count), BIN TCP=\(bin.tcp.count), BIN HTTP=\(bin.http.count)")
        } catch {
            // URLSession 错误可能含签名 URL；不要打印错误对象。
            print("FAIL: DNS1 live discovery or DNS/BIN consistency check failed")
            exit(1)
        }
    }
}
