//
//  AesEncryptManager.m
//  EncryptLib
//
//  Created by phl on 2025/9/11.
//

#import "AesEncryptManager.h"
#import <CommonCrypto/CommonCryptor.h>
#import <Security/SecRandom.h>

@implementation AesEncryptManager

/// AES解密
/// - Parameter data: 需要aes解密的数据
-(NSData*)aesDecrypt:(NSData*)data {
    @try {
        // 参数验证
        if (!data) {
            NSLog(@"AESDecrypt: 输入数据为空");
            return nil;
        }
        
        // 最小长度检查：3 ("AES") + 1 (version) + 32 (key) + 16 (iv)
        const NSUInteger minLength = 3 + 1 + 32 + 16;
        if (data.length < minLength) {
            NSLog(@"AESDecrypt: 数据长度不足，需要至少 %lu 字节，实际 %lu 字节", (unsigned long)minLength, (unsigned long)data.length);
            return data; // 数据太小，无法解密
        }
        
        NSUInteger offset = 3; // 跳过 "AES"
        
        // 安全地读取版本号
        if (offset + 1 > data.length) {
            NSLog(@"AESDecrypt: 数据长度不足以读取版本号");
            return data;
        }
        
        uint8_t version = 0;
        [data getBytes:&version range:NSMakeRange(offset, 1)];
        offset += 1;
        
        if (version != 2) {
            NSLog(@"AESDecrypt: 不支持的版本号 %d", version);
            return data; // 不支持的版本
        }
        
        // 安全地提取密钥
        if (offset + 32 > data.length) {
            NSLog(@"AESDecrypt: 数据长度不足以读取密钥");
            return data;
        }
        NSData *key = [data subdataWithRange:NSMakeRange(offset, 32)];
        offset += 32;
        
        // 安全地提取IV
        if (offset + 16 > data.length) {
            NSLog(@"AESDecrypt: 数据长度不足以读取IV");
            return data;
        }
        NSData *iv = [data subdataWithRange:NSMakeRange(offset, 16)];
        offset += 16;
        
        // 安全地提取密文
        if (offset >= data.length) {
            NSLog(@"AESDecrypt: 没有密文数据");
            return data;
        }
        NSData *ciphertext = [data subdataWithRange:NSMakeRange(offset, data.length - offset)];
        
        // 验证密文长度
        if (ciphertext.length == 0) {
            NSLog(@"AESDecrypt: 密文长度为0");
            return data;
        }
        
        // 准备输出缓冲区（多加一个 block 大小以防填充）
        size_t dataOutAvailable = ciphertext.length + kCCBlockSizeAES128;
        
        // 检查缓冲区大小是否合理，防止整数溢出
        if (dataOutAvailable < ciphertext.length) {
            NSLog(@"AESDecrypt: 缓冲区大小计算溢出");
            return data;
        }
        
        void *dataOut = malloc(dataOutAvailable);
        if (!dataOut) {
            NSLog(@"AESDecrypt: 内存分配失败");
            return data;
        }
        
        // 清零输出缓冲区
        memset(dataOut, 0, dataOutAvailable);
        
        size_t dataOutMoved = 0;
        CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                         kCCAlgorithmAES,
                                         kCCOptionPKCS7Padding,
                                         key.bytes, key.length,
                                         iv.bytes,
                                         ciphertext.bytes, ciphertext.length,
                                         dataOut, dataOutAvailable,
                                         &dataOutMoved);
        
        if (status != kCCSuccess) {
            NSLog(@"AESDecrypt: CCCrypt 解密失败，状态码: %d", status);
            // 清零敏感数据
            memset_s(dataOut, dataOutAvailable, 0, dataOutAvailable);
            free(dataOut);
            return data; // 解密失败，返回原数据
        }
        
        // 验证解密结果长度
        if (dataOutMoved == 0 || dataOutMoved > dataOutAvailable) {
            NSLog(@"AESDecrypt: 解密结果长度异常: %zu", dataOutMoved);
            memset_s(dataOut, dataOutAvailable, 0, dataOutAvailable);
            free(dataOut);
            return data;
        }
        
        NSData *decrypted = [NSData dataWithBytes:dataOut length:dataOutMoved];
        
        // 清零敏感数据
        memset_s(dataOut, dataOutAvailable, 0, dataOutAvailable);
        free(dataOut);
        
        return decrypted;
        
    } @catch (NSException *exception) {
        NSLog(@"AESDecrypt: 发生异常: %@", exception.reason);
        return data; // 异常情况下返回原数据
    }
}

