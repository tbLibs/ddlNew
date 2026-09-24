//
//  ZIMKeyExchange.h
//  ZIM Client
//
//  Created by Connector Handler
//  Copyright © 2024 ZLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ECDH密钥交换结果
 */
@interface ZIMECDHKeyPair : NSObject

/**
 * 本地私钥
 */
@property (nonatomic, readonly) SecKeyRef privateKey;

/**
 * 本地公钥
 */
@property (nonatomic, readonly) SecKeyRef publicKey;

/**
 * 公钥的原始数据（用于网络传输）
 */
@property (nonatomic, strong, readonly) NSData *publicKeyData;

/**
 * 创建密钥对实例
 */
+ (nullable instancetype)keyPairWithPrivateKey:(SecKeyRef)privateKey
                                     publicKey:(SecKeyRef)publicKey
                                 publicKeyData:(NSData *)publicKeyData;

/**
 * 释放密钥资源
 */
- (void)cleanup;

@end

/**
 * ZIM ECDH密钥交换管理器
 *
 * 负责生成ECDH密钥对、计算共享密钥和派生AES密钥
 * 与服务端保持完全一致的算法实现
 */
@interface ZIMKeyExchange : NSObject

/**
 * ECDH曲线类型（secp256r1）
 */
@property (class, readonly) NSString *curveType;

/**
 * AES密钥长度（32字节，AES-256）
 */
@property (class, readonly) NSUInteger aesKeyLength;

/**
 * 生成ECDH密钥对
 * 使用secp256r1曲线，与服务端保持一致
 *
 * @return ECDH密钥对，失败返回nil
 */
+ (nullable ZIMECDHKeyPair *)generateECDHKeyPair;

/**
 * 从数据重构公钥
 *
 * @param publicKeyData 公钥的原始数据
 * @return 公钥对象，失败返回nil
 */
+ (nullable SecKeyRef)reconstructPublicKeyFromData:(NSData *)publicKeyData;

/**
 * 计算ECDH共享密钥
 *
 * @param privateKey 本地私钥
 * @param remotePublicKeyData 远程公钥数据
 * @return 共享密钥，失败返回nil
 */
+ (nullable NSData *)computeSharedSecret:(SecKeyRef)privateKey
                      remotePublicKeyData:(NSData *)remotePublicKeyData;

/**
 * 从共享密钥派生AES密钥
 * 使用与服务端完全一致的算法：直接SHA-256
 *
 * @param sharedSecret ECDH共享密钥
 * @return AES-256密钥（32字节），失败返回nil
 */
+ (nullable NSData *)deriveAESKeyFromSharedSecret:(NSData *)sharedSecret;

/**
 * 完整的密钥交换流程（客户端侧）
 *
 * @param serverPublicKeyData 服务端公钥数据
 * @param key 客户端密钥
 * @return 派生的AES密钥，失败返回nil
 */
+ (nullable NSData *)performKeyExchange:(NSData *)serverPublicKeyData
                          clientKeyPair:(SecKeyRef)key;

/**
 * 验证公钥数据是否有效
 *
 * @param publicKeyData 公钥数据
 * @return YES表示有效，NO表示无效
 */
+ (BOOL)isValidPublicKeyData:(NSData *)publicKeyData;

/**
 * 将数据转换为十六进制字符串（用于调试）
 *
 * @param data 要转换的数据
 * @return 十六进制字符串
 */
+ (NSString *)dataToHexString:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
