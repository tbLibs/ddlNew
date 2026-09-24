//
//  ZIMAESEncryption.m
//  ZIM Client
//
//  Created by Connector Handler
//  Copyright © 2024 ZLC. All rights reserved.
//

#import "ZIMAESEncryption.h"
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

// 常量定义
static const NSUInteger kStandardIVLength = 16;      // AES-128/256 标准IV长度
static const NSUInteger kStandardHMACLength = 32;    // HMAC-SHA256 输出长度
static const NSUInteger kAESKeyLength = 32;          // AES-256 密钥长度
static const NSUInteger kLengthFieldSize = 4;        // 长度字段大小

#pragma mark - ZIMAESEncryptedBody

@interface ZIMAESEncryptedBody ()

@property (nonatomic, strong, readwrite) NSData *iv;
@property (nonatomic, strong, readwrite) NSData *hmac;
@property (nonatomic, strong, readwrite) NSData *encryptedData;

@end

@implementation ZIMAESEncryptedBody

+ (instancetype)bodyWithIV:(NSData *)iv hmac:(NSData *)hmac encryptedData:(NSData *)encryptedData {
    ZIMAESEncryptedBody *body = [[ZIMAESEncryptedBody alloc] init];
    if (body) {
        body.iv = iv;
        body.hmac = hmac;
        body.encryptedData = encryptedData;
    }
    return body;
}

- (NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    
    // 1. IV长度 (4字节, Big-Endian)
    uint32_t ivLength = CFSwapInt32HostToBig((uint32_t)self.iv.length);
    [data appendBytes:&ivLength length:kLengthFieldSize];
    
    // 2. IV数据
    [data appendData:self.iv];
    
    // 3. HMAC长度 (4字节, Big-Endian)
    uint32_t hmacLength = CFSwapInt32HostToBig((uint32_t)self.hmac.length);
    [data appendBytes:&hmacLength length:kLengthFieldSize];
    
    // 4. HMAC数据
    [data appendData:self.hmac];
    
    // 5. 加密数据长度 (4字节, Big-Endian)
    uint32_t encryptedLength = CFSwapInt32HostToBig((uint32_t)self.encryptedData.length);
    [data appendBytes:&encryptedLength length:kLengthFieldSize];
    
    // 6. 加密数据
    [data appendData:self.encryptedData];
    
    NSLog(@"🔐 AES加密消息体序列化完成: 总长度=%lu, IV=%lu字节, HMAC=%lu字节, 加密数据=%lu字节", 
          (unsigned long)data.length, (unsigned long)self.iv.length, (unsigned long)self.hmac.length, (unsigned long)self.encryptedData.length);
    
    return [data copy];
}

- (uint32_t)totalLength {
    return (uint32_t)(3 * kLengthFieldSize + self.iv.length + self.hmac.length + self.encryptedData.length);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"ZIMAESEncryptedBody{ivLength=%lu, hmacLength=%lu, encryptedDataLength=%lu, totalLength=%u}",
            (unsigned long)self.iv.length, (unsigned long)self.hmac.length, (unsigned long)self.encryptedData.length, [self totalLength]];
}

@end

#pragma mark - ZIMAESEncryption

@implementation ZIMAESEncryption

#pragma mark - Class Properties

+ (NSUInteger)standardIVLength {
    return kStandardIVLength;
}

+ (NSUInteger)standardHMACLength {
    return kStandardHMACLength;
}

#pragma mark - AES Encryption/Decryption

+ (nullable NSData *)encryptData:(NSData *)plainData withKey:(NSData *)key iv:(NSData *)iv {
    if (!plainData || !key || !iv) {
        NSLog(@"❌ AES加密参数无效");
        return nil;
    }
    
    if (key.length != kAESKeyLength) {
        NSLog(@"❌ AES密钥长度无效: %lu (期望: %lu)", (unsigned long)key.length, (unsigned long)kAESKeyLength);
        return nil;
    }
    
    if (iv.length != kStandardIVLength) {
        NSLog(@"❌ IV长度无效: %lu (期望: %lu)", (unsigned long)iv.length, (unsigned long)kStandardIVLength);
        return nil;
    }
    
    // 创建输出缓冲区
    size_t bufferSize = plainData.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    if (!buffer) {
        NSLog(@"❌ 内存分配失败");
        return nil;
    }
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                         kCCAlgorithmAES,
                                         kCCOptionPKCS7Padding,
                                         key.bytes,
                                         key.length,
                                         iv.bytes,
                                         plainData.bytes,
                                         plainData.length,
                                         buffer,
                                         bufferSize,
                                         &numBytesEncrypted);
    
    NSData *encryptedData = nil;
    if (cryptStatus == kCCSuccess) {
        encryptedData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
        NSLog(@"✅ AES加密成功: 明文=%lu字节, 密文=%lu字节", (unsigned long)plainData.length, (unsigned long)numBytesEncrypted);
    } else {
        NSLog(@"❌ AES加密失败: 状态码=%d", cryptStatus);
    }
    
    free(buffer);
    return encryptedData;
}

