//
//  ECDHKeyManager.m
//  IM Client ECDH Implementation
//
//  对应服务端 EccKeyManager.java 的客户端实现
//  使用 P-256 (secp256r1) 椭圆曲线，与Java服务端完全兼容
//  Created by IM Team
//

#import "ECDHKeyManager.h"
#import <CommonCrypto/CommonCrypto.h>
// 宏定义
#import "LingIMMacorHeader.h"

// 错误域定义
static NSString * const ECDHKeyManagerErrorDomain = @"ECDHKeyManagerError";

// 椭圆曲线参数 - 与服务端保持一致
static NSString * const kECDHAlgorithm = @"ECDH";
static NSString * const kCurveName = @"secp256r1";  // 对应服务端的 CURVE_NAME
static NSInteger const kKeySize = 256;              // P-256 = 256位

@implementation ECDHKeyManager

#pragma mark - 密钥对生成

/**
 * 生成ECDH密钥对 - 异步版本
 * 对应服务端的 generateKeyPair() 方法
 */
+ (void)generateKeyPairWithCompletion:(void(^)(SecKeyRef _Nullable publicKey, 
                                              SecKeyRef _Nullable privateKey, 
                                              NSError * _Nullable error))completion {
    
    CIMLog(@"🚀 开始生成ECDH密钥对 (secp256r1)...");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSDictionary *keyPair = [self generateKeyPairSyncWithError:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !keyPair) {
                CIMLog(@"❌ ECDH密钥对生成失败: %@", error.localizedDescription);
                completion(NULL, NULL, error);
            } else {
                SecKeyRef publicKey = (__bridge SecKeyRef)keyPair[@"publicKey"];
                SecKeyRef privateKey = (__bridge SecKeyRef)keyPair[@"privateKey"];
                CIMLog(@"✅ ECDH密钥对生成成功");
                completion(publicKey, privateKey, nil);
            }
        });
    });
}

/**
 * 同步生成ECDH密钥对
 */
+ (NSDictionary * _Nullable)generateKeyPairSyncWithError:(NSError **)error {
    
    // secp256r1 (P-256) 椭圆曲线参数配置
    NSDictionary *keyAttributes = @{
        // 椭圆曲线类型 - 对应服务端的 ECDH + secp256r1
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        
        // P-256 = 256位密钥长度
        (id)kSecAttrKeySizeInBits: @(kKeySize),
        
        // 私钥类别
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPrivate,
        
        // 私钥属性
        (id)kSecPrivateKeyAttrs: @{
            (id)kSecAttrIsPermanent: @NO,  // 临时密钥，不存储到钥匙串
            (id)kSecAttrApplicationTag: [@"ECDHPrivateKey" dataUsingEncoding:NSUTF8StringEncoding],
            (id)kSecAttrLabel: @"ECDH Private Key (secp256r1)"
        },
        
        // 公钥属性
        (id)kSecPublicKeyAttrs: @{
            (id)kSecAttrIsPermanent: @NO,   // 临时密钥，不存储到钥匙串
            (id)kSecAttrApplicationTag: [@"ECDHPublicKey" dataUsingEncoding:NSUTF8StringEncoding],
            (id)kSecAttrLabel: @"ECDH Public Key (secp256r1)"
        }
    };
    
    // 生成密钥对
    CFErrorRef cfError = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)keyAttributes, &cfError);
    
    if (cfError != NULL) {
        if (error) {
            *error = (__bridge_transfer NSError *)cfError;
        }
        CIMLog(@"❌ ECDH私钥生成失败: %@", ((__bridge NSError *)cfError).localizedDescription);
        return nil;
    }
    
    // 获取对应的公钥
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (publicKey == NULL) {
        CFRelease(privateKey);
        if (error) {
            *error = [NSError errorWithDomain:ECDHKeyManagerErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"无法从私钥获取公钥"}];
        }
        CIMLog(@"❌ ECDH公钥获取失败");
        return nil;
    }
    
    CIMLog(@"✅ ECDH密钥对生成成功 (secp256r1)");
    [self printKeyInfo:privateKey label:@"生成的私钥"];
    [self printKeyInfo:publicKey label:@"生成的公钥"];
    
    // 返回密钥对字典
    return @{
        @"publicKey": (__bridge id)publicKey,
        @"privateKey": (__bridge id)privateKey
    };
}

#pragma mark - 公钥处理

