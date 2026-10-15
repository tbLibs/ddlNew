// Created by taobo on 2026/10/13.
import Foundation
import CommonCrypto

/// 兼容旧端文件包装格式；这是媒体格式兼容层，业务请求加密仍使用 SDK。
nonisolated enum LegacyChatMediaCodec {
    private static let imageVideoExtensions: Set<String> = ["jpeg", "png", "gif", "jpg", "jpe", "mp4", "mov", "avi", "flv", "rm", "rmvb", "mkv", "wmv"]

    /// 沿用旧端默认 XOR，包装照片视频、群头像及对应文件，不改变语音和一般附件。
    static func prepareUpload(file: URL, type: Int) throws -> URL {
        guard type == 1 || type == 2 || type == 101 || type == 102 || (type == 5 && imageVideoExtensions.contains(file.pathExtension.lowercased())) else { return file }
        let reader = try FileHandle(forReadingFrom: file)
        defer { try? reader.close() }
        let size = try reader.seekToEnd()
        // 尾部256字节作为包装键，必须与前128字节不重叠，较短文件保持原格式。
        guard size >= 384 else { return file }
        try reader.seek(toOffset: 0)
        let head = try reader.read(upToCount: 128) ?? Data()
        if head.prefix(3) == Data("XOR".utf8) || head.prefix(3) == Data("AES".utf8) { return file }
        try reader.seek(toOffset: size - 256)
        let key = try reader.read(upToCount: 256) ?? Data()
        guard head.count == 128, key.count == 256 else { throw CocoaError(.fileReadCorruptFile) }
        let output = temporary(extension: file.pathExtension)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        do {
            let writer = try FileHandle(forWritingTo: output)
            defer { try? writer.close() }
            try writer.write(contentsOf: Data("XOR".utf8))
            try writer.write(contentsOf: xor(head, key: key))
            try reader.seek(toOffset: 128)
            try copy(reader, to: writer)
            return output
        } catch { try? FileManager.default.removeItem(at: output); throw error }
    }

    /// 图片处理器使用同一包装解析，普通二进制直接返回。
    static func decode(_ data: Data) throws -> Data {
        guard data.prefix(3) == Data("XOR".utf8) || data.prefix(3) == Data("AES".utf8) else { return data }
        let source = temporary(extension: "bin")
        try data.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let decoded = try decodeFile(source)
        defer { if decoded != source { try? FileManager.default.removeItem(at: decoded) } }
        return try Data(contentsOf: decoded)
    }

    /// 大文件以一 MiB 流式解包，下载成功后才交给播放或系统分享。
    static func decodeFile(_ file: URL) throws -> URL {
        let reader = try FileHandle(forReadingFrom: file)
        defer { try? reader.close() }
        let header = try reader.read(upToCount: 3) ?? Data()
        guard header == Data("XOR".utf8) || header == Data("AES".utf8) else { return file }
        let size = try reader.seekToEnd()
        let output = temporary(extension: file.pathExtension)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        do {
            let writer = try FileHandle(forWritingTo: output)
            defer { try? writer.close() }
            if header == Data("XOR".utf8) {
                guard size >= 387 else { throw CocoaError(.fileReadCorruptFile) }
                try reader.seek(toOffset: size - 256)
                let key = try reader.read(upToCount: 256) ?? Data()
                try reader.seek(toOffset: 3)
                let first = try reader.read(upToCount: 128) ?? Data()
                guard first.count == 128, key.count == 256 else { throw CocoaError(.fileReadCorruptFile) }
                try writer.write(contentsOf: xor(first, key: key))
                try copy(reader, to: writer)
            } else {
                try reader.seek(toOffset: 3)
                try decodeAES(reader, to: writer)
            }
            return output
        } catch { try? FileManager.default.removeItem(at: output); throw error }
    }

    /// XOR 格式仅变换前128字节，键来自文件尾部原样数据。
    private static func xor(_ data: Data, key: Data) -> Data {
        Data(zip(data, key).map { $0 ^ $1 })
    }

    /// 识别旧 AES v2 的32字节键、16字节IV及PKCS7密文，错误包装不得伪装正常媒体。
    private static func decodeAES(_ reader: FileHandle, to writer: FileHandle) throws {
        guard let parameters = try reader.read(upToCount: 49), parameters.count == 49, parameters[0] == 2 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let key = parameters.subdata(in: 1..<33), iv = parameters.subdata(in: 33..<49)
        let position = try reader.offset()
        let end = try reader.seekToEnd()
        guard end > position, (end - position) % UInt64(kCCBlockSizeAES128) == 0 else { throw CocoaError(.fileReadCorruptFile) }
        try reader.seek(toOffset: position)
        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBytes { keyBytes in iv.withUnsafeBytes { ivBytes in
            CCCryptorCreate(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), 0,
                            keyBytes.baseAddress, key.count, ivBytes.baseAddress, &cryptor)
        } }
        guard status == kCCSuccess, let cryptor else { throw CocoaError(.fileReadCorruptFile) }
        defer { CCCryptorRelease(cryptor) }
        var tail = Data()
        while let bytes = try reader.read(upToCount: 1024 * 1024), !bytes.isEmpty {
            try Task<Never, Never>.checkCancellation()
            var result = Data(count: CCCryptorGetOutputLength(cryptor, bytes.count, false))
            let capacity = result.count
            var moved = 0
            let update = bytes.withUnsafeBytes { input in result.withUnsafeMutableBytes { output in
                CCCryptorUpdate(cryptor, input.baseAddress, bytes.count, output.baseAddress, capacity, &moved)
            } }
            guard update == kCCSuccess else { throw CocoaError(.fileReadCorruptFile) }
            result.count = moved
            tail.append(result)
            if tail.count > kCCBlockSizeAES128 {
                try writer.write(contentsOf: tail.dropLast(kCCBlockSizeAES128))
                tail = Data(tail.suffix(kCCBlockSizeAES128))
            }
        }
        var final = Data(count: kCCBlockSizeAES128), moved = 0
        let completion = final.withUnsafeMutableBytes { CCCryptorFinal(cryptor, $0.baseAddress, kCCBlockSizeAES128, &moved) }
        guard completion == kCCSuccess else { throw CocoaError(.fileReadCorruptFile) }
        final.count = moved; tail.append(final)
        // 显式核验PKCS7，部分系统实现的流式Final不会拒绝所有损坏/截断输入。
        guard let padding = tail.last, padding > 0, padding <= kCCBlockSizeAES128,
              tail.count >= Int(padding), tail.suffix(Int(padding)).allSatisfy({ $0 == padding }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try writer.write(contentsOf: tail.dropLast(Int(padding)))
    }

    /// 临时文件保留原扩展，调用方负责在发送或解码消费完成后删除。
    private static func temporary(extension suffix: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
    }

    /// 复制剩余媒体数据，每块检查取消并保证异常时关闭文件。
    private static func copy(_ reader: FileHandle, to writer: FileHandle) throws {
        while let bytes = try reader.read(upToCount: 1024 * 1024), !bytes.isEmpty {
            try Task<Never, Never>.checkCancellation(); try writer.write(contentsOf: bytes)
        }
    }
}
