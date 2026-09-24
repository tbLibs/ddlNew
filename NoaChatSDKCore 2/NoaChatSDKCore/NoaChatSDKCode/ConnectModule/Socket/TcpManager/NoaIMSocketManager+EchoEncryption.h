//
//  NoaIMSocketManager+EchoEncryption.h
//  NoaChatSDKCore
//
//  Created by phl on 2025/8/31.
//

#import "NoaIMSocketManager.h"
#import "ECDHClientProtocolHandler.h"
NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSocketManager (EchoEncryption) <ECDHClientProtocolHandlerDelegate>

/// ECDH 协议处理器
@property (nonatomic, strong) ECDHClientProtocolHandler *ecdhHandler;

/// ECDH 协商是否完成
@property (nonatomic, assign) BOOL isECDHCompleted;

/// 密钥交换进行中
@property (nonatomic, assign) BOOL isKeyExchangeInProgress;

/// 会话密钥
@property (nonatomic, strong, nullable) NSData *sessionKey;

/**
 * 启动 ECDH 密钥交换流程
 */
- (void)startECDHKeyExchange;

/**
 * 发送 ECDH 请求给服务端
 */
- (void)sendECDHRequest;

/**
 * ECDH 协商完成后的处理
 */
- (void)onECDHCompleted;

/**
 * 处理服务端的 ECDH 响应数据
 */
- (void)handleECDHServerResponse:(NSData *)responseData;

@end

NS_ASSUME_NONNULL_END
