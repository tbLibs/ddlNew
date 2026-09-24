//
//  ECDHClientProtocolHandler.h
//  NoaChatSDKCore
//
//  客户端 ECDH 协议处理器
//  对应服务端 ECDHProtocolHandler.java 的客户端实现
//  负责处理 ECDH 密钥交换的协议层逻辑
//  Created by IM Team
//

#import <Foundation/Foundation.h>
#import "ECDHKeyManager.h"

NS_ASSUME_NONNULL_BEGIN

@class ECDHClientProtocolHandler;

/**
 * ECDH 协议处理器代理
 */
@protocol ECDHClientProtocolHandlerDelegate <NSObject>

@optional
/**
 * ECDH 密钥交换成功
 * @param handler 协议处理器
 * @param sharedSecret 共享密钥
 * @param sessionKey 派生的会话密钥
 */
- (void)ecdhProtocolHandler:(ECDHClientProtocolHandler *)handler 
        keyExchangeSucceeded:(NSData *)sharedSecret 
                  sessionKey:(NSData *)sessionKey;

/**
 * ECDH 密钥交换失败
 * @param handler 协议处理器
 * @param error 错误信息
 */
- (void)ecdhProtocolHandler:(ECDHClientProtocolHandler *)handler 
           keyExchangeFailed:(NSError *)error;

/**
 * ECDH 协议状态更新
 * @param handler 协议处理器
 * @param status 状态描述
 */
- (void)ecdhProtocolHandler:(ECDHClientProtocolHandler *)handler 
              statusUpdated:(NSString *)status;

@end

/**
 * 客户端 ECDH 协议处理器
 * 对应服务端 ECDHProtocolHandler.java
 * 支持与服务端的 ECDH 密钥交换协议交互
 */
@interface ECDHClientProtocolHandler : NSObject

/// 代理对象
@property (nonatomic, weak) id<ECDHClientProtocolHandlerDelegate> delegate;

/// 当前客户端公钥
@property (nonatomic, readonly, nullable) SecKeyRef clientPublicKey;

/// 当前客户端私钥
@property (nonatomic, readonly, nullable) SecKeyRef clientPrivateKey;

/// 共享密钥
@property (nonatomic, readonly, nullable) NSData *sharedSecret;

/// 会话密钥
@property (nonatomic, readonly, nullable) NSData *sessionKey;

/// ECDH 是否已完成
@property (nonatomic, readonly) BOOL isKeyExchangeCompleted;

/**
 * 初始化协议处理器
 * @param delegate 代理对象
 * @return 协议处理器实例
 */
- (instancetype)initWithDelegate:(id<ECDHClientProtocolHandlerDelegate>)delegate;

/**
 * 启动 ECDH 密钥交换流程
 * 生成客户端密钥对并发送交换请求
 */
- (void)initiateKeyExchange;

/**
 * 处理服务端的 ECDH 响应数据
 * @param responseData 服务端响应的原始数据
 * @return 是否成功处理
 */
- (BOOL)handleServerResponse:(NSData *)responseData;

/**
 * 创建 ECDH 密钥交换请求数据
 * @return 请求数据，失败返回 nil
 */
- (NSData * _Nullable)createKeyExchangeRequest;

/**
 * 重置协议处理器状态
 * 清理密钥和会话数据
 */
- (void)reset;

/**
 * 派生指定上下文的会话密钥
 * @param context 派生上下文
 * @param length 密钥长度
 * @return 派生的密钥
 */
- (NSData * _Nullable)deriveSessionKeyWithContext:(NSString *)context length:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END