/**
 * 从字节数组重构公钥
 * 对应服务端的 reconstructPublicKey(byte[] publicKeyBytes) 方法
 * 支持 X.509 DER 格式和原始格式
 */
+ (SecKeyRef _Nullable)reconstructPublicKeyFromBytes:(NSData *)publicKeyBytes error:(NSError **)error {
    CIMLog(@"🔄 从字节数组重构公钥，长度: %lu字节", (unsigned long)publicKeyBytes.length);
    
    if (!publicKeyBytes || publicKeyBytes.length == 0) {
        CIMLog(@"公钥字节数组为空");
        return NULL;
    }
    
    NSData *keyDataToUse = publicKeyBytes;
    
    // 判断是否为 X.509 DER 格式（以 0x30 开头）还是原始格式（65字节）
    const uint8_t *bytes = (const uint8_t *)publicKeyBytes.bytes;
    if (publicKeyBytes.length > 65 && bytes[0] == 0x30) {
        // X.509 DER 格式，直接使用
        CIMLog(@"📋 检测到X.509 DER格式公钥");
        keyDataToUse = publicKeyBytes;
    } else if (publicKeyBytes.length == 65) {
        // 原始格式，需要转换为 X.509 DER
        CIMLog(@"📋 检测到原始格式公钥，转换为X.509 DER");
        keyDataToUse = [self convertRawPublicKeyToX509DER:publicKeyBytes];
        if (!keyDataToUse) {
            if (error) {
                *error = [NSError errorWithDomain:ECDHKeyManagerErrorDomain
                                             code:-11
                                         userInfo:@{NSLocalizedDescriptionKey: @"原始公钥转换为X.509 DER失败"}];
            }
            CIMLog(@"❌ 原始公钥转换为X.509 DER失败");
            return NULL;
        }
    } else {
        CIMLog(@"⚠️ 未知的公钥格式，长度: %lu字节，尝试直接解析", (unsigned long)publicKeyBytes.length);
    }
    
    // 尝试不同的方法创建公钥
    SecKeyRef publicKey = NULL;
    CFErrorRef cfError = NULL;
    
    // 方法1: 尝试直接使用 X.509 DER 格式
    NSDictionary *keyAttributes = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
    };
    
    publicKey = SecKeyCreateWithData((__bridge CFDataRef)keyDataToUse,
                                   (__bridge CFDictionaryRef)keyAttributes,
                                   &cfError);
    
    // 如果方法1失败，尝试方法2: 从 X.509 DER 提取原始公钥数据
    if (cfError != NULL) {
        CFRelease(cfError);
        cfError = NULL;
        
        CIMLog(@"⚠️ 直接解析X.509 DER失败，尝试提取原始公钥数据...");
        
        // 从 X.509 DER 中提取原始公钥数据
        NSData *rawPublicKeyData = [self extractRawPublicKeyFromX509DER:keyDataToUse];
        if (rawPublicKeyData) {
            CIMLog(@"📋 提取到原始公钥数据，长度: %lu字节", (unsigned long)rawPublicKeyData.length);
            
            publicKey = SecKeyCreateWithData((__bridge CFDataRef)rawPublicKeyData,
                                           (__bridge CFDictionaryRef)keyAttributes,
                                           &cfError);
        }
    }
    
    if (cfError != NULL) {
        if (error) {
            *error = (__bridge_transfer NSError *)cfError;
        }
        CIMLog(@"❌ 公钥重构失败: %@", ((__bridge NSError *)cfError).localizedDescription);
        CIMLog(@"   - 输入数据长度: %lu字节", (unsigned long)publicKeyBytes.length);
        CIMLog(@"   - 使用数据长度: %lu字节", (unsigned long)keyDataToUse.length);
        CIMLog(@"   - 数据hex: %@", [self hexStringFromData:keyDataToUse]);
        CIMLog(@"   - 错误码: %ld", (long)CFErrorGetCode(cfError));
        return NULL;
    }
    
    // 验证重构的公钥是否为secp256r1
    if (![self isSecp256r1Key:publicKey]) {
        CFRelease(publicKey);
        if (error) {
            *error = [NSError errorWithDomain:ECDHKeyManagerErrorDomain
                                         code:-3
                                     userInfo:@{NSLocalizedDescriptionKey: @"重构的公钥不是secp256r1类型"}];
        }
        CIMLog(@"❌ 重构的公钥类型验证失败");
        return NULL;
    }
    
    CIMLog(@"✅ 公钥重构成功");
    return publicKey;
}

