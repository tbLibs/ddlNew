//
//  ECDHKeyManager.h
//  IM Client ECDH Implementation
//
//  对应服务端 EccKeyManager.java 的客户端实现
//  使用 P-256 (secp256r1) 椭圆曲线
//  Created by IM Team
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ECDH密钥管理器 - 客户端实现
 * 与服务端 EccKeyManager.java 保持兼容
 * 使用 secp256r1 (P-256) 椭圆曲线
 */
@interface ECDHKeyManager : NSObject

/**
 * 生成ECDH密钥对
 * 对应服务端的 generateKeyPair() 方法
 * 
 * @param completion 完成回调，返回公钥、私钥或错误信息
 */
+ (void)generateKeyPairWithCompletion:(void(^)(SecKeyRef _Nullable publicKey, 
                                              SecKeyRef _Nullable privateKey, 
                                              NSError * _Nullable error))completion;

/**
 * 同步生成ECDH密钥对
 * 
 * @param error 错误信息输出
 * @return 包含公钥和私钥的字典，失败返回nil
 */
+ (NSDictionary * _Nullable)generateKeyPairSyncWithError:(NSError **)error;

/**
 * 从字节数组重构公钥
 * 对应服务端的 reconstructPublicKey(byte[] publicKeyBytes) 方法
 * 
 * @param publicKeyBytes 公钥字节数组 (X.509 DER编码)
 * @param error 错误信息输出
 * @return 公钥引用
 */
+ (SecKeyRef _Nullable)reconstructPublicKeyFromBytes:(NSData *)publicKeyBytes error:(NSError **)error;

/**
 * 计算ECDH共享密钥
 * 对应服务端的 computeSharedSecret(PrivateKey privateKey, byte[] publicKeyBytes) 方法
 * 
 * @param privateKey 本地私钥
 * @param publicKeyBytes 远程公钥字节数组
 * @param error 错误信息输出
 * @return 共享密钥数据
 */
+ (NSData * _Nullable)computeSharedSecretWithPrivateKey:(SecKeyRef)privateKey 
                                         publicKeyBytes:(NSData *)publicKeyBytes 
                                                  error:(NSError **)error;

/**
 * 计算ECDH共享密钥
 * 对应服务端的 computeSharedSecret(PrivateKey privateKey, PublicKey publicKey) 方法
 * 
 * @param privateKey 本地私钥
 * @param publicKey 远程公钥
 * @param error 错误信息输出
 * @return 共享密钥数据
 */
+ (NSData * _Nullable)computeSharedSecretWithPrivateKey:(SecKeyRef)privateKey 
                                              publicKey:(SecKeyRef)publicKey 
                                                  error:(NSError **)error;

/**
 * 验证公钥是否有效
 * 对应服务端的 isValidPublicKey(byte[] publicKeyBytes) 方法
 * 
 * @param publicKeyBytes 公钥字节数组
 * @return YES表示有效，NO表示无效
 */
+ (BOOL)isValidPublicKey:(NSData *)publicKeyBytes;

/**
 * 获取公钥的X.509 DER编码字节数组
 * 用于与服务端交换公钥
 * 
 * @param publicKey 公钥引用
 * @param error 错误信息输出
 * @return X.509 DER编码的公钥数据
 */
+ (NSData * _Nullable)getPublicKeyBytes:(SecKeyRef)publicKey error:(NSError **)error;

/**
 * 获取私钥的X.509 DER编码字节数组
 * 用于与服务端公钥共享（对应Java的私钥编码格式）
 */
+ (NSData * _Nullable)getPrivateKeyBytes:(SecKeyRef)privateKey error:(NSError **)error;

/**
 * 验证密钥是否为secp256r1类型
 * 
 * @param key 要验证的密钥
 * @return YES表示是secp256r1密钥
 */
+ (BOOL)isSecp256r1Key:(SecKeyRef)key;

/**
 * 打印密钥详细信息（调试用）
 * 
 * @param key 密钥引用
 * @param label 标签
 */
+ (void)printKeyInfo:(SecKeyRef)key label:(NSString *)label;

/**
 * 将NSData转换为十六进制字符串
 * 
 * @param data 要转换的数据
 * @return 十六进制字符串
 */
+ (NSString *)hexStringFromData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