/// 大文件加密
/// - Parameters:
///   - plainData: 文件数据
///   - error: 错误
- (NSData *)encryptFileToData:(NSData *)plainData {
    @try {
        // 参数验证
        if (!plainData) {
            NSLog(@"encryptFileToData: plainData 为空");
            return nil;
        }
        
        // 生成随机 key(32) 和 iv(16)
        uint8_t keyBytes[32];
        uint8_t ivBytes[16];
        
        // 清零敏感数据缓冲区
        memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
        memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
        
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(keyBytes), keyBytes) != errSecSuccess) {
            NSLog(@"encryptFileToData: 密钥随机数生成失败");
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            return nil;
        }
        
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(ivBytes), ivBytes) != errSecSuccess) {
            NSLog(@"encryptFileToData: IV随机数生成失败");
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }

        // 输出缓冲（明文长度 + 一个 block 大小以备填充）
        size_t cipherBufferSize = plainData.length + kCCBlockSizeAES128;
        
        // 检查缓冲区大小是否合理，防止整数溢出
        if (cipherBufferSize < plainData.length) {
            NSLog(@"encryptFileToData: 缓冲区大小计算溢出");
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        void *cipherBuffer = malloc(cipherBufferSize);
        if (!cipherBuffer) {
            NSLog(@"encryptFileToData: 内存分配失败，需要 %zu 字节", cipherBufferSize);
            // 清理敏感数据
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        // 清零输出缓冲区
        memset(cipherBuffer, 0, cipherBufferSize);

        size_t outLength = 0;
        CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                         kCCAlgorithmAES,
                                         kCCOptionPKCS7Padding,
                                         keyBytes, sizeof(keyBytes),
                                         ivBytes,
                                         plainData.bytes, plainData.length,
                                         cipherBuffer, cipherBufferSize,
                                         &outLength);
        
        if (status != kCCSuccess) {
            NSLog(@"encryptFileToData: CCCrypt 加密失败，状态码: %d", status);
            // 清零敏感数据
            memset_s(cipherBuffer, cipherBufferSize, 0, cipherBufferSize);
            free(cipherBuffer);
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        // 验证加密结果长度
        if (outLength == 0 || outLength > cipherBufferSize) {
            NSLog(@"encryptFileToData: 加密结果长度异常: %zu", outLength);
            memset_s(cipherBuffer, cipherBufferSize, 0, cipherBufferSize);
            free(cipherBuffer);
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }

        // 构造最终结果："AES" + version + key(32) + iv(16) + ciphertext
        NSMutableData *result = [NSMutableData data];
        const char header[] = {'A','E','S'};
        [result appendBytes:header length:3];

        uint8_t version = 2;
        [result appendBytes:&version length:1];

        [result appendBytes:keyBytes length:sizeof(keyBytes)];
        [result appendBytes:ivBytes  length:sizeof(ivBytes)];

        if (outLength > 0) {
            [result appendBytes:cipherBuffer length:outLength];
        }

        // 清理敏感数据
        memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
        memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
        memset_s(cipherBuffer, cipherBufferSize, 0, cipherBufferSize);
        free(cipherBuffer);

        return [result copy];
        
    } @catch (NSException *exception) {
        NSLog(@"encryptFileToData: 发生异常: %@", exception.reason);
        return nil;
    }
}

