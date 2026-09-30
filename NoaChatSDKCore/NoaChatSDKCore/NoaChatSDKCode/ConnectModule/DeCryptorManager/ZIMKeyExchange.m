//
//  ZIMKeyExchange.m
//  ZIM Client
//
//  Created by Connector Handler
//  Copyright © 2024 ZLC. All rights reserved.
//

#import "ZIMKeyExchange.h"
#import <CommonCrypto/CommonCrypto.h>

// 常量定义
static NSString * const kECCurveType = @"secp256r1";
static const NSUInteger kAESKeyLength = 32;  // AES-256密钥长度

#pragma mark - ZIMECDHKeyPair

@interface ZIMECDHKeyPair ()

@property (nonatomic, readwrite) SecKeyRef privateKey;
@property (nonatomic, readwrite) SecKeyRef publicKey;
@property (nonatomic, strong, readwrite) NSData *publicKeyData;

@end

@implementation ZIMECDHKeyPair

+ (nullable instancetype)keyPairWithPrivateKey:(SecKeyRef)privateKey
                                     publicKey:(SecKeyRef)publicKey
                                 publicKeyData:(NSData *)publicKeyData {
    ZIMECDHKeyPair *keyPair = [[ZIMECDHKeyPair alloc] init];
    if (keyPair) {
        keyPair.privateKey = (SecKeyRef)CFRetain(privateKey);
        keyPair.publicKey = (SecKeyRef)CFRetain(publicKey);
        keyPair.publicKeyData = publicKeyData;
    }
    return keyPair;
}

- (void)cleanup {
    if (_privateKey) {
        CFRelease(_privateKey);
        _privateKey = NULL;
    }
    if (_publicKey) {
        CFRelease(_publicKey);
        _publicKey = NULL;
    }
}

- (void)dealloc {
    [self cleanup];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"ZIMECDHKeyPair{publicKeyLength=%lu}",
            (unsigned long)self.publicKeyData.length];
}

@end

#pragma mark - ZIMKeyExchange

@implementation ZIMKeyExchange

#pragma mark - Class Properties

+ (NSString *)curveType {
    return kECCurveType;
}

+ (NSUInteger)aesKeyLength {
    return kAESKeyLength;
}

#pragma mark - ECDH Key Generation

+ (nullable ZIMECDHKeyPair *)generateECDHKeyPair {
    NSLog(@"🔑 开始生成ECDH密钥对（%@曲线）...", kECCurveType);
    
    // 尝试多种密钥生成方法
    ZIMECDHKeyPair *keyPair = [self tryGenerateKeyPairMethod1];
    if (!keyPair) {
        NSLog(@"⚠️ 方法1失败，尝试方法2...");
        keyPair = [self tryGenerateKeyPairMethod2];
    }
    if (!keyPair) {
        NSLog(@"⚠️ 方法2失败，尝试方法3...");
        keyPair = [self tryGenerateKeyPairMethod3];
    }
    
    if (!keyPair) {
        NSLog(@"❌ 所有密钥生成方法都失败了");
        return nil;
    }
    
    NSLog(@"✅ ECDH密钥对生成成功");
    return keyPair;
}

/**
 * 方法1: 使用Secure Enclave（如果支持）
 */
+ (nullable ZIMECDHKeyPair *)tryGenerateKeyPairMethod1 {
    NSDictionary *keyParams = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrTokenID: (id)kSecAttrTokenIDSecureEnclave
    };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyParams, &error);
    
    if (!privateKey || error) {
        NSLog(@"⚠️ 方法1失败（Secure Enclave）: %@", error ? CFBridgingRelease(error) : @"未知错误");
        return nil;
    }
    
    return [self createKeyPairFromPrivateKey:privateKey method:@"Secure Enclave"];
}

/**
 * 方法2: 标准EC密钥生成
 */