/**
 * 获取公钥的X.509 DER编码字节数组
 * 用于与服务端交换公钥（对应Java的公钥编码格式）
 */
+ (NSData * _Nullable)getPublicKeyBytes:(SecKeyRef)publicKey error:(NSError **)error {
    // 使用 SecKeyCopyExternalRepresentation 获取原始公钥数据
    CFErrorRef cfError = NULL;
    CFDataRef rawKeyData = SecKeyCopyExternalRepresentation(publicKey, &cfError);
    
    if (cfError != NULL) {
        if (error) {
            *error = (__bridge_transfer NSError *)cfError;
        }
        CIMLog(@"❌ 获取公钥原始数据失败: %@", ((__bridge NSError *)cfError).localizedDescription);
        return nil;
    }
    
    NSData *rawData = (__bridge_transfer NSData *)rawKeyData;
    CIMLog(@"📋 原始公钥数据长度: %lu字节", (unsigned long)rawData.length);
    
    // 将原始公钥数据转换为X.509 DER格式
    NSData *x509Data = [self convertRawPublicKeyToX509DER:rawData];
    
    if (!x509Data) {
        if (error) {
            *error = [NSError errorWithDomain:ECDHKeyManagerErrorDomain
                                         code:-10
                                     userInfo:@{NSLocalizedDescriptionKey: @"转换为X.509 DER格式失败"}];
        }
        CIMLog(@"❌ 转换为X.509 DER格式失败");
        return nil;
    }
    
    CIMLog(@"✅ X.509 DER公钥数据生成成功: %lu字节", (unsigned long)x509Data.length);
    return x509Data;
}

/**
 * 获取私钥的X.509 DER编码字节数组
 * 用于与服务端公钥共享（对应Java的私钥编码格式）
 */
+ (NSData * _Nullable)getPrivateKeyBytes:(SecKeyRef)privateKey error:(NSError **)error {
    // 使用 SecKeyCopyExternalRepresentation 获取原始私钥数据
    CFErrorRef cfError = NULL;
    CFDataRef rawKeyData = SecKeyCopyExternalRepresentation(privateKey, &cfError);
    
    if (cfError != NULL) {
        if (error) {
            *error = (__bridge_transfer NSError *)cfError;
        }
        CIMLog(@"❌ 获取私钥原始数据失败: %@", ((__bridge NSError *)cfError).localizedDescription);
        return nil;
    }
    
    NSData *rawData = (__bridge_transfer NSData *)rawKeyData;
    CIMLog(@"📋 原始私钥数据长度: %lu字节", (unsigned long)rawData.length);
    
    // 将原始私钥数据转换为X.509 DER格式
    NSData *x509Data = [self convertRawPrivateKeyToX509DER:rawData];
    
    if (!x509Data) {
        if (error) {
            *error = [NSError errorWithDomain:ECDHKeyManagerErrorDomain
                                         code:-10
                                     userInfo:@{NSLocalizedDescriptionKey: @"转换为X.509 DER格式失败"}];
        }
        CIMLog(@"❌ 转换为X.509 DER格式失败");
        return nil;
    }
    
    CIMLog(@"✅ X.509 DER私钥数据生成成功: %lu字节", (unsigned long)x509Data.length);
    return x509Data;
}

