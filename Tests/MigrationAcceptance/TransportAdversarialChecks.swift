//
//  TransportAdversarialChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import CommonCrypto
import ObjectMapper

@main struct TransportAdversarialChecks {
    static var failed = 0
    static var checked = 0
    /// 固定虚构字节与凭据只在离线内存，云签名从不访问网络。
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ddlNew-qa-transport-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let plain = Data((0..<8193).map { UInt8($0 % 251) })
        let aes = try aesFixture(plain)
        check(try LegacyChatMediaCodec.decode(aes) == plain, "AESv2 非整块多字节正文往返")
        var invalidVersion = aes; invalidVersion[3] = 1
        check(rejects { _ = try LegacyChatMediaCodec.decode(invalidVersion) }, "AESv2 非2版本拒绝")
        check(rejects { _ = try LegacyChatMediaCodec.decode(Data(aes.prefix(25))) }, "AESv2 参数不足拒绝")
        check(rejects { _ = try LegacyChatMediaCodec.decode(Data(aes.dropLast())) }, "AESv2 密文截断拒绝")
        var corrupted = aes; corrupted[corrupted.count - 1] ^= 0x7f
        check(rejects { _ = try LegacyChatMediaCodec.decode(corrupted) }, "AESv2 PKCS7损坏拒绝")
        check(rejects { _ = try LegacyChatMediaCodec.decode(Data("XOR".utf8)) }, "XOR短包装拒绝")
        for size in [0, 1, 127, 128, 383, 384] {
            let file = directory.appendingPathComponent("short-\(size).png")
            let bytes = Data(repeating: 0x3a, count: size); try bytes.write(to: file)
            let uploaded = try LegacyChatMediaCodec.prepareUpload(file: file, type: 1)
            defer { if uploaded != file { try? FileManager.default.removeItem(at: uploaded) } }
            let result = try Data(contentsOf: uploaded)
            check(size < 384 ? uploaded == file : result.prefix(3) == Data("XOR".utf8), "XOR包装边界\(size)")
            check(try LegacyChatMediaCodec.decode(result) == bytes, "XOR短文件\(size)往返")
        }
        let largeFile = directory.appendingPathComponent("cancel.png")
        try Data(repeating: 0x52, count: 2 * 1024 * 1024).write(to: largeFile)
        // 旧群头像入口isEncrypt:YES，101应沿图片包装而非直接原文上传。
        let avatarUpload = try LegacyChatMediaCodec.prepareUpload(file: largeFile, type: 101)
        defer { if avatarUpload != largeFile { try? FileManager.default.removeItem(at: avatarUpload) } }
        let avatarBytes = try Data(contentsOf: avatarUpload)
        check(avatarBytes.prefix(3) == Data("XOR".utf8), "CHAT-034 群头像101沿旧图片XOR包装")
        check(try LegacyChatMediaCodec.decode(avatarBytes) == Data(contentsOf: largeFile), "CHAT-034 群头像101包装可解码")
        let cancellation = Task { () throws -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try LegacyChatMediaCodec.prepareUpload(file: largeFile, type: 1); return false }
            catch is CancellationError { return true }
        }
        check(try await cancellation.value, "流式媒体包装取消抛错")
        let hashCancellation = Task { () throws -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try CloudRequestSigner.fileHash(largeFile); return false }
            catch is CancellationError { return true }
        }
        check(try await hashCancellation.value, "云正文摘要取消抛错")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fixture = CloudMediaCredentials(accessKey: "qa-fiction-id", secretKey: "qa-fiction-key", token: "qa-fiction-token", expires: now.addingTimeInterval(3600))
        for provider in [CloudStorageProvider.aliyun, .amazon, .tencent, .huawei] {
            let base = try signed(provider, credential: fixture, date: now)
            let alternateMethod = try signed(provider, credential: fixture, method: "GET", date: now)
            let alternatePath = try signed(provider, credential: fixture, path: "chat/other.bin", date: now)
            let alternateType = try signed(provider, credential: fixture, contentType: "text/plain", date: now)
            check(base != alternateMethod, "\(provider.rawValue)签名绑定HTTP方法")
            check(base != alternatePath, "\(provider.rawValue)签名绑定对象路径")
            check(base != alternateType, "\(provider.rawValue)签名绑定Content-Type")
            let expired = CloudMediaCredentials(accessKey: fixture.accessKey, secretKey: fixture.secretKey, token: fixture.token, expires: now)
            check(rejects { _ = try signed(provider, credential: expired, date: now) }, "\(provider.rawValue)过期凭据拒绝")
        }
        let awsA = try signed(.amazon, credential: fixture, query: "b=2&a=1&a=0", date: now)
        let awsB = try signed(.amazon, credential: fixture, query: "a=0&a=1&b=2", date: now)
        check(awsA == awsB, "AWS查询排序与重复键规范化")
        check(awsA != (try signed(.amazon, credential: fixture, query: "a=0&a=1&b=3", date: now)), "AWS查询参数值绑定")
        check((try signed(.amazon, credential: fixture, hash: String(repeating: "a", count: 64), date: now)) != (try signed(.amazon, credential: fixture, hash: String(repeating: "b", count: 64), date: now)), "AWS正文摘要绑定")
        check((try signed(.tencent, credential: fixture, query: "Name=one", date: now)) == (try signed(.tencent, credential: fixture, query: "name=one", date: now)), "COS参数名按官方规范转小写")
        for provider in [CloudStorageProvider.aliyun, .huawei] {
            check((try signed(provider, credential: fixture, query: "acl", date: now)) != (try signed(provider, credential: fixture, date: now)), "\(provider.rawValue)合法子资源acl参与签名")
        }
        let keys: [(CloudStorageProvider, [String])] = [(.aliyun, ["aliyunAccessKeyId", "aliyunSecretKeyId", "aliyunSecurityToken", "aliyunExpiration"]), (.amazon, ["awss3AccessKey", "awss3SecretKey", "awss3sessionToken", "awss3Expiration"]), (.tencent, ["tencentsecretId", "tencentsecretKey", "tencentToken", "tencentExpiration"]), (.huawei, ["obsAccessKey", "obsSecretKey", "obsToken", "obsExpiration"])]
        for (provider, names) in keys {
            let fields = Dictionary(uniqueKeysWithValues: zip(names, ["qa-fiction-id", "qa-fiction-key", "qa-fiction-token", String(now.timeIntervalSince1970 + 31)]))
            let shared: [String: Any] = ["accessKeyId": "qa-fiction-id", "accessKeySecret": "qa-fiction-key", "securityToken": "qa-fiction-token", "expiration": String(now.timeIntervalSince1970 + 60)]
            let nested = Mapper<CloudMediaCredentialPayload>().map(JSON: ["credentials": shared])
            check(nested?.credentials(for: provider, now: now)?.accessKey == "qa-fiction-id", "\(provider.rawValue)真实STS credentials包装必须可用")
            check(nested?.toJSON().isEmpty == true, "\(provider.rawValue)真实STS包装不可序列化")
            var missingShared = shared; missingShared.removeValue(forKey: "securityToken")
            check(Mapper<CloudMediaCredentialPayload>().map(JSON: ["credentials": missingShared])?.credentials(for: provider, now: now) == nil, "\(provider.rawValue)真实STS缺Token必须拒绝")
            var expiredShared = shared; expiredShared["expiration"] = String(now.timeIntervalSince1970 + 30)
            check(Mapper<CloudMediaCredentialPayload>().map(JSON: ["credentials": expiredShared])?.credentials(for: provider, now: now) == nil, "\(provider.rawValue)真实STS临近过期拒绝")
            var mixed: [String: Any] = fields; mixed["credentials"] = [:] as [String: Any]
            check(Mapper<CloudMediaCredentialPayload>().map(JSON: mixed)?.credentials(for: provider, now: now) == nil, "\(provider.rawValue)显式损坏真实包装不能回退旧前缀凭据")
            let valid = Mapper<CloudMediaCredentialPayload>().map(JSON: fields)!
            check(valid.credentials(for: provider, now: now) != nil, "\(provider.rawValue)STS完整且剩余31秒可用")
            for expiry in [String(now.timeIntervalSince1970 + 30), "0", "NaN", "Infinity", "1e308", "invalid"] {
                var broken = fields; broken[names[3]] = expiry
                check(Mapper<CloudMediaCredentialPayload>().map(JSON: broken)?.credentials(for: provider, now: now) == nil, "\(provider.rawValue)STS不足期限或损坏拒绝")
            }
            var milliseconds = fields; milliseconds[names[3]] = String((now.timeIntervalSince1970 + 60) * 1000)
            check(Mapper<CloudMediaCredentialPayload>().map(JSON: milliseconds)?.credentials(for: provider, now: now)?.expires == now.addingTimeInterval(60), "\(provider.rawValue)STS毫秒期限规范化")
            var missing = fields; missing[names[2]] = ""
            check(Mapper<CloudMediaCredentialPayload>().map(JSON: missing)?.credentials(for: provider, now: now) == nil, "\(provider.rawValue)STS缺Token拒绝")
            missing[names[2]] = " \t "
            check(Mapper<CloudMediaCredentialPayload>().map(JSON: missing)?.credentials(for: provider, now: now) == nil, "\(provider.rawValue)STS纯空白Token拒绝")
            check(valid.toJSON().isEmpty, "\(provider.rawValue)STS不可序列化持久化")
        }
        print("Independent transport acceptance: \(checked-failed)/\(checked) passed; \(failed) failed")
        if failed > 0 { exit(1) }
    }
    /// 用CommonCrypto独立构造测试包装，避免用解码实现反推密文。
    static func aesFixture(_ input: Data) throws -> Data {
        let key = Data((0..<32).map(UInt8.init)); let iv = Data((32..<48).map(UInt8.init))
        var encrypted = Data(count: input.count + kCCBlockSizeAES128); let capacity = encrypted.count
        var moved = 0
        let result = input.withUnsafeBytes { plain in key.withUnsafeBytes { keyBytes in iv.withUnsafeBytes { ivBytes in encrypted.withUnsafeMutableBytes { out in
            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), keyBytes.baseAddress, key.count, ivBytes.baseAddress, plain.baseAddress, input.count, out.baseAddress, capacity, &moved)
        } } } }
        guard result == kCCSuccess else { throw CocoaError(.fileReadCorruptFile) }
        encrypted.count = moved
        return Data("AES".utf8) + Data([2]) + key + iv + encrypted
    }
    /// 签名变体使用完全虚构身份，不输出Authorization头或安全Token。
    static func signed(_ provider: CloudStorageProvider, credential: CloudMediaCredentials, method: String = "PUT", path: String = "chat/test.bin", query: String? = nil, contentType: String = "application/octet-stream", hash: String = String(repeating: "a", count: 64), date: Date) throws -> String {
        var components = URLComponents(string: "https://qa-bucket.example.invalid/" + path)!
        if let query { components.percentEncodedQuery = query }
        var request = URLRequest(url: components.url!); request.httpMethod = method; request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        return try CloudRequestSigner.sign(request, provider: provider, credentials: credential, bucket: "qa-bucket", objectKey: path, region: "qa-region", payloadHash: hash, date: date).value(forHTTPHeaderField: "Authorization") ?? ""
    }
    /// 异常路径必须真正抛错，不能只打印被拒绝。
    static func rejects(_ work: () throws -> Void) -> Bool { do { try work(); return false } catch { return true } }
    /// 保留每个独立断言的清晰结果。
    static func check(_ result: Bool, _ label: String) { checked += 1; if !result { failed += 1 }; print("\(result ? "PASS" : "FAIL") \(label)") }
}