+ (nullable ZIMECDHKeyPair *)tryGenerateKeyPairMethod2 {
    NSDictionary *keyParams = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeySizeInBits: @256
    };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyParams, &error);
    
    if (!privateKey || error) {
        NSLog(@"⚠️ 方法2失败（标准EC）: %@", error ? CFBridgingRelease(error) : @"未知错误");
        return nil;
    }
    
    return [self createKeyPairFromPrivateKey:privateKey method:@"标准EC"];
}

/**
 * 方法3: 通用EC类型
 */
+ (nullable ZIMECDHKeyPair *)tryGenerateKeyPairMethod3 {
    NSDictionary *keyParams = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeEC,
        (id)kSecAttrKeySizeInBits: @256
    };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyParams, &error);
    
    if (!privateKey || error) {
        NSLog(@"⚠️ 方法3失败（通用EC）: %@", error ? CFBridgingRelease(error) : @"未知错误");
        return nil;
    }
    
    return [self createKeyPairFromPrivateKey:privateKey method:@"通用EC"];
}

/**
 * 从私钥创建完整的密钥对
 */
+ (nullable ZIMECDHKeyPair *)createKeyPairFromPrivateKey:(SecKeyRef)privateKey method:(NSString *)methodName {
    // 获取公钥
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        NSLog(@"❌ 无法从私钥获取公钥（%@）", methodName);
        CFRelease(privateKey);
        return nil;
    }
    
    // 导出公钥数据
    CFErrorRef exportError = NULL;
    CFDataRef publicKeyDataRef = SecKeyCopyExternalRepresentation(publicKey, &exportError);
    
    if (!publicKeyDataRef || exportError) {
        NSLog(@"❌ 公钥数据导出失败（%@）: %@", methodName, exportError ? CFBridgingRelease(exportError) : @"未知错误");
        CFRelease(privateKey);
        CFRelease(publicKey);
        return nil;
    }
    
    NSData *publicKeyData = CFBridgingRelease(publicKeyDataRef);
    
    // 验证公钥数据格式
    if (![self validatePublicKeyData:publicKeyData]) {
        NSLog(@"❌ 生成的公钥数据格式无效（%@）", methodName);
        CFRelease(privateKey);
        CFRelease(publicKey);
        return nil;
    }
    
    NSLog(@"✅ 密钥对生成成功（%@）: 公钥长度=%lu字节", methodName, (unsigned long)publicKeyData.length);
    NSLog(@"🔍 公钥数据预览: %@", [self dataToHexString:[publicKeyData subdataWithRange:NSMakeRange(0, MIN(16, publicKeyData.length))]]);
    
    ZIMECDHKeyPair *keyPair = [ZIMECDHKeyPair keyPairWithPrivateKey:privateKey
                                                          publicKey:publicKey
                                                      publicKeyData:publicKeyData];
    
    // 释放本地引用（keyPair内部已经retain）
    CFRelease(privateKey);
    CFRelease(publicKey);
    
    return keyPair;
}

/**
 * 验证公钥数据格式
 */
+ (BOOL)validatePublicKeyData:(NSData *)publicKeyData {
    if (!publicKeyData || publicKeyData.length == 0) {
        return NO;
    }
    
    const uint8_t *bytes = (const uint8_t *)publicKeyData.bytes;
    NSUInteger length = publicKeyData.length;
    
    // 检查常见的有效格式
    if (length == 65 && bytes[0] == 0x04) {
        NSLog(@"🔍 检测到有效的未压缩EC公钥格式");
        return YES;
    }
    
    if (length == 33 && (bytes[0] == 0x02 || bytes[0] == 0x03)) {
        NSLog(@"🔍 检测到压缩EC公钥格式");
        return YES;
    }
    
    if (length == 64) {
        NSLog(@"🔍 检测到原始坐标格式");
        return YES;
    }
    
    if (length > 65 && bytes[0] == 0x30) {
        NSLog(@"🔍 检测到DER编码格式");
        return YES;
    }
    
    NSLog(@"⚠️ 未知的公钥格式: 长度=%lu, 首字节=0x%02x", (unsigned long)length, bytes[0]);
    return YES; // 允许未知格式，让后续处理决定
}