+ (NSData * _Nullable)convertRawPrivateKeyToX509DER:(NSData *)rawPrivateKey {
    if (!rawPrivateKey || rawPrivateKey.length != 32) {
        CIMLog(@"❌ 原始私钥数据无效，期望32字节，实际%lu字节", (unsigned long)rawPrivateKey.length);
        return nil;
    }
    
    // P-256 私钥的 X.509 DER 编码结构：
    // SEQUENCE {
    //   OBJECT IDENTIFIER 1.2.840.10045.2.1 (ecPrivateKey)
    //   SEQUENCE {
    //     OBJECT IDENTIFIER 1.2.840.10045.3.1.7 (secp256r1)
    //   }
    //   OCTET STRING (私钥数据)
    // }
    
    NSMutableData *x509Data = [NSMutableData data];
    
    // 算法标识符部分 (30 59 30 13 06 07 2a 86 48 ce 3d 02 01 06 08 2a 86 48 ce 3d 03 01 07)
    uint8_t algorithmIdentifier[] = {
        0x30, 0x13,                                     // SEQUENCE (算法标识符)
        0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,  // OID: 1.2.840.10045.2.1 (ecPrivateKey)
        0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07  // OID: 1.2.840.10045.3.1.7 (secp256r1)
    };
    
    // OCTET STRING 头部 (04 20)
    uint8_t octetStringHeader[] = {
        0x04, 0x20  // OCTET STRING, 32字节私钥数据
    };
    
    // 计算总长度并构建最外层 SEQUENCE
    NSUInteger totalContentLength = sizeof(algorithmIdentifier) + sizeof(octetStringHeader) + rawPrivateKey.length;
    
    // 最外层 SEQUENCE 头部
    [x509Data appendBytes:(uint8_t[]){0x30} length:1];  // SEQUENCE tag
    
    // 编码长度
    if (totalContentLength < 0x80) {
        [x509Data appendBytes:&totalContentLength length:1];
    } else {
        [x509Data appendBytes:(uint8_t[]){0x81, (uint8_t)totalContentLength} length:2];
    }
    
    // 添加算法标识符
    [x509Data appendBytes:algorithmIdentifier length:sizeof(algorithmIdentifier)];
    
    // 添加 OCTET STRING 头部
    [x509Data appendBytes:octetStringHeader length:sizeof(octetStringHeader)];
    
    // 添加原始私钥数据
    [x509Data appendData:rawPrivateKey];
    
    CIMLog(@"🔧 X.509 DER编码完成:");
    CIMLog(@"   - 原始私钥: %lu字节", (unsigned long)rawPrivateKey.length);
    CIMLog(@"   - X.509 DER: %lu字节", (unsigned long)x509Data.length);
    CIMLog(@"   - X.509 hex: %@", [self hexStringFromData:x509Data]);
    
    return [x509Data copy];
}

/**
 * 从 X.509 DER 格式中提取原始公钥数据
 * 解析 X.509 DER 格式的 ECDSA 公钥
 */
