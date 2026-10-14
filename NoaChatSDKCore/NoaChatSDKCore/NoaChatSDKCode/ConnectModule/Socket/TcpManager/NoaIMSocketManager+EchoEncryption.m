//
//  NoaIMSocketManager+EchoEncryption.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/8/31.
//

#import "NoaIMSocketManager+EchoEncryption.h"

// 宏header
#import "LingIMMacorHeader.h"

//
#import "NoaIMSocketManagerTool.h"

//
#import <objc/runtime.h>

static const NSTimeInterval kKeyExchangeTimeout = 20.0;

@implementation NoaIMSocketManager (EchoEncryption)

#pragma mark - ecdhHandler
- (void)setEcdhHandler:(ECDHClientProtocolHandler *)ecdhHandler {
    objc_setAssociatedObject(self, @selector(ecdhHandler), ecdhHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ECDHClientProtocolHandler *)ecdhHandler {
    return objc_getAssociatedObject(self, @selector(ecdhHandler));
}

#pragma mark - isECDHCompleted
- (void)setIsECDHCompleted:(BOOL)isECDHCompleted {
    objc_setAssociatedObject(self, @selector(isECDHCompleted), @(isECDHCompleted), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isECDHCompleted {
    return [objc_getAssociatedObject(self, @selector(isECDHCompleted)) boolValue];
}

#pragma mark - isKeyExchangeInProgress
- (void)setIsKeyExchangeInProgress:(BOOL)isKeyExchangeInProgress {
    objc_setAssociatedObject(self, @selector(isKeyExchangeInProgress), @(isKeyExchangeInProgress), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isKeyExchangeInProgress {
    return [objc_getAssociatedObject(self, @selector(isKeyExchangeInProgress)) boolValue];
}

#pragma mark - sessionKey
- (void)setSessionKey:(NSData *)sessionKey {
    objc_setAssociatedObject(self, @selector(sessionKey), sessionKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSData *)sessionKey {
    return objc_getAssociatedObject(self, @selector(sessionKey));
}

#pragma mark - ECDH 密钥交换

/**
 * 启动 ECDH 密钥交换流程
 */
- (void)startECDHKeyExchange {
    if (self.isECDHCompleted) {
        CIMLog(@"✅ [ECDH协商] ECDH密钥交换已完成，跳过");
        [self onECDHCompleted];
        return;
    }
    
    if (!self.ecdhHandler) {
        self.ecdhHandler = [[ECDHClientProtocolHandler alloc] initWithDelegate:self];
    }
    
    CIMLog(@"🚀 [ECDH协商] 启动ECDH密钥交换流程...");
    [self.ecdhHandler initiateKeyExchange];
}

/**
 * 发送 ECDH 请求给服务端
 */
- (void)sendECDHRequest {
    NSData *requestData = [self.ecdhHandler createKeyExchangeRequest];
    if (!requestData) {
        CIMLog(@"❌ [ECDH协商] 创建ECDH请求失败");
        return;
    }
    
    CIMLog(@"📤 [ECDH协商] 发送ECDH密钥交换请求，长度: %lu字节", (unsigned long)requestData.length);
    [self.gcdSocket writeData:requestData withTimeout:kKeyExchangeTimeout tag:100];
}

/**
 * ECDH 协商完成后的处理
 */
- (void)onECDHCompleted {
    CIMLog(@"🎉 [ECDH协商] ECDH密钥交换完成，开始用户鉴权");
    // ECDH 完成后，开始用户鉴权流程
    [self authSocketUser];
}

#pragma mark - ECDHClientProtocolHandlerDelegate

/**
 * ECDH 密钥交换成功
 */
- (void)ecdhProtocolHandler:(ECDHClientProtocolHandler *)handler
        keyExchangeSucceeded:(NSData *)sharedSecret
                  sessionKey:(NSData *)sessionKey {
    
    CIMLog(@"✅ [ECDH协商] ECDH密钥交换成功完成！");
    CIMLog(@"🔐 [ECDH协商] 共享密钥长度: %lu字节", (unsigned long)sharedSecret.length);
    CIMLog(@"🔑 [ECDH协商] 会话密钥长度: %lu字节", (unsigned long)sessionKey.length);
    
    self.isECDHCompleted = YES;
    self.sessionKey = sessionKey;
    
    // 通知上层 ECDH 完成
    [SOCKETMANAGERTOOL ecdhKeyExchangeCompleted:sessionKey];
    
    // 继续后续流程
    [self onECDHCompleted];
}

/**
 * ECDH 密钥交换失败
 */
/// 诊断只保留请求阶段、消息身份、长度和错误码，不输出资源URL、原始错误或认证数据。
- (void)ecdhProtocolHandler:(ECDHClientProtocolHandler *)handler
           keyExchangeFailed:(NSError *)error {
    
    CIMLog(@"❌ [ECDH协商] ECDH密钥交换失败 domain=%@ code=%ld", error.domain, (long)error.code);
    
    // 通知上层 ECDH 失败
    [SOCKETMANAGERTOOL ecdhKeyExchangeFailed:error];
    
    // 可以选择重试或者降级处理
    // 这里暂时继续用户鉴权流程
    [self onECDHCompleted];
}

/**
 * ECDH 协议状态更新
 */
/// 诊断只保留请求阶段、消息身份、长度和错误码，不输出资源URL、原始错误或认证数据。
- (void)ecdhProtocolHandler:(ECDHClientProtocolHandler *)handler
              statusUpdated:(NSString *)status {
    
    CIMLog(@"ℹ️ [ECDH协商] stage=ECDH_STATUS length=%lu", (unsigned long)status.length);
    
    // 如果状态是密钥对生成完成，发送请求
    if ([status containsString:@"准备发送交换请求"]) {
        [self sendECDHRequest];
    }
}

/**
 * 处理服务端的 ECDH 响应数据
 */
- (void)handleECDHServerResponse:(NSData *)responseData {
    CIMLog(@"📥 [ECDH协商] 收到服务端ECDH响应，长度: %lu字节", (unsigned long)responseData.length);
    
    BOOL success = [self.ecdhHandler handleServerResponse:responseData];
    if (!success) {
        CIMLog(@"❌ [ECDH协商] 处理服务端ECDH响应失败");
    }
}

/**
 * 重置 ECDH 状态
 */
- (void)resetECDHState {
    CIMLog(@"🔄 [ECDH协商] 重置ECDH状态");
    
    self.isECDHCompleted = NO;
    self.sessionKey = nil;
    
    if (self.ecdhHandler) {
        [self.ecdhHandler reset];
    }
}

@end
