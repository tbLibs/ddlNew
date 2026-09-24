//
//  ZIMAESEncryption.h
//  ZIM Client
//
//  Created by Connector Handler
//  Copyright © 2024 ZLC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * AES加密消息体结构
 */
@interface ZIMAESEncryptedBody : NSObject

/**
 * 初始化向量 (IV)
 */
@property (nonatomic, strong, readonly) NSData *iv;

/**
 * 消息认证码 (HMAC)
 */
@property (nonatomic, strong, readonly) NSData *hmac;

/**
 * 加密的数据
 */
@property (nonatomic, strong, readonly) NSData *encryptedData;

/**
 * 创建AES加密消息体
 * 
 * @param iv 初始化向量
 * @param hmac 消息认证码
 * @param encryptedData 加密数据
 * @return AES加密消息体实例
 */
+ (instancetype)bodyWithIV:(NSData *)iv hmac:(NSData *)hmac encryptedData:(NSData *)encryptedData;

/**
 * 将加密消息体序列化为NSData
 * 格式: [IV Length][IV][HMAC Length][HMAC][Encrypted Length][Encrypted Data]
 * 
 * @return 序列化后的数据
 */
- (NSData *)toData;

/**
 * 计算消息体的总长度
 * 
 * @return 消息体长度（字节）
 */
- (uint32_t)totalLength;

@end

/**
 * ZIM AES加密工具类
 * 
 * 负责处理AES-256-CBC加密和HMAC-SHA256认证
 */
@interface ZIMAESEncryption : NSObject

/**
 * 标准AES IV长度（字节）
 */
@property (class, readonly) NSUInteger standardIVLength;

/**
 * 标准HMAC长度（字节）
 */
@property (class, readonly) NSUInteger standardHMACLength;

/**
 * 使用AES-256-CBC加密数据
 * 
 * @param plainData 待加密的明文数据
 * @param key AES密钥 (32字节)
 * @param iv 初始化向量 (16字节)
 * @return 加密后的数据，失败返回nil
 */
+ (nullable NSData *)encryptData:(NSData *)plainData withKey:(NSData *)key iv:(NSData *)iv;

/**
 * 使用AES-256-CBC解密数据
 * 
 * @param encryptedData 待解密的数据
 * @param key AES密钥 (32字节)
 * @param iv 初始化向量 (16字节)
 * @return 解密后的明文数据，失败返回nil
 */
+ (nullable NSData *)decryptData:(NSData *)encryptedData withKey:(NSData *)key iv:(NSData *)iv;

/**
 * 计算HMAC-SHA256
 * 
 * @param data 待计算HMAC的数据
 * @param key HMAC密钥
 * @return HMAC值，失败返回nil
 */
+ (nullable NSData *)hmacSHA256:(NSData *)data withKey:(NSData *)key;

/**
 * 生成随机IV
 * 
 * @param length IV长度，通常为16字节
 * @return 随机生成的IV数据
 */
+ (NSData *)generateRandomIV:(NSUInteger)length;

/**
 * 验证HMAC
 * 
 * @param data 原始数据
 * @param expectedHMAC 期望的HMAC值
 * @param key HMAC密钥
 * @return YES表示验证通过，NO表示验证失败
 */
+ (BOOL)verifyHMAC:(NSData *)data expectedHMAC:(NSData *)expectedHMAC withKey:(NSData *)key;

@end

NS_ASSUME_NONNULL_END