+ (nullable SecKeyRef)reconstructPublicKeyFromData:(NSData *)publicKeyData {
    if (!publicKeyData || publicKeyData.length == 0) {
        NSLog(@"❌ 公钥数据无效");
        return nil;
    }
    
    NSLog(@"🔍 重构公钥，原始数据长度: %lu字节", (unsigned long)publicKeyData.length);
    NSLog(@"🔍 原始数据预览: %@", [self dataToHexString:[publicKeyData subdataWithRange:NSMakeRange(0, MIN(16, publicKeyData.length))]]);
    
    // 处理不同格式的公钥数据
    NSData *processedKeyData = [self processPublicKeyData:publicKeyData];
    if (!processedKeyData) {
        NSLog(@"❌ 公钥数据预处理失败");
        return nil;
    }
    
    NSLog(@"🔍 处理后数据长度: %lu字节", (unsigned long)processedKeyData.length);
    
    // 尝试多种导入方式
    SecKeyRef publicKey = [self tryCreatePublicKeyWithData:processedKeyData];
    if (!publicKey) {
        // 如果失败，尝试原始数据
        NSLog(@"⚠️ 使用处理后数据失败，尝试原始数据...");
        publicKey = [self tryCreatePublicKeyWithData:publicKeyData];
    }
    
    if (!publicKey) {
        NSLog(@"❌ 所有公钥重构方法都失败了");
        return nil;
    }
    
    NSLog(@"✅ 公钥重构成功");
    return publicKey;
}

/**
 * 预处理公钥数据，转换为iOS兼容的格式
 */
+ (nullable NSData *)processPublicKeyData:(NSData *)rawKeyData {
    if (!rawKeyData) return nil;
    
    const uint8_t *bytes = (const uint8_t *)rawKeyData.bytes;
    NSUInteger length = rawKeyData.length;
    
    // 检查是否是未压缩格式 (0x04开头，65字节)
    if (length == 65 && bytes[0] == 0x04) {
        NSLog(@"🔍 检测到未压缩EC公钥格式 (65字节)");
        return rawKeyData; // 已经是正确格式
    }
    
    // 检查是否是压缩格式 (0x02或0x03开头，33字节)
    if (length == 33 && (bytes[0] == 0x02 || bytes[0] == 0x03)) {
        NSLog(@"🔍 检测到压缩EC公钥格式 (33字节)");
        // iOS不直接支持压缩格式，需要解压缩
        return [self decompressPublicKey:rawKeyData];
    }
    
    // 检查是否是DER编码格式
    if (length > 65 && bytes[0] == 0x30) {
        NSLog(@"🔍 检测到DER编码公钥格式");
        return [self extractRawKeyFromDER:rawKeyData];
    }
    
    // 检查是否是原始坐标格式 (64字节，无前缀)
    if (length == 64) {
        NSLog(@"🔍 检测到原始坐标格式 (64字节)，添加0x04前缀");
        NSMutableData *uncompressedKey = [NSMutableData dataWithCapacity:65];
        uint8_t prefix = 0x04;
        [uncompressedKey appendBytes:&prefix length:1];
        [uncompressedKey appendData:rawKeyData];
        return uncompressedKey;
    }
    
    NSLog(@"⚠️ 未知的公钥数据格式，长度: %lu", (unsigned long)length);
    return rawKeyData; // 返回原始数据，让调用者尝试
}

/**
 * 尝试创建公钥的多种方法
 */