+ (NSData * _Nullable)extractRawPublicKeyFromX509DER:(NSData *)x509Data {
    if (!x509Data || x509Data.length < 26) {
        CIMLog(@"❌ X.509 DER数据无效，长度不足");
        return nil;
    }
    
    const uint8_t *bytes = (const uint8_t *)x509Data.bytes;
    
    // 验证 X.509 DER 结构
    // 期望格式: 30 59 30 13 06 07 2a 86 48 ce 3d 02 01 06 08 2a 86 48 ce 3d 03 01 07 03 42 00 + 65字节公钥数据
    if (bytes[0] != 0x30) {
        CIMLog(@"❌ X.509 DER格式错误，不是SEQUENCE");
        return nil;
    }
    
    CIMLog(@"📋 开始解析X.509 DER数据，总长度: %lu字节", (unsigned long)x509Data.length);
    CIMLog(@"📋 数据hex: %@", [self hexStringFromData:x509Data]);
    
    // 简单方法：直接从末尾提取65字节作为公钥数据
    // 因为P-256公钥总是65字节，我们可以从末尾往前取
    if (x509Data.length >= 65) {
        NSData *rawPublicKey = [x509Data subdataWithRange:NSMakeRange(x509Data.length - 65, 65)];
        
        // 验证公钥格式：第一个字节应该是0x04（未压缩格式）
        const uint8_t *keyBytes = (const uint8_t *)rawPublicKey.bytes;
        if (keyBytes[0] == 0x04) {
            CIMLog(@"✅ 从X.509 DER提取原始公钥成功（简单方法）:");
            CIMLog(@"   - X.509 DER长度: %lu字节", (unsigned long)x509Data.length);
            CIMLog(@"   - 原始公钥长度: %lu字节", (unsigned long)rawPublicKey.length);
            CIMLog(@"   - 原始公钥hex: %@", [self hexStringFromData:rawPublicKey]);
            
            return rawPublicKey;
        } else {
            CIMLog(@"❌ 提取的公钥格式错误，第一个字节不是0x04");
        }
    }
    
    // 如果简单方法失败，尝试详细解析
    CIMLog(@"⚠️ 简单方法失败，尝试详细解析...");
    
    // 查找 BIT STRING 标记 (03)
    NSUInteger offset = 0;
    BOOL foundBitString = NO;
    
    for (NSUInteger i = 0; i < x509Data.length - 3; i++) {
        if (bytes[i] == 0x03) { // BIT STRING
            offset = i;
            foundBitString = YES;
            break;
        }
    }
    
    if (!foundBitString) {
        CIMLog(@"❌ X.509 DER中未找到BIT STRING标记");
        return nil;
    }
    
    CIMLog(@"📋 找到BIT STRING标记，位置: %lu", (unsigned long)offset);
    
    // 读取 BIT STRING 长度
    if (offset + 2 >= x509Data.length) {
        CIMLog(@"❌ BIT STRING长度数据不完整");
        return nil;
    }
    
    NSUInteger bitStringLength = bytes[offset + 1];
    if (bitStringLength == 0x81) {
        // 长度超过127，使用2字节长度
        if (offset + 3 >= x509Data.length) {
            CIMLog(@"❌ BIT STRING扩展长度数据不完整");
            return nil;
        }
        bitStringLength = bytes[offset + 2];
        offset += 3;
    } else if (bitStringLength == 0x82) {
        // 长度超过255，使用3字节长度
        if (offset + 4 >= x509Data.length) {
            CIMLog(@"❌ BIT STRING扩展长度数据不完整");
            return nil;
        }
        bitStringLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 4;
    } else {
        offset += 2;
    }
    
    CIMLog(@"📋 BIT STRING长度: %lu字节", (unsigned long)bitStringLength);
    
    // 跳过填充字节 (00)
    if (offset >= x509Data.length || bytes[offset] != 0x00) {
        CIMLog(@"❌ BIT STRING填充字节错误");
        return nil;
    }
    offset += 1;
    
    // 提取原始公钥数据 (应该是65字节)
    NSUInteger remainingLength = x509Data.length - offset;
    CIMLog(@"📋 剩余数据长度: %lu字节", (unsigned long)remainingLength);
    
    if (remainingLength != 65) {
        CIMLog(@"❌ 原始公钥数据长度错误，期望65字节，实际%lu字节", (unsigned long)remainingLength);
        CIMLog(@"📋 当前offset: %lu", (unsigned long)offset);
        CIMLog(@"📋 数据总长度: %lu", (unsigned long)x509Data.length);
        return nil;
    }
    
    NSData *rawPublicKey = [x509Data subdataWithRange:NSMakeRange(offset, 65)];
    
    CIMLog(@"✅ 从X.509 DER提取原始公钥成功（详细解析）:");
    CIMLog(@"   - X.509 DER长度: %lu字节", (unsigned long)x509Data.length);
    CIMLog(@"   - 原始公钥长度: %lu字节", (unsigned long)rawPublicKey.length);
    CIMLog(@"   - 原始公钥hex: %@", [self hexStringFromData:rawPublicKey]);
    
    return rawPublicKey;
}

/**
 * 将原始公钥数据转换为X.509 DER格式
 * P-256 公钥的 X.509 DER 编码格式
 */
+ (NSData * _Nullable)convertRawPublicKeyToX509DER:(NSData *)rawPublicKey {
    if (!rawPublicKey || rawPublicKey.length != 65) {
        CIMLog(@"❌ 原始公钥数据无效，期望65字节，实际%lu字节", (unsigned long)rawPublicKey.length);
        return nil;
    }
    
    // P-256 公钥的 X.509 DER 编码结构：
    // SEQUENCE {
    //   SEQUENCE {
    //     OBJECT IDENTIFIER 1.2.840.10045.2.1 (ecPublicKey)
    //     OBJECT IDENTIFIER 1.2.840.10045.3.1.7 (secp256r1)
    //   }
    //   BIT STRING (公钥数据)
    // }
    
    NSMutableData *x509Data = [NSMutableData data];
    
    // 算法标识符部分 (30 59 30 13 06 07 2a 86 48 ce 3d 02 01 06 08 2a 86 48 ce 3d 03 01 07)
    uint8_t algorithmIdentifier[] = {
        0x30, 0x13,                                     // SEQUENCE (算法标识符)
        0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,  // OID: 1.2.840.10045.2.1 (ecPublicKey)
        0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07  // OID: 1.2.840.10045.3.1.7 (secp256r1)
    };
    
    // BIT STRING 头部 (03 42 00)
    uint8_t bitStringHeader[] = {
        0x03, 0x42, 0x00  // BIT STRING, 66字节长度(65字节数据+1字节填充), 0填充位
    };
    
    // 计算总长度并构建最外层 SEQUENCE
    NSUInteger totalContentLength = sizeof(algorithmIdentifier) + sizeof(bitStringHeader) + rawPublicKey.length;
    
    // 最外层 SEQUENCE 头部
    [x509Data appendBytes:(uint8_t[]){0x30} length:1];  // SEQUENCE tag
    
    // 编码长度
    if (totalContentLength < 0x80) {
        [x509Data appendBytes:&totalContentLength length:1];
    } else {
        [x509Data appendBytes:(uint8_t[]){0x81, (uint8_t)totalContentLength} length:2];
    }
    
    // 添加算法标识符
    [x509Data appendBytes:algorithmIdentifier length:sizeof(algorithmIdentifier)];
    
    // 添加 BIT STRING 头部
    [x509Data appendBytes:bitStringHeader length:sizeof(bitStringHeader)];
    
    // 添加原始公钥数据
    [x509Data appendData:rawPublicKey];
    
    CIMLog(@"🔧 X.509 DER编码完成:");
    CIMLog(@"   - 原始公钥: %lu字节", (unsigned long)rawPublicKey.length);
    CIMLog(@"   - X.509 DER: %lu字节", (unsigned long)x509Data.length);
    CIMLog(@"   - X.509 hex: %@", [self hexStringFromData:x509Data]);
    
    return [x509Data copy];
}

