//
//  AesEncryptUtils.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import CryptoKit
import CommonCrypto

enum AesEncryptUtils {
    static let keyLengthBits = 128

    /// 将 UTF-8 字符串加密并返回 Base64 字符串。
    static func encrypt(_ plainText: String, secret: String) -> String? {
        guard !plainText.isEmpty,
              let cipher = encryptBytes(Data(plainText.utf8), secret: secret) else {
            return nil
        }
        return cipher.base64EncodedString()
    }

    /// 加密原始字节。
    static func encryptBytes(_ plainData: Data, secret: String) -> Data? {
        guard !plainData.isEmpty else { return nil }
        return crypt(plainData, secret: secret, operation: CCOperation(kCCEncrypt))
    }

    /// 解密原始字节。
    static func decryptBytes(_ cipherData: Data, secret: String) -> Data? {
        guard !cipherData.isEmpty else { return nil }
        return crypt(cipherData, secret: secret, operation: CCOperation(kCCDecrypt))
    }

    /// 将 Base64 密文解密为 UTF-8 字符串。
    static func decrypt(_ base64Cipher: String, secret: String) -> String? {
        guard let cipher = Data(base64Encoded: base64Cipher),
              let plainData = decryptBytes(cipher, secret: secret) else {
            return nil
        }
        return String(data: plainData, encoding: .utf8)
    }

    // 与旧项目一致：取 SHA-1(secret) 的前 16 字节作为 AES-128 密钥。
    private static func crypt(_ input: Data, secret: String, operation: CCOperation) -> Data? {
        let key = Array(Insecure.SHA1.hash(data: Data(secret.utf8)).prefix(kCCKeySizeAES128))
        let outputCapacity = input.count + kCCBlockSizeAES128
        var output = [UInt8](repeating: 0, count: outputCapacity)
        var outputCount: size_t = 0

        // AES/ECB/PKCS5Padding 对应 CommonCrypto 的 PKCS7 填充。
        let status = key.withUnsafeBytes { keyBytes in
            input.withUnsafeBytes { inputBytes in
                output.withUnsafeMutableBytes { outputBytes in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                        keyBytes.baseAddress,
                        key.count,
                        nil,
                        inputBytes.baseAddress,
                        input.count,
                        outputBytes.baseAddress,
                        outputCapacity,
                        &outputCount
                    )
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return Data(output.prefix(Int(outputCount)))
    }
}
