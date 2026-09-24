//
//  ZIMMessageDecoder.m
//  ZIM Client
//
//  Created by Connector Handler
//  Copyright © 2024 ZLC. All rights reserved.
//

#import "ZIMMessageDecoder.h"

// 常量定义
static const NSUInteger kLengthFieldSize = 4;        // 长度字段大小

#pragma mark - ZIMDecodedMessage

@interface ZIMDecodedMessage ()

@property (nonatomic, strong, readwrite) MessageProtocolHeader *protocolHeader;
@property (nonatomic, strong, readwrite) NSData *messageData;
@property (nonatomic, readwrite) BOOL isEncrypted;

@end

@implementation ZIMDecodedMessage

+ (instancetype)messageWithHeader:(MessageProtocolHeader *)header
                      messageData:(NSData *)messageData
                      isEncrypted:(BOOL)isEncrypted {
    ZIMDecodedMessage *message = [[ZIMDecodedMessage alloc] init];
    if (message) {
        message.protocolHeader = header;
        message.messageData = messageData;
        message.isEncrypted = isEncrypted;
    }
    return message;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"ZIMDecodedMessage{encrypted=%@, messageLength=%lu, header=%@}",
            self.isEncrypted ? @"YES" : @"NO", 
            (unsigned long)self.messageData.length,
            self.protocolHeader];
}

@end

#pragma mark - ZIMMessageDecoder

@implementation ZIMMessageDecoder

#pragma mark - Initialization

+ (instancetype)decoder {
    return [[ZIMMessageDecoder alloc] init];
}

+ (instancetype)decoderWithAESKey:(NSData *)aesKey {
    ZIMMessageDecoder *decoder = [[ZIMMessageDecoder alloc] init];
    if (decoder) {
        decoder.aesKey = aesKey;
    }
    return decoder;
}

#pragma mark - Main Decoding Methods

- (nullable ZIMDecodedMessage *)decodeMessage:(NSData *)messageData {
    if (!messageData || messageData.length < [MessageProtocolHeader protocolHeaderLength]) {
        NSLog(@"❌ 消息数据无效或长度不足: %lu < %lu",
              (unsigned long)(messageData ? messageData.length : 0), 
              (unsigned long)[MessageProtocolHeader protocolHeaderLength]);
        return nil;
    }
    
    NSLog(@"🔍 开始解码ZIM消息，总长度: %lu字节", (unsigned long)messageData.length);
    
    // 1. 解析协议头
    MessageProtocolHeader *protocolHeader = [MessageProtocolHeader readFromData:messageData];
    if (!protocolHeader) {
        NSLog(@"❌ 协议头解析失败");
        return nil;
    }
    
    NSLog(@"📋 协议头解析成功: %@", protocolHeader);
    
    // 2. 验证消息完整性
    if (messageData.length != protocolHeader.totalLength) {
        NSLog(@"❌ 消息长度不匹配: 期望=%u, 实际=%lu", 
              protocolHeader.totalLength, (unsigned long)messageData.length);
        return nil;
    }
    
    // 3. 根据加密标志选择解码方法
    if ([protocolHeader isAesEncrypted]) {
        return [self decodeEncryptedMessage:messageData protocolHeader:protocolHeader];
    } else {
        return [self decodePlainMessage:messageData protocolHeader:protocolHeader];
    }
}

- (nullable ZIMDecodedMessage *)decodePlainMessage:(NSData *)messageData 
                                    protocolHeader:(MessageProtocolHeader *)protocolHeader {
    NSLog(@"📝 解码明文消息，消息体长度: %u字节", [protocolHeader messageBodyLength]);
    
    // 提取消息体数据
    NSUInteger headerLength = [MessageProtocolHeader protocolHeaderLength];
    NSUInteger messageBodyLength = [protocolHeader messageBodyLength];
    
    if (messageData.length < headerLength + messageBodyLength) {
        NSLog(@"❌ 明文消息体数据不足");
        return nil;
    }
    
    NSRange messageBodyRange = NSMakeRange(headerLength, messageBodyLength);
    NSData *protobufData = [messageData subdataWithRange:messageBodyRange];
    
    NSLog(@"✅ 明文消息解码完成，ProtoBuf数据长度: %lu字节", (unsigned long)protobufData.length);
    
    return [ZIMDecodedMessage messageWithHeader:protocolHeader 
                                    messageData:protobufData 
                                    isEncrypted:NO];
}

- (nullable ZIMDecodedMessage *)decodeEncryptedMessage:(NSData *)messageData 
                                        protocolHeader:(MessageProtocolHeader *)protocolHeader {
    NSLog(@"🔐 解码AES加密消息，消息体长度: %ld字节", [protocolHeader messageBodyLength]);
    
    if (![self hasAESKey]) {
        NSLog(@"❌ AES密钥未配置，无法解密");
        return nil;
    }
    
    // 提取加密消息体数据
    NSUInteger headerLength = [MessageProtocolHeader protocolHeaderLength];
    NSUInteger messageBodyLength = [protocolHeader messageBodyLength];
    
    if (messageData.length < headerLength + messageBodyLength) {
        NSLog(@"❌ AES加密消息体数据不足");
        return nil;
    }
    
    NSRange messageBodyRange = NSMakeRange(headerLength, messageBodyLength);
    NSData *encryptedBody = [messageData subdataWithRange:messageBodyRange];
    
    NSLog(@"🔍 AES消息体前20字节: %@", 
          [[encryptedBody subdataWithRange:NSMakeRange(0, MIN(20, encryptedBody.length))] description]);
    
    // 解密消息体
    NSData *protobufData = [self decryptMessageBody:encryptedBody];
    if (!protobufData) {
        NSLog(@"❌ AES消息解密失败");
        return nil;
    }
    
    NSLog(@"✅ AES加密消息解码完成，ProtoBuf数据长度: %lu字节", (unsigned long)protobufData.length);
    
    return [ZIMDecodedMessage messageWithHeader:protocolHeader 
                                    messageData:protobufData 
                                    isEncrypted:YES];
}

