//
//  NovDecryptorManager.h
//  NoaKit
//
//  Created by Candy on 2025/8/30.
//
#import <Foundation/Foundation.h>
#import <Security/Security.h>
// 消息解密
#import "ZIMMessageDecoder.h"

NS_ASSUME_NONNULL_BEGIN

// 增强帧协议头格式：[帧头标识(8字节)][消息体长度(4字节)]
typedef struct {
    uint8_t frameIdentifier[8];  // 帧头标识 8B (AES密钥前8字节)
    uint32_t actualDataLength;   // 消息体长度 4B (只包含消息体，不包含扰乱数据)
} __attribute__((packed)) MessageFrameHeader;

#define MESSAGE_FRAME_HEADER_SIZE sizeof(MessageFrameHeader)

@interface NovDecryptorManager : NSObject

/// 公钥
@property (nonatomic) SecKeyRef privateKey;

/// 私钥
@property (nonatomic) SecKeyRef publicKey;

/// 服务器公钥与APP私钥处理的共享密钥，用于后续的消息加解密操作
@property (nonatomic, strong, nullable) NSData *shareKey;

/// 获取到的服务器公钥数据
@property (nonatomic, strong, nullable) NSData *serverPublicKeyData;

/// 将APP获取的密钥进行转码成NSData
/// - Parameter keyRef: APP密钥
- (NSData *)secKeyRefToData:(SecKeyRef)keyRef;

// 获取edch公钥与私钥
- (void)generateKeyPairWithComplete:(void (^)(SecKeyRef publicKey, SecKeyRef privateKey))complete;

/// 交换密钥(服务器公钥与APP私钥共享)
- (BOOL)generateSharedSecret;

/// 获取服务器公钥请求消息
/// - Parameter appPublicKey: app公钥
- (NSData *)buildServerPublicKeyRequestMessage:(NSData *)appPublicKeyBase64Data;

/// 返解服务器公钥数据
/// - Parameters:
///   - messageData: 服务器返回消息
///   - error: 异常
- (BOOL)parseServerPublicKeyMessageSync:(NSData *)messageData;

/// 构建增强帧协议格式的加密消息帧（合并原buildEncryptedMessageFrameWithData和buildEnhancedFrameProtocolMessageWithData）
/// - Parameter data: 需要加密的原始数据
/// - Returns: 增强帧协议格式的完整消息帧
- (NSData *)buildEncryptedMessageFrameWithData:(NSData *)data;

#pragma mark - 增强帧协议支持

/// 解析增强帧协议格式的消息
/// @param enhancedFrameData 增强帧协议格式的数据
/// @return 解密后的原始数据
- (NSData *)parseEnhancedFrameProtocolMessage:(NSData *)enhancedFrameData;

/// 获取帧头标识符（shareKey的前8字节）
/// @return 帧头标识符，如果shareKey未准备好则返回nil
- (NSData * _Nullable)getFrameIdentifier;

@end

NS_ASSUME_NONNULL_END

