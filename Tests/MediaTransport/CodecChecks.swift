import Foundation
@main private struct CodecChecks {
    /// 与旧XOR格式验证已知头部及逐字节往返，流式文件不能破坏正文。
    static func main() throws {
        let bytes = Data((0..<1024).map { UInt8($0 % 256) })
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try bytes.write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }
        let encoded = try LegacyChatMediaCodec.prepareUpload(file: temp, type: 1)
        defer { if encoded != temp { try? FileManager.default.removeItem(at: encoded) } }
        let content = try Data(contentsOf: encoded)
        precondition(content.prefix(3) == Data("XOR".utf8))
        precondition(content.dropFirst(3).prefix(128) == Data(repeating: 0, count: 128))
        let roundtrip = try LegacyChatMediaCodec.decode(content)
        precondition(roundtrip == bytes)
        let decoded = try LegacyChatMediaCodec.decodeFile(encoded)
        defer { if decoded != encoded { try? FileManager.default.removeItem(at: decoded) } }
        let fileBytes = try Data(contentsOf: decoded)
        precondition(fileBytes == bytes)
        let voice = try LegacyChatMediaCodec.prepareUpload(file: temp, type: 4)
        precondition(voice == temp, "语音沿旧端保持原格式")
        let evidence = try LegacyChatMediaCodec.prepareUpload(file: temp, type: 102)
        defer { if evidence != temp { try? FileManager.default.removeItem(at: evidence) } }
        let evidenceData = try Data(contentsOf: evidence)
        precondition(evidenceData.prefix(3) == Data("XOR".utf8), "投诉通用证据图沿旧端isEncrypt:YES包装")
        let avatar = try LegacyChatMediaCodec.prepareUpload(file: temp, type: 101)
        defer { if avatar != temp { try? FileManager.default.removeItem(at: avatar) } }
        let avatarBytes = try Data(contentsOf: avatar)
        precondition(avatarBytes.prefix(3) == Data("XOR".utf8), "群头像沿旧端isEncrypt:YES包装")
        let plain = try LegacyChatMediaCodec.decode(Data("plain".utf8))
        precondition(plain == Data("plain".utf8))
        print("Legacy media codec checks passed")
    }
}