+ (nullable NSData *)decryptData:(NSData *)encryptedData withKey:(NSData *)key iv:(NSData *)iv {
    if (!encryptedData || !key || !iv) {
        NSLog(@"❌ AES解密参数无效");
        return nil;
    }
    
    if (key.length != kAESKeyLength) {
        NSLog(@"❌ AES密钥长度无效: %lu (期望: %lu)", (unsigned long)key.length, (unsigned long)kAESKeyLength);
        return nil;
    }
    
    if (iv.length != kStandardIVLength) {
        NSLog(@"❌ IV长度无效: %lu (期望: %lu)", (unsigned long)iv.length, (unsigned long)kStandardIVLength);
        return nil;
    }
    
    // 创建输出缓冲区
    size_t bufferSize = encryptedData.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    if (!buffer) {
        NSLog(@"❌ 内存分配失败");
        return nil;
    }
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                         kCCAlgorithmAES,
                                         kCCOptionPKCS7Padding,
                                         key.bytes,
                                         key.length,
                                         iv.bytes,
                                         encryptedData.bytes,
                                         encryptedData.length,
                                         buffer,
                                         bufferSize,
                                         &numBytesDecrypted);
    
    NSData *decryptedData = nil;
    if (cryptStatus == kCCSuccess) {
        decryptedData = [NSData dataWithBytes:buffer length:numBytesDecrypted];
        NSLog(@"✅ AES解密成功: 密文=%lu字节, 明文=%lu字节", (unsigned long)encryptedData.length, (unsigned long)numBytesDecrypted);
    } else {
        NSLog(@"❌ AES解密失败: 状态码=%d", cryptStatus);
    }
    
    free(buffer);
    return decryptedData;
}

#pragma mark - HMAC

+ (nullable NSData *)hmacSHA256:(NSData *)data withKey:(NSData *)key {
    if (!data || !key) {
        NSLog(@"❌ HMAC参数无效");
        return nil;
    }
    
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, data.bytes, data.length, hmac);
    
    NSData *hmacData = [NSData dataWithBytes:hmac length:CC_SHA256_DIGEST_LENGTH];
    NSLog(@"✅ HMAC-SHA256计算成功: 数据=%lu字节, HMAC=%lu字节", (unsigned long)data.length, (unsigned long)hmacData.length);
    
    return hmacData;
}

+ (BOOL)verifyHMAC:(NSData *)data expectedHMAC:(NSData *)expectedHMAC withKey:(NSData *)key {
    NSData *calculatedHMAC = [self hmacSHA256:data withKey:key];
    if (!calculatedHMAC) {
        NSLog(@"❌ HMAC计算失败");
        return NO;
    }
    
    BOOL isValid = [calculatedHMAC isEqualToData:expectedHMAC];
    NSLog(@"%@ HMAC验证%@", isValid ? @"✅" : @"❌", isValid ? @"通过" : @"失败");
    
    return isValid;
}

#pragma mark - Utility

+ (NSData *)generateRandomIV:(NSUInteger)length {
    NSMutableData *ivData = [NSMutableData dataWithLength:length];
    int result = SecRandomCopyBytes(kSecRandomDefault, length, ivData.mutableBytes);
    
    if (result != errSecSuccess) {
        NSLog(@"❌ 生成随机IV失败: %d", result);
        return nil;
    }
    
    NSLog(@"✅ 生成随机IV成功: %lu字节", (unsigned long)length);
    return [ivData copy];
}

@end