// AES加密
- (NSData *)AESEncrypt:(NSData*)plainData {
    @try {
        // 参数验证
        if (!plainData) {
            NSLog(@"AESEncrypt: 输入数据为空");
            return nil;
        }
        
        if (plainData.length == 0) {
            NSLog(@"AESEncrypt: 输入数据长度为0");
            return plainData;
        }
        
        // 检查数据长度是否过大，防止内存溢出
        const NSUInteger maxDataSize = 100 * 1024 * 1024; // 100MB 限制
        if (plainData.length > maxDataSize) {
            NSLog(@"AESEncrypt: 数据过大，超过 %lu 字节限制", (unsigned long)maxDataSize);
            return nil;
        }
        
        // 生成 32 字节 key（AES-256）和 16 字节 iv
        uint8_t keyBytes[32];
        uint8_t ivBytes[16];
        
        // 清零敏感数据缓冲区
        memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
        memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
        
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(keyBytes), keyBytes) != errSecSuccess) {
            NSLog(@"AESEncrypt: 密钥随机数生成失败");
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            return nil;
        }
        
        if (SecRandomCopyBytes(kSecRandomDefault, sizeof(ivBytes), ivBytes) != errSecSuccess) {
            NSLog(@"AESEncrypt: IV随机数生成失败");
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        NSData *key = [NSData dataWithBytes:keyBytes length:sizeof(keyBytes)];
        NSData *iv = [NSData dataWithBytes:ivBytes length:sizeof(ivBytes)];
        
        // 输出缓冲（明文长度 + 一个 block 的空间以备填充）
        size_t outAvailable = plainData.length + kCCBlockSizeAES128;
        
        // 检查缓冲区大小是否合理，防止整数溢出
        if (outAvailable < plainData.length) {
            NSLog(@"AESEncrypt: 缓冲区大小计算溢出");
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        void *outBuffer = malloc(outAvailable);
        if (!outBuffer) {
            NSLog(@"AESEncrypt: 内存分配失败，需要 %zu 字节", outAvailable);
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        // 清零输出缓冲区
        memset(outBuffer, 0, outAvailable);
        
        size_t outMoved = 0;
        CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                         kCCAlgorithmAES,
                                         kCCOptionPKCS7Padding,
                                         key.bytes, key.length,
                                         iv.bytes,
                                         plainData.bytes, plainData.length,
                                         outBuffer, outAvailable,
                                         &outMoved);
        
        if (status != kCCSuccess) {
            NSLog(@"AESEncrypt: CCCrypt 加密失败，状态码: %d", status);
            memset_s(outBuffer, outAvailable, 0, outAvailable);
            free(outBuffer);
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil; // 加密失败，返回nil
        }
        
        // 验证加密结果长度
        if (outMoved == 0 || outMoved > outAvailable) {
            NSLog(@"AESEncrypt: 加密结果长度异常: %zu", outMoved);
            memset_s(outBuffer, outAvailable, 0, outAvailable);
            free(outBuffer);
            memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
            memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
            return nil;
        }
        
        NSData *ciphertext = [NSData dataWithBytes:outBuffer length:outMoved];
        
        // 清零敏感数据
        memset_s(outBuffer, outAvailable, 0, outAvailable);
        free(outBuffer);
        
        // 按解密方法所期望的格式拼接： "AES" + version(2) + key(32) + iv(16) + ciphertext
        NSMutableData *result = [NSMutableData data];
        const char header[] = {'A','E','S'};
        [result appendBytes:header length:3];
        
        uint8_t version = 2;
        [result appendBytes:&version length:1];
        
        [result appendData:key];
        [result appendData:iv];
        [result appendData:ciphertext];
        
        // 清理敏感数据
        memset_s(keyBytes, sizeof(keyBytes), 0, sizeof(keyBytes));
        memset_s(ivBytes, sizeof(ivBytes), 0, sizeof(ivBytes));
        
        return [result copy];
        
    } @catch (NSException *exception) {
        NSLog(@"AESEncrypt: 发生异常: %@", exception.reason);
        return nil; // 异常情况下返回nil
    }
}

@end
