import Foundation
import CryptoKit
import Darwin

/// Developer-only, read-only evidence capture. Raw responses and secrets stay in memory.
@main struct DNS1ReviewCapture {
    @MainActor static func main() async {
        do {
            guard let input = readLine() else { throw DNS1Error.invalidLicense }
            let license = try DNS1Payload.license(input)
            let started = timestamp()
            let records = try await DNS1DoHClient.records(domain: "t" + license.lowercased() + "." + dns1MainDomain)
            let dns = try DNS1Payload.records(records)
            let dnsText = try recordText(records)
            guard try DNS1Payload.decode(dnsText, requireJSON: false) == dns else { throw DNS1Error.invalidPayload }
            let dnsTime = timestamp()

            guard let url = URL(string: dns1BinURLTemplate.replacingOccurrences(of: "%s", with: license)),
                  url.scheme == "https" else { throw DNS1Error.invalidPayload }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 5
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_048_576 else { throw DNS1Error.unavailable }
            let bin = try DNS1Payload.bin(data, license: license)
            let binText = try decryptedText(data, license: license)
            guard try DNS1Payload.decode(binText, requireJSON: true) == bin else { throw DNS1Error.invalidPayload }

            var redactor = Redactor()
            let dnsRedacted = redactor.payload(dns)
            let binRedacted = redactor.payload(bin)
            let report: [String: Any] = [
                "capture_started_at": started,
                "capture_finished_at": timestamp(),
                "method": "Live main DNS lookup followed by an independent BIN retrieval, using current production request/parser/decryption functions in a macOS command-line harness.",
                "invitation": "User supplied the App Review invitation code; omitted from output.",
                "dns": ["completed_at": dnsTime, "aaaa_record_count": records.count,
                        "decoded_shape": shape(dnsText), "normalized_redacted": dnsRedacted],
                "bin": ["completed_at": timestamp(), "http_status": 200,
                        "download_bytes": data.count, "decoded_shape": shape(binText),
                        "normalized_redacted": binRedacted],
                "tcp_node_sets_match": Set(dns.tcp.map(\.address)) == Set(bin.tcp.map(\.address)),
                "redaction": "Hosts consistently replaced with host-N.example.invalid across both results. Explicit ports consistently replaced with synthetic numbers starting at 40001. HTTP path segments consistently replaced with segment-N. Schemes, normalized array order/counts, and equality relationships preserved. No invitation, account credentials, signed URLs, raw AAAA records, ciphertext, plaintext response bodies or redaction mapping persisted.",
                "scope": "Normalized accepted endpoints, not raw wire data. Parser may filter invalid/duplicate entries; decoded_shape records input counts. No user login, ECDH node probing, messaging, device reconnect, or submitted IPA execution performed. Independent BIN retrieval does not prove automatic fallback occurred."
            ]
            let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            FileHandle.standardOutput.write(json)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            // Errors may embed signed request URLs. Never print error objects.
            FileHandle.standardError.write(Data("Capture failed: input, network or payload validation failed; sensitive details suppressed.\n".utf8))
            exit(1)
        }
    }

    static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: Date())
    }

    /// Inspect original shape only after the production parser accepts the records.
    static func recordText(_ records: [String]) throws -> String {
        var chunks: [Int: [UInt8]] = [:]
        for record in records {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard inet_pton(AF_INET6, record, &bytes) == 1 else { throw DNS1Error.invalidPayload }
            chunks[Int(bytes[0]) * 256 + Int(bytes[1])] = Array(bytes.dropFirst(2))
        }
        let bytes = chunks.keys.sorted().flatMap { chunks[$0]! }.prefix { $0 != 0 }
        guard let text = String(bytes: bytes, encoding: .utf8) else { throw DNS1Error.invalidPayload }
        return text
    }

    @MainActor static func decryptedText(_ data: Data, license: String) throws -> String {
        let secret = Insecure.MD5.hash(data: Data(license.utf8)).map { String(format: "%02x", $0) }.joined()
        var candidates = [data]
        if let text = String(data: data, encoding: .utf8),
           let decoded = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) { candidates.append(decoded) }
        for candidate in candidates {
            if let plain = AesEncryptUtils.decryptBytes(candidate, secret: secret),
               let text = String(data: plain, encoding: .utf8),
               (try? DNS1Payload.decode(text, requireJSON: true)) != nil { return text }
        }
        throw DNS1Error.invalidPayload
    }

    static func shape(_ text: String) -> [String: Any] {
        if let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] {
            return ["format": "JSON object", "has_tcp": object["tcp"] != nil, "has_http": object["http"] != nil,
                    "tcp_input_entries": (object["tcp"] as? [String])?.count ?? 0,
                    "http_input_entries": (object["http"] as? [String])?.count ?? 0,
                    "additional_field_count": object.keys.filter { $0 != "tcp" && $0 != "http" }.count]
        }
        return ["format": "Comma-separated TCP list", "tcp_input_entries": text.components(separatedBy: ",").count,
                "has_http": false]
    }

    struct Redactor {
        var hosts: [String: String] = [:]
        var ports: [Int: Int] = [:]
        var segments: [String: String] = [:]

        mutating func host(_ value: String) -> String {
            let key = value.lowercased()
            if let existing = hosts[key] { return existing }
            let result = "host-\(hosts.count + 1).example.invalid"
            hosts[key] = result
            return result
        }

        mutating func port(_ value: Int) -> Int {
            if let existing = ports[value] { return existing }
            let result = 40001 + ports.count
            ports[value] = result
            return result
        }

        mutating func path(_ value: String) -> String {
            value.components(separatedBy: "/").map { segment in
                guard !segment.isEmpty else { return "" }
                if let existing = segments[segment] { return existing }
                let result = "segment-\(segments.count + 1)"
                segments[segment] = result
                return result
            }.joined(separator: "/")
        }

        mutating func payload(_ value: DNS1Payload) -> [String: [String]] {
            let tcp = value.tcp.map { node in "\(host(node.host)):\(port(Int(node.port)))" }
            let http = value.http.map { url in
                var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                parts.host = host(parts.host!)
                if let originalPort = parts.port { parts.port = port(originalPort) }
                parts.percentEncodedPath = path(parts.percentEncodedPath)
                return parts.string!
            }
            return ["tcp": tcp, "http": http]
        }
    }
}