+ (nullable SecKeyRef)tryCreatePublicKeyWithData:(NSData *)keyData {
    // 方法1: 标准EC公钥导入
    NSDictionary *keyParams1 = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic
    };
    
    CFErrorRef error1 = NULL;
    SecKeyRef publicKey = SecKeyCreateWithData((__bridge CFDataRef)keyData,
                                             (__bridge CFDictionaryRef)keyParams1,
                                             &error1);
    
    if (publicKey && !error1) {
        NSLog(@"✅ 方法1成功: 标准EC公钥导入");
        return publicKey;
    }
    
    NSLog(@"⚠️ 方法1失败: %@", error1 ? CFBridgingRelease(error1) : @"未知错误");
    
    // 方法2: 不指定密钥大小
    NSDictionary *keyParams2 = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic
    };
    
    CFErrorRef error2 = NULL;
    publicKey = SecKeyCreateWithData((__bridge CFDataRef)keyData,
                                   (__bridge CFDictionaryRef)keyParams2,
                                   &error2);
    
    if (publicKey && !error2) {
        NSLog(@"✅ 方法2成功: 不指定密钥大小");
        return publicKey;
    }
    
    NSLog(@"⚠️ 方法2失败: %@", error2 ? CFBridgingRelease(error2) : @"未知错误");
    
    // 方法3: 使用EC通用类型
    NSDictionary *keyParams3 = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeEC,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic
    };
    
    CFErrorRef error3 = NULL;
    publicKey = SecKeyCreateWithData((__bridge CFDataRef)keyData,
                                   (__bridge CFDictionaryRef)keyParams3,
                                   &error3);
    
    if (publicKey && !error3) {
        NSLog(@"✅ 方法3成功: EC通用类型");
        return publicKey;
    }
    
    NSLog(@"⚠️ 方法3失败: %@", error3 ? CFBridgingRelease(error3) : @"未知错误");
    
    return nil;
}

/**
 * 从DER编码中提取原始公钥数据
 */
+ (nullable NSData *)extractRawKeyFromDER:(NSData *)derData {
    // 这是一个简化的DER解析，实际应用中可能需要更完整的ASN.1解析
    const uint8_t *bytes = (const uint8_t *)derData.bytes;
    NSUInteger length = derData.length;
    
    // 寻找公钥数据部分 (通常是最后的65字节，以0x04开头)
    for (NSUInteger i = 0; i < length - 64; i++) {
        if (bytes[i] == 0x04 && (length - i) >= 65) {
            NSLog(@"🔍 在DER数据中找到未压缩公钥，偏移: %lu", (unsigned long)i);
            return [derData subdataWithRange:NSMakeRange(i, 65)];
        }
    }
    
    NSLog(@"⚠️ 无法从DER数据中提取公钥");
    return nil;
}

/**
 * 解压缩EC公钥 (简化实现)
 */
+ (nullable NSData *)decompressPublicKey:(NSData *)compressedKey {
    NSLog(@"⚠️ 压缩公钥解压缩功能尚未实现");
    // 这需要椭圆曲线数学运算来从压缩格式恢复完整坐标
    // 暂时返回nil，建议服务端发送未压缩格式的公钥
    return nil;
}

#pragma mark - Shared Secret Computation

+ (nullable NSData *)computeSharedSecret:(SecKeyRef)privateKey
                      remotePublicKeyData:(NSData *)remotePublicKeyData {
    if (!privateKey || !remotePublicKeyData) {
        NSLog(@"❌ 共享密钥计算参数无效");
        return nil;
    }
    
    NSLog(@"🔐 开始计算ECDH共享密钥...");
    NSLog(@"🔍 远程公钥长度: %lu字节", (unsigned long)remotePublicKeyData.length);
    
    // 重构远程公钥
    SecKeyRef remotePublicKey = [self reconstructPublicKeyFromData:remotePublicKeyData];
    if (!remotePublicKey) {
        NSLog(@"❌ 远程公钥重构失败");
        return nil;
    }
    
    // 计算共享密钥
    CFErrorRef error = NULL;
    CFDataRef sharedSecretRef = SecKeyCopyKeyExchangeResult(privateKey,
                                                           kSecKeyAlgorithmECDHKeyExchangeStandard,
                                                           remotePublicKey,
                                                           (__bridge CFDictionaryRef)@{},
                                                           &error);
    
    CFRelease(remotePublicKey); // 释放临时公钥
    
    if (!sharedSecretRef || error) {
        NSLog(@"❌ ECDH共享密钥计算失败: %@", error ? CFBridgingRelease(error) : @"未知错误");
        return nil;
    }
    
    NSData *sharedSecret = CFBridgingRelease(sharedSecretRef);
    
    NSLog(@"✅ ECDH共享密钥计算成功: 长度=%lu字节", (unsigned long)sharedSecret.length);
    NSLog(@"🔍 共享密钥前16字节: %@", [self dataToHexString:[sharedSecret subdataWithRange:NSMakeRange(0, MIN(16, sharedSecret.length))]]);
    
    return sharedSecret;
}