/**
 * 验证公钥是否有效
 * 对应服务端的 isValidPublicKey(byte[] publicKeyBytes) 方法
 */
+ (BOOL)isValidPublicKey:(NSData *)publicKeyBytes {
    NSError *error = nil;
    SecKeyRef publicKey = [self reconstructPublicKeyFromBytes:publicKeyBytes error:&error];
    
    if (publicKey) {
        CFRelease(publicKey);
        return YES;
    } else {
        CIMLog(@"⚠️ 公钥验证失败: %@", error.localizedDescription);
        return NO;
    }
}

#pragma mark - 共享密钥计算

/**
 * 计算ECDH共享密钥 - 从字节数组
 * 对应服务端的 computeSharedSecret(PrivateKey privateKey, byte[] publicKeyBytes) 方法
 */
+ (NSData * _Nullable)computeSharedSecretWithPrivateKey:(SecKeyRef)privateKey 
                                         publicKeyBytes:(NSData *)publicKeyBytes 
                                                  error:(NSError **)error {
    
    CIMLog(@"🔄 计算ECDH共享密钥 (从字节数组)...");
    
    // 先重构远程公钥
    SecKeyRef remotePublicKey = [self reconstructPublicKeyFromBytes:publicKeyBytes error:error];
    if (!remotePublicKey) {
        CIMLog(@"❌ 远程公钥重构失败");
        return nil;
    }
    
    // 计算共享密钥
    NSData *sharedSecret = [self computeSharedSecretWithPrivateKey:privateKey 
                                                         publicKey:remotePublicKey 
                                                             error:error];
    
    // 清理临时公钥
    CFRelease(remotePublicKey);
    
    return sharedSecret;
}

/**
 * 计算ECDH共享密钥 - 核心实现
 * 对应服务端的 computeSharedSecret(PrivateKey privateKey, PublicKey publicKey) 方法
 */
