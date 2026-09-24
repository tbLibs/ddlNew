//
//  ZIMMessageDecoder.h
//  ZIM Client
//
//  Created by Connector Handler
//  Copyright © 2024 ZLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageProtocolHeader.h"
#import "ZIMAESEncryption.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * ZIM消息解码结果
 */
@interface ZIMDecodedMessage : NSObject

/**
 * 协议头信息
 */
@property (nonatomic, strong, readonly) MessageProtocolHeader *protocolHeader;

/**
 * 解码后的消息数据（ProtoBuf格式）
 */
@property (nonatomic, strong, readonly) NSData *messageData;

/**
 * 是否为加密消息
 */
@property (nonatomic, readonly) BOOL isEncrypted;

/**
 * 创建解码结果实例
 */
+ (instancetype)messageWithHeader:(MessageProtocolHeader *)header
                      messageData:(NSData *)messageData
                      isEncrypted:(BOOL)isEncrypted;

@end

/**
 * ZIM消息解码器
 * 
 * 负责解析从服务端接收的消息，支持明文和AES加密消息
 * 与服务端的 AesEncryptionHandler 保持完全一致的解码逻辑
 */
@interface ZIMMessageDecoder : NSObject

/**
 * AES密钥（用于解密和HMAC验证）
 */
@property (nonatomic, strong, nullable) NSData *aesKey;

/**
 * 创建解码器实例
 */
+ (instancetype)decoder;

/**
 * 创建带AES密钥的解码器实例
 * 
 * @param aesKey AES密钥（32字节）- 同时用于解密和HMAC验证
 * @return 解码器实例
 */
+ (instancetype)decoderWithAESKey:(NSData *)aesKey;

/**
 * 解码完整的ZIM消息
 * 
 * @param messageData 从服务端接收的完整消息数据
 * @return 解码结果，失败返回nil
 */
- (nullable ZIMDecodedMessage *)decodeMessage:(NSData *)messageData;

/**
 * 解码明文消息
 * 
 * @param messageData 完整消息数据
 * @param protocolHeader 已解析的协议头
 * @return 解码结果，失败返回nil
 */
- (nullable ZIMDecodedMessage *)decodePlainMessage:(NSData *)messageData 
                                    protocolHeader:(MessageProtocolHeader *)protocolHeader;

/**
 * 解码AES加密消息
 * 
 * @param messageData 完整消息数据
 * @param protocolHeader 已解析的协议头
 * @return 解码结果，失败返回nil
 */
- (nullable ZIMDecodedMessage *)decodeEncryptedMessage:(NSData *)messageData 
                                        protocolHeader:(MessageProtocolHeader *)protocolHeader;

/**
 * 验证和解析AES加密消息体
 * 
 * @param encryptedBody AES加密的消息体数据
 * @return 解密后的ProtoBuf数据，失败返回nil
 */
- (nullable NSData *)decryptMessageBody:(NSData *)encryptedBody;

/**
 * 验证HMAC
 * 
 * @param encryptedData 加密数据
 * @param receivedHMAC 接收到的HMAC
 * @return YES表示验证通过，NO表示验证失败
 */
- (BOOL)verifyHMAC:(NSData *)encryptedData receivedHMAC:(NSData *)receivedHMAC;

/**
 * 检查解码器是否已配置AES密钥
 * 
 * @return YES表示已配置，NO表示未配置
 */
- (BOOL)hasAESKey;

@end

NS_ASSUME_NONNULL_END