#pragma mark - AES Key Derivation

+ (nullable NSData *)deriveAESKeyFromSharedSecret:(NSData *)sharedSecret {
    if (!sharedSecret || sharedSecret.length == 0) {
        NSLog(@"❌ 共享密钥无效，无法派生AES密钥");
        return nil;
    }
    
    NSLog(@"🔐 开始AES密钥派生，共享密钥长度: %lu字节", (unsigned long)sharedSecret.length);
    NSLog(@"🔍 共享密钥前16字节: %@", [self dataToHexString:[sharedSecret subdataWithRange:NSMakeRange(0, MIN(16, sharedSecret.length))]]);
    NSLog(@"📋 派生算法: 直接SHA-256（与服务端保持一致）");
    
    // 使用SHA-256对共享密钥进行哈希（与服务端完全一致的算法）
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(sharedSecret.bytes, (CC_LONG)sharedSecret.length, hash);
    
    // 取前32字节作为AES-256密钥
    NSData *aesKey = [NSData dataWithBytes:hash length:kAESKeyLength];
    
    NSLog(@"✅ AES密钥派生完成: 长度=%lu字节", (unsigned long)aesKey.length);
    NSLog(@"🔍 派生AES密钥前16字节: %@", [self dataToHexString:[aesKey subdataWithRange:NSMakeRange(0, MIN(16, aesKey.length))]]);
    
    // 清理哈希缓冲区
    memset(hash, 0, sizeof(hash));
    
    return aesKey;
}

#pragma mark - Complete Key Exchange

+ (nullable NSData *)performKeyExchange:(NSData *)serverPublicKeyData
                         clientKeyPair:(SecKeyRef)key {
    if (!serverPublicKeyData || !key) {
        NSLog(@"❌ 密钥交换参数无效");
        return nil;
    }
    
    NSLog(@"🤝 开始执行完整的ECDH密钥交换流程...");
    
    // 1. 计算共享密钥
    NSData *sharedSecret = [self computeSharedSecret:key
                                  remotePublicKeyData:serverPublicKeyData];
    if (!sharedSecret) {
        NSLog(@"❌ 共享密钥计算失败");
        return nil;
    }
    
    // 2. 派生AES密钥
    NSData *aesKey = [self deriveAESKeyFromSharedSecret:sharedSecret];
    if (!aesKey) {
        NSLog(@"❌ AES密钥派生失败");
        return nil;
    }
    
    NSLog(@"✅ ECDH密钥交换完成，AES密钥已生成");
    
    return aesKey;
}

#pragma mark - Validation

+ (BOOL)isValidPublicKeyData:(NSData *)publicKeyData {
    if (!publicKeyData || publicKeyData.length == 0) {
        return NO;
    }
    
    // 尝试重构公钥来验证有效性
    SecKeyRef publicKey = [self reconstructPublicKeyFromData:publicKeyData];
    if (publicKey) {
        CFRelease(publicKey);
        return YES;
    }
    
    return NO;
}

#pragma mark - Utility

+ (NSString *)dataToHexString:(NSData *)data {
    if (!data || data.length == 0) {
        return @"";
    }
    
    NSMutableString *hexString = [NSMutableString stringWithCapacity:data.length * 2];
    const unsigned char *bytes = (const unsigned char *)data.bytes;
    
    for (NSUInteger i = 0; i < data.length; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }
    
    return [hexString copy];
}

@end