+ (NSData * _Nullable)computeSharedSecretWithPrivateKey:(SecKeyRef)privateKey 
                                              publicKey:(SecKeyRef)publicKey 
                                                  error:(NSError **)error {
    
    CIMLog(@"🔄 开始计算ECDH共享密钥...");
    
    // 验证密钥类型
    if (![self isSecp256r1Key:privateKey] || ![self isSecp256r1Key:publicKey]) {
        NSString *errorMsg = @"密钥不是secp256r1类型";
        CIMLog(@"❌ %@", errorMsg);
        if (error) {
            *error = [NSError errorWithDomain:ECDHKeyManagerErrorDomain
                                         code:-4
                                     userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
        }
        return nil;
    }
    
    // 使用Security框架计算ECDH共享密钥
    CFErrorRef cfError = NULL;
    CFDataRef sharedSecret = SecKeyCopyKeyExchangeResult(
        privateKey,
        kSecKeyAlgorithmECDHKeyExchangeStandard,  // 标准ECDH算法
        publicKey,
        (__bridge CFDictionaryRef)@{},
        &cfError
    );
    
    if (cfError != NULL) {
        if (error) {
            *error = (__bridge_transfer NSError *)cfError;
        }
        CIMLog(@"❌ ECDH共享密钥计算失败: %@", ((__bridge NSError *)cfError).localizedDescription);
        return nil;
    }
    
    NSData *sharedSecretData = (__bridge_transfer NSData *)sharedSecret;
    CIMLog(@"✅ ECDH共享密钥计算成功，长度: %lu字节", (unsigned long)sharedSecretData.length);
    CIMLog(@"🔐 共享密钥: %@", [self hexStringFromData:sharedSecretData]);
    
    return sharedSecretData;
}

#pragma mark - 密钥验证

/**
 * 验证密钥是否为secp256r1类型
 */
+ (BOOL)isSecp256r1Key:(SecKeyRef)key {
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes) {
        CIMLog(@"⚠️ 无法获取密钥属性");
        return NO;
    }
    
    NSDictionary *attrs = (__bridge_transfer NSDictionary *)attributes;
    NSNumber *keySize = attrs[(id)kSecAttrKeySizeInBits];
    NSString *keyType = attrs[(id)kSecAttrKeyType];
    
    BOOL isSecp256r1 = [keySize intValue] == kKeySize && 
                       [keyType isEqualToString:(id)kSecAttrKeyTypeECSECPrimeRandom];
    
    if (!isSecp256r1) {
        CIMLog(@"⚠️ 密钥不是secp256r1类型: 大小=%@位, 类型=%@", keySize, keyType);
    }
    
    return isSecp256r1;
}

#pragma mark - 调试工具

/**
 * 打印密钥详细信息
 */
+ (void)printKeyInfo:(SecKeyRef)key label:(NSString *)label {
    CFDictionaryRef attributes = SecKeyCopyAttributes(key);
    if (!attributes) {
        CIMLog(@"❌ %@ 密钥信息获取失败", label);
        return;
    }
    
    NSDictionary *attrs = (__bridge_transfer NSDictionary *)attributes;
    NSNumber *keySize = attrs[(id)kSecAttrKeySizeInBits];
    NSString *keyType = attrs[(id)kSecAttrKeyType];
    NSString *keyClass = attrs[(id)kSecAttrKeyClass];
    NSString *applicationTag = [[NSString alloc] initWithData:attrs[(id)kSecAttrApplicationTag] 
                                                     encoding:NSUTF8StringEncoding];
    
    CIMLog(@"🔑 %@ 详细信息:", label);
    CIMLog(@"   椭圆曲线: %@ (secp256r1)", kCurveName);
    CIMLog(@"   算法: %@", kECDHAlgorithm);
    CIMLog(@"   密钥类型: %@", keyType);
    CIMLog(@"   密钥类别: %@", keyClass);
    CIMLog(@"   密钥长度: %@位", keySize);
    CIMLog(@"   应用标签: %@", applicationTag ?: @"N/A");
    CIMLog(@"   安全等级: 128位对称加密等效");
}

#pragma mark - 数据转换工具

/**
 * 将NSData转换为十六进制字符串
 */
+ (NSString *)hexStringFromData:(NSData *)data {
    if (!data) return @"";
    
    NSMutableString *hexString = [NSMutableString stringWithCapacity:data.length * 2];
    const unsigned char *bytes = (const unsigned char *)data.bytes;
    
    for (NSUInteger i = 0; i < data.length; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
    }
    
    return [hexString copy];
}

/**
 * 从十六进制字符串转换为NSData
 */
+ (NSData * _Nullable)dataFromHexString:(NSString *)hexString {
    if (!hexString || hexString.length == 0) return nil;
    
    // 移除空格和换行符
    NSString *cleanHex = [[hexString componentsSeparatedByCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    
    if (cleanHex.length % 2 != 0) {
        CIMLog(@"❌ 十六进制字符串长度必须是偶数: %@", cleanHex);
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithCapacity:cleanHex.length / 2];
    
    for (NSUInteger i = 0; i < cleanHex.length; i += 2) {
        NSString *byteString = [cleanHex substringWithRange:NSMakeRange(i, 2)];
        unsigned int byteValue;
        if ([[NSScanner scannerWithString:byteString] scanHexInt:&byteValue]) {
            uint8_t byte = (uint8_t)byteValue;
            [data appendBytes:&byte length:1];
        } else {
            CIMLog(@"❌ 无效的十六进制字符: %@", byteString);
            return nil;
        }
    }
    
    return [data copy];
}

@end