#pragma mark - AES Decryption

- (nullable NSData *)decryptMessageBody:(NSData *)encryptedBody {
    if (!encryptedBody || encryptedBody.length < 3 * kLengthFieldSize) {
        NSLog(@"❌ 加密消息体数据无效或长度不足");
        return nil;
    }
    
    NSLog(@"🔐 开始解析AES加密消息体...");
    
    const uint8_t *bytes = (const uint8_t *)encryptedBody.bytes;
    NSUInteger offset = 0;
    
    // 1. 读取IV长度和IV数据
    if (offset + kLengthFieldSize > encryptedBody.length) {
        NSLog(@"❌ 无法读取IV长度");
        return nil;
    }
    
    uint32_t ivLength = CFSwapInt32BigToHost(*(uint32_t *)(bytes + offset));
    offset += kLengthFieldSize;
    
    NSLog(@"📋 IV长度: %u字节", ivLength);
    
    if (offset + ivLength > encryptedBody.length) {
        NSLog(@"❌ IV数据不足");
        return nil;
    }
    
    NSData *iv = [encryptedBody subdataWithRange:NSMakeRange(offset, ivLength)];
    offset += ivLength;
    
    // 2. 读取HMAC长度和HMAC数据
    if (offset + kLengthFieldSize > encryptedBody.length) {
        NSLog(@"❌ 无法读取HMAC长度");
        return nil;
    }
    
    uint32_t hmacLength = CFSwapInt32BigToHost(*(uint32_t *)(bytes + offset));
    offset += kLengthFieldSize;
    
    NSLog(@"📋 HMAC长度: %u字节", hmacLength);
    
    if (offset + hmacLength > encryptedBody.length) {
        NSLog(@"❌ HMAC数据不足");
        return nil;
    }
    
    NSData *hmac = [encryptedBody subdataWithRange:NSMakeRange(offset, hmacLength)];
    offset += hmacLength;
    
    // 3. 读取加密数据长度和加密数据
    if (offset + kLengthFieldSize > encryptedBody.length) {
        NSLog(@"❌ 无法读取加密数据长度");
        return nil;
    }
    
    uint32_t encryptedDataLength = CFSwapInt32BigToHost(*(uint32_t *)(bytes + offset));
    offset += kLengthFieldSize;
    
    NSLog(@"📋 加密数据长度: %u字节", encryptedDataLength);
    
    if (offset + encryptedDataLength != encryptedBody.length) {
        NSLog(@"❌ 加密数据长度不匹配: 期望=%u, 剩余=%lu", 
              encryptedDataLength, (unsigned long)(encryptedBody.length - offset));
        return nil;
    }
    
    NSData *encryptedData = [encryptedBody subdataWithRange:NSMakeRange(offset, encryptedDataLength)];
    
    NSLog(@"✅ AES消息体解析完成: IV=%u字节, HMAC=%u字节, 加密数据=%u字节", 
          ivLength, hmacLength, encryptedDataLength);
    
    // 4. 验证HMAC
    NSLog(@"🔐 开始HMAC验证...");
    if (![self verifyHMAC:encryptedData receivedHMAC:hmac]) {
        NSLog(@"❌ HMAC验证失败，消息可能被篡改");
        return nil;
    }
    
    NSLog(@"✅ HMAC验证成功");
    
    // 5. AES解密
    NSLog(@"🔐 开始AES解密...");
    NSData *decryptedData = [ZIMAESEncryption decryptData:encryptedData withKey:self.aesKey iv:iv];
    if (!decryptedData) {
        NSLog(@"❌ AES解密失败");
        return nil;
    }
    
    NSLog(@"✅ AES解密成功，解密后数据长度: %lu字节", (unsigned long)decryptedData.length);
    
    return decryptedData;
}

- (BOOL)verifyHMAC:(NSData *)encryptedData receivedHMAC:(NSData *)receivedHMAC {
    if (!encryptedData || !receivedHMAC || ![self hasAESKey]) {
        NSLog(@"❌ HMAC验证参数无效");
        return NO;
    }
    
    NSLog(@"🔍 计算期望HMAC，密钥长度: %lu, 数据长度: %lu", 
          (unsigned long)self.aesKey.length, (unsigned long)encryptedData.length);
    NSLog(@"🔍 AES密钥前16字节: %@", 
          [[self.aesKey subdataWithRange:NSMakeRange(0, MIN(16, self.aesKey.length))] description]);
    
    // 使用AES密钥计算HMAC（与服务端保持一致）
    NSData *expectedHMAC = [ZIMAESEncryption hmacSHA256:encryptedData withKey:self.aesKey];
    if (!expectedHMAC) {
        NSLog(@"❌ HMAC计算失败");
        return NO;
    }
    
    NSLog(@"🔍 HMAC计算完成，结果长度: %lu", (unsigned long)expectedHMAC.length);
    
    // 比较HMAC值
    BOOL isValid = [expectedHMAC isEqualToData:receivedHMAC];
    
    if (isValid) {
        NSLog(@"✅ HMAC验证通过");
    } else {
        NSLog(@"❌ HMAC验证失败");
        NSLog(@"   期望HMAC: %@", [expectedHMAC description]);
        NSLog(@"   接收HMAC: %@", [receivedHMAC description]);
    }
    
    return isValid;
}

#pragma mark - Validation

- (BOOL)hasAESKey {
    return self.aesKey != nil && self.aesKey.length == 32;
}

@end
