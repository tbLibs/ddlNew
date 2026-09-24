//
//  OSSAuthRequestBuilder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CommonCrypto
import CryptoKit
import Foundation
import Security

enum OSSAuthRequestError: Error {
    case emptyAppID
    case missingClientVersion
    case missingRegion
    case missingSigningKey
    case unsupportedAppType
    case randomGenerationFailed
    case encryptionFailed
}

/// 构造旧导航协议的 IM 服务器列表请求；只负责消息和签名，不执行 TCP 收发。
enum OSSAuthRequestBuilder {
    static func make(
        appID: String,
        signingKeyID: String,
        signingKeySecret: String,
        appType: IMServerListRequest.DataType = .common,
        clientVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        region: String = Locale.current.region?.identifier ?? "",
        clientIP: String = "",
        date: Date = Date()
    ) throws -> NavMessage {
        guard !appID.isEmpty else { throw OSSAuthRequestError.emptyAppID }
        guard !clientVersion.isEmpty else { throw OSSAuthRequestError.missingClientVersion }
        guard !region.isEmpty else { throw OSSAuthRequestError.missingRegion }
        guard !signingKeyID.isEmpty, !signingKeySecret.isEmpty else {
            throw OSSAuthRequestError.missingSigningKey
        }
        switch appType {
        case .common, .independent:
            break
        case .UNRECOGNIZED:
            throw OSSAuthRequestError.unsupportedAppType
        }

        let timestamp = Int64(date.timeIntervalSince1970 * 1_000)
        // 与旧项目保持一致：时间戳既用于请求字段，也用于 nonce 和签名原文。
        let nonce = "test_nonce_\(timestamp)"
        let deviceType = "ios"
        let rawSign = "\(appID)\(appType.rawValue)\(clientVersion)\(region)\(deviceType)\(timestamp)\(nonce)"
        let signature = try encryptSignature(
            rawSign,
            signingKeyID: signingKeyID,
            signingKeySecret: signingKeySecret
        )

        var request = IMServerListRequest()
        request.appID = appID
        request.appType = appType
        request.clientVersion = clientVersion
        request.region = region
        request.deviceType = deviceType
        request.timestamp = timestamp
        request.signature = signature
        request.clientIp = clientIP
        request.sdkVersion = "1.0"
        request.nonce = nonce

        var message = NavMessage()
        message.dataType = .imServerListReq
        message.imServerListRequest = request
        return message
    }

    /// 旧协议签名格式：Base64(16 字节随机 IV + AES-256-CBC/PKCS7 密文)。
    private static func encryptSignature(
        _ rawSign: String,
        signingKeyID: String,
        signingKeySecret: String
    ) throws -> String {
        let keySeed = signingKeyID + signingKeySecret
        let key = Array(SHA256.hash(data: Data(keySeed.utf8)))
        var iv = [UInt8](repeating: 0, count: kCCBlockSizeAES128)
        let randomStatus = iv.withUnsafeMutableBytes { bytes -> OSStatus in
            guard let address = bytes.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, bytes.count, address)
        }
        guard randomStatus == errSecSuccess else {
            throw OSSAuthRequestError.randomGenerationFailed
        }

        let plainBytes = Array(rawSign.utf8)
        var cipherBytes = [UInt8](repeating: 0, count: plainBytes.count + kCCBlockSizeAES128)
        let cipherCapacity = cipherBytes.count
        var cipherLength: size_t = 0
        let cryptStatus = key.withUnsafeBytes { keyBuffer in
            iv.withUnsafeBytes { ivBuffer in
                plainBytes.withUnsafeBytes { plainBuffer in
                    cipherBytes.withUnsafeMutableBytes { cipherBuffer in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBuffer.baseAddress,
                            key.count,
                            ivBuffer.baseAddress,
                            plainBuffer.baseAddress,
                            plainBytes.count,
                            cipherBuffer.baseAddress,
                            cipherCapacity,
                            &cipherLength
                        )
                    }
                }
            }
        }
        guard cryptStatus == kCCSuccess else {
            throw OSSAuthRequestError.encryptionFailed
        }

        var signedBytes = Data(iv)
        signedBytes.append(contentsOf: cipherBytes.prefix(cipherLength))
        return signedBytes.base64EncodedString()
    }
}
