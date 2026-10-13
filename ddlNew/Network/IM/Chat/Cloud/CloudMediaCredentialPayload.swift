// Created by taobo on 2026/10/13.
import Foundation
import ObjectMapper

/// 服务端 STS 字段只在本次请求内存中映射，不支持序列化到缓存。
nonisolated struct CloudMediaCredentialPayload: Mappable {
    private var fields: [String: String] = [:]
    /// STS必须是字典，具体供应商字段在取用时完整校验。
    init?(map: Map) {}
    /// 保留真实临时凭据字段，明确禁止toJSON输出。
    mutating func mapping(map: Map) {
        guard map.mappingType == .fromJSON else { return }
        for (key, value) in map.JSON {
            if let text = value as? String { fields[key] = text }
            else if let number = value as? NSNumber { fields[key] = number.stringValue }
        }
    }
    /// 校验当前供应商完整凭据与实际失效时间，不缓存、不宽松猜测过期字段。
    func credentials(for provider: CloudStorageProvider, now: Date = Date()) -> CloudMediaCredentials? {
        let names: [String]
        switch provider {
        case .aliyun: names = ["aliyunAccessKeyId", "aliyunSecretKeyId", "aliyunSecurityToken", "aliyunExpiration"]
        case .amazon: names = ["awss3AccessKey", "awss3SecretKey", "awss3sessionToken", "awss3Expiration"]
        case .tencent: names = ["tencentsecretId", "tencentsecretKey", "tencentToken", "tencentExpiration"]
        case .huawei: names = ["obsAccessKey", "obsSecretKey", "obsToken", "obsExpiration"]
        }
        let values = names.map { fields[$0] ?? "" }
        guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              values.prefix(3).allSatisfy({ $0.rangeOfCharacter(from: .controlCharacters) == nil }),
              let expiry = expiration(values[3]), expiry.timeIntervalSince(now) > 30 else { return nil }
        return CloudMediaCredentials(accessKey: values[0], secretKey: values[1], token: values[2], expires: expiry)
    }
    /// 旧端云服务可能返回秒、毫秒或ISO日期，拒绝损坏与非有限数字。
    private func expiration(_ raw: String) -> Date? {
        if let value = Double(raw), value.isFinite, value > 0 {
            let seconds = value > 100_000_000_000 ? value / 1000 : value
            guard seconds <= 253_402_300_799 else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: raw), date.timeIntervalSince1970 <= 253_402_300_799 { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        guard let date = formatter.date(from: raw), date.timeIntervalSince1970 <= 253_402_300_799 else { return nil }
        return date
    }
}
