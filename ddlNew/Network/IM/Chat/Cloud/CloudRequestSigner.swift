// Created by taobo on 2026/10/13.
import Foundation
import CryptoKit

/// Foundation 上传复用旧端供应商协议，避免引入四套云 SDK；签名文档见 Docs/CHAT_CLOUD_TRANSPORT.md。
nonisolated enum CloudRequestSigner {
    /// 按供应商规范签署当前URL、方法、头与内容摘要，临时Token始终随请求携带。
    static func sign(_ original: URLRequest, provider: CloudStorageProvider, credentials: CloudMediaCredentials,
                     bucket: String, objectKey: String, region: String, payloadHash: String, date: Date = Date()) throws -> URLRequest {
        guard let url = original.url, let host = url.host, !credentials.accessKey.isEmpty,
              !credentials.secretKey.isEmpty, credentials.expires > date,
              date.timeIntervalSince1970.isFinite, date.timeIntervalSince1970 >= 0,
              credentials.expires.timeIntervalSince1970.isFinite,
              credentials.expires.timeIntervalSince1970 <= 253_402_300_799 else { throw URLError(.badURL) }
        var request = original
        request.setValue(host + (url.port.map { ":\($0)" } ?? ""), forHTTPHeaderField: "Host")
        switch provider {
        case .amazon:
            guard !region.isEmpty, !payloadHash.isEmpty else { throw URLError(.badURL) }
            request.setValue(format(date, "yyyyMMdd'T'HHmmss'Z'"), forHTTPHeaderField: "x-amz-date")
            request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
            if !credentials.token.isEmpty { request.setValue(credentials.token, forHTTPHeaderField: "x-amz-security-token") }
            let headers = normalizedHeaders(request)
            let names = headers.keys.sorted()
            let canonicalHeaders = names.map { "\($0):\((headers[$0] ?? ""))\n" }.joined()
            let canonical = [request.httpMethod ?? "PUT", encodedPath(url.path), canonicalQuery(url),
                             canonicalHeaders, names.joined(separator: ";"), payloadHash].joined(separator: "\n")
            let day = format(date, "yyyyMMdd"), scope = "\(day)/\(region)/s3/aws4_request"
            let string = "AWS4-HMAC-SHA256\n\(format(date, "yyyyMMdd'T'HHmmss'Z'"))\n\(scope)\n\(sha256(Data(canonical.utf8)))"
            let dayKey = hmac256(Data("AWS4\(credentials.secretKey)".utf8), Data(day.utf8))
            let regionKey = hmac256(dayKey, Data(region.utf8))
            let serviceKey = hmac256(regionKey, Data("s3".utf8))
            let key = hmac256(serviceKey, Data("aws4_request".utf8))
            let signature = hex(hmac256(key, Data(string.utf8)))
            request.setValue("AWS4-HMAC-SHA256 Credential=\(credentials.accessKey)/\(scope),SignedHeaders=\(names.joined(separator: ";")),Signature=\(signature)", forHTTPHeaderField: "Authorization")
        case .aliyun, .huawei:
            guard !bucket.isEmpty else { throw URLError(.badURL) }
            let prefix = provider == .aliyun ? "x-oss-" : "x-obs-"
            request.setValue(format(date, "EEE, dd MMM yyyy HH:mm:ss 'GMT'"), forHTTPHeaderField: "Date")
            if !credentials.token.isEmpty { request.setValue(credentials.token, forHTTPHeaderField: prefix + "security-token") }
            let headers = normalizedHeaders(request)
            let canonicalHeaders = headers.keys.filter { $0.hasPrefix(prefix) }.sorted().map { "\($0):\((headers[$0] ?? ""))\n" }.joined()
            let canonical = [request.httpMethod ?? "PUT", headers["content-md5"] ?? "", headers["content-type"] ?? "", headers["date"] ?? ""].joined(separator: "\n")
                + "\n" + canonicalHeaders + "/\(bucket)/\(objectKey)" + resourceQuery(url)
            let signature = hmac1(Data(credentials.secretKey.utf8), Data(canonical.utf8)).base64EncodedString()
            request.setValue("\(provider == .aliyun ? "OSS" : "OBS") \(credentials.accessKey):\(signature)", forHTTPHeaderField: "Authorization")
        case .tencent:
            request.setValue(credentials.token, forHTTPHeaderField: "x-cos-security-token")
            let headers = normalizedHeaders(request)
            let names = headers.keys.sorted()
            let headerString = names.map { "\(encode($0))=\(encode((headers[$0] ?? "")))" }.joined(separator: "&")
            let query = canonicalQuery(url, lowercaseNames: true)
            let queryNames = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { $0.name.lowercased() }.sorted().joined(separator: ";")
            let httpString = "\((request.httpMethod ?? "PUT").lowercased())\n\(url.path)\n\(query)\n\(headerString)\n"
            let start = Int(date.timeIntervalSince1970), end = min(start + 300, Int(credentials.expires.timeIntervalSince1970))
            let time = "\(start);\(end)"
            let signingKey = hex(hmac1(Data(credentials.secretKey.utf8), Data(time.utf8)))
            let string = "sha1\n\(time)\n\(hex(Insecure.SHA1.hash(data: Data(httpString.utf8))))\n"
            let signature = hex(hmac1(Data(signingKey.utf8), Data(string.utf8)))
            request.setValue("q-sign-algorithm=sha1&q-ak=\(credentials.accessKey)&q-sign-time=\(time)&q-key-time=\(time)&q-header-list=\(names.joined(separator: ";"))&q-url-param-list=\(queryNames)&q-signature=\(signature)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// SHA256正文摘要使用真实上送文件字节，不能用文件名代替。
    static func fileHash(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var hash = SHA256()
        while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty {
            try Task<Never, Never>.checkCancellation(); hash.update(data: bytes)
        }
        return hex(hash.finalize())
    }
    /// 摘要和HMAC统一转成小写十六进制。
    private static func hex<S: Sequence>(_ data: S) -> String where S.Element == UInt8 { data.map { String(format: "%02x", $0) }.joined() }
    /// 计算规范请求的SHA256摘要。
    private static func sha256(_ data: Data) -> String { hex(SHA256.hash(data: data)) }
    /// AWS使用逐级SHA256派生签名键。
    private static func hmac256(_ key: Data, _ data: Data) -> Data { Data(HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))) }
    /// 阿里、腾讯、华为沿用旧SDK的SHA1签名协议。
    private static func hmac1(_ key: Data, _ data: Data) -> Data { Data(HMAC<Insecure.SHA1>.authenticationCode(for: data, using: SymmetricKey(data: key))) }
    /// 签名时间固定UTC和POSIX日历，不受系统地区影响。
    private static func format(_ date: Date, _ template: String) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = template
        return formatter.string(from: date)
    }
    /// 请求头名称排序前转为小写，空白按云协议压缩。
    private static func normalizedHeaders(_ request: URLRequest) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in request.allHTTPHeaderFields ?? [:] where key.lowercased() != "authorization" {
            headers[key.lowercased()] = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
        return headers
    }
    /// 签名URL只使用RFC3986不保留字符，避免空格和美元符号歧义。
    private static func encode(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")) ?? "" }
    /// S3路径保留斜杠，各段单独编码且不二次编码百分号。
    private static func encodedPath(_ path: String) -> String { path.split(separator: "/", omittingEmptySubsequences: false).map { encode(String($0)) }.joined(separator: "/") }
    /// 查询参数按编码后的名称和值排序，空值保留等号。
    private static func canonicalQuery(_ url: URL, lowercaseNames: Bool = false) -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let encoded: [(String, String)] = items.map { (encode(lowercaseNames ? $0.name.lowercased() : $0.name), encode($0.value ?? "")) }
        let sorted = encoded.sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1 < rhs.1 }
            return lhs.0 < rhs.0
        }
        return sorted.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }

    /// OSS/OBS规范将合法子资源纳入资源签名，普通查询参数不参与该项。
    private static func resourceQuery(_ url: URL) -> String {
        let supported: Set<String> = ["acl", "uploads", "uploadId", "partNumber", "versionId", "versions", "versioning", "delete", "append", "position", "tagging", "objectMeta", "x-oss-process", "x-image-process"]
        let items = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).filter { supported.contains($0.name) }
            .sorted { $0.name == $1.name ? ($0.value ?? "") < ($1.value ?? "") : $0.name < $1.name }
        guard !items.isEmpty else { return "" }
        return "?" + items.map { item in
            guard let value = item.value, !value.isEmpty else { return item.name }
            return "\(item.name)=\(value)"
        }.joined(separator: "&")
    }
}
