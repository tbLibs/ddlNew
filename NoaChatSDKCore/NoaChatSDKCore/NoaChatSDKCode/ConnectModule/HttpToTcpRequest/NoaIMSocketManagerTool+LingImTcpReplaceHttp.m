//
//  NoaIMSocketManagerTool+LingImTcpReplaceHttp.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/8/25.
//

#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"

// 长连接工具单例
#import "NoaIMSocketManager.h"
#import "NoaIMSocketManagerTool.h"



// 创建分类属性
#import <objc/runtime.h>

// 宏定义
#import "LingIMMacorHeader.h"

// 头文件
#import "NoaIMSDKManager.h"

// http接口宏定义相关
#import "NoaIMHttpManager.h"

#import "NoaLocalLogger.h"

#define kMessageTimeOut 15

@implementation NoaIMSocketManagerTool (LingImTcpReplaceHttp)

/// MARK: 懒加载
- (void)setIsTokenExpired:(BOOL)isTokenExpired {
    objc_setAssociatedObject(self, @selector(isTokenExpired), @(isTokenExpired), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isTokenExpired {
    return [objc_getAssociatedObject(self, @selector(isTokenExpired)) boolValue];
}

- (void)setIsTokenRefreshing:(BOOL)isTokenRefreshing {
    objc_setAssociatedObject(self, @selector(isTokenRefreshing), @(isTokenRefreshing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isTokenRefreshing {
    return [objc_getAssociatedObject(self, @selector(isTokenRefreshing)) boolValue];
}

- (void)setHasRetriedAuthAfterTokenRefresh:(BOOL)hasRetriedAuthAfterTokenRefresh {
    objc_setAssociatedObject(self, @selector(hasRetriedAuthAfterTokenRefresh), @(hasRetriedAuthAfterTokenRefresh), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)hasRetriedAuthAfterTokenRefresh {
    return [objc_getAssociatedObject(self, @selector(hasRetriedAuthAfterTokenRefresh)) boolValue];
}

- (void)setTokenRefreshTimeDate:(NSDate *)tokenRefreshTimeDate {
    objc_setAssociatedObject(self, @selector(tokenRefreshTimeDate), tokenRefreshTimeDate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)tokenRefreshTimeDate {
    return objc_getAssociatedObject(self, @selector(tokenRefreshTimeDate));
}

#pragma mark - 队列属性

- (dispatch_queue_t)tokenRefreshQueue {
    dispatch_queue_t queue = objc_getAssociatedObject(self, @selector(tokenRefreshQueue));
    if (!queue) {
        queue = dispatch_queue_create("com.lingim.tokenRefreshQueue", DISPATCH_QUEUE_SERIAL);
        [self setTokenRefreshQueue:queue];
    }
    return queue;
}

- (void)setTokenRefreshQueue:(dispatch_queue_t)tokenRefreshQueue {
    objc_setAssociatedObject(self, @selector(tokenRefreshQueue), tokenRefreshQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (dispatch_queue_t)tcpRequestQueue {
    dispatch_queue_t queue = objc_getAssociatedObject(self, @selector(tcpRequestQueue));
    if (!queue) {
        queue = dispatch_queue_create("com.lingim.tcpRequestQueue", DISPATCH_QUEUE_SERIAL);
        [self setTcpRequestQueue:queue];
    }
    return queue;
}

- (void)setTcpRequestQueue:(dispatch_queue_t)tcpRequestQueue {
    objc_setAssociatedObject(self, @selector(tcpRequestQueue), tcpRequestQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (dispatch_queue_t)waitSendQueue {
    dispatch_queue_t queue = objc_getAssociatedObject(self, @selector(waitSendQueue));
    if (!queue) {
        queue = dispatch_queue_create("com.lingim.waitSendQueue", DISPATCH_QUEUE_SERIAL);
        [self setWaitSendQueue:queue];
    }
    return queue;
}

- (void)setWaitSendQueue:(dispatch_queue_t)waitSendQueue {
    objc_setAssociatedObject(self, @selector(waitSendQueue), waitSendQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<LingIMTcpRequestModel *> *)waitSendRequestModelArr {
    NSMutableArray *arr = objc_getAssociatedObject(self, @selector(waitSendRequestModelArr));
    if (!arr) {
        arr = [NSMutableArray array];
        [self setWaitSendRequestModelArr:arr];
    }
    return arr;
}

- (void)setWaitSendRequestModelArr:(NSMutableArray<LingIMTcpRequestModel *> *)waitSendRequestModelArr {
    objc_setAssociatedObject(self, @selector(waitSendRequestModelArr), waitSendRequestModelArr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 消息发送队列管理属性

- (dispatch_queue_t)messageSendQueue {
    dispatch_queue_t queue = objc_getAssociatedObject(self, @selector(messageSendQueue));
    if (!queue) {
        queue = dispatch_queue_create("com.lingim.messageSendQueue", DISPATCH_QUEUE_SERIAL);
        [self setMessageSendQueue:queue];
    }
    return queue;
}

- (void)setMessageSendQueue:(dispatch_queue_t)messageSendQueue {
    objc_setAssociatedObject(self, @selector(messageSendQueue), messageSendQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray<LingIMTcpRequestModel *> *)pendingSendQueue {
    NSMutableArray *arr = objc_getAssociatedObject(self, @selector(pendingSendQueue));
    if (!arr) {
        arr = [NSMutableArray array];
        [self setPendingSendQueue:arr];
    }
    return arr;
}

- (void)setPendingSendQueue:(NSMutableArray<LingIMTcpRequestModel *> *)pendingSendQueue {
    objc_setAssociatedObject(self, @selector(pendingSendQueue), pendingSendQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDate *)lastSendTime {
    NSDate *date = objc_getAssociatedObject(self, @selector(lastSendTime));
    if (!date) {
        date = [NSDate dateWithTimeIntervalSince1970:0];
        [self setLastSendTime:date];
    }
    return date;
}

- (void)setLastSendTime:(NSDate *)lastSendTime {
    objc_setAssociatedObject(self, @selector(lastSendTime), lastSendTime, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isSending {
    return [objc_getAssociatedObject(self, @selector(isSending)) boolValue];
}

- (void)setIsSending:(BOOL)isSending {
    objc_setAssociatedObject(self, @selector(isSending), @(isSending), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/// MARK: socket消息处理相关
/// 发送消息
/// - Parameter requestModel: LingIMTcpRequestModel消息处理对象
- (void)sendSocketMessageWithRequestModel:(LingIMTcpRequestModel *)requestModel {
    // 1) 心跳 & 鉴权：直接发送，绕过调度（避免被阻塞）
    IMMessage *sendMessage = (IMMessage *)requestModel.sendMessage;
    if (sendMessage.dataType == IMMessage_DataType_ImpingMessage ||
        sendMessage.dataType == IMMessage_DataType_ImauthMessage) {
        return;
    }
    
    //调度消息
    [self enqueueTcpRequest:requestModel];
}

/// 消息调度
/// - Parameter requestModel: http转tcp请求模型
- (void)enqueueTcpRequest:(LingIMTcpRequestModel *)requestModel {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.tcpRequestQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) {
            return;
        }
        
        BOOL isRefreshTokenRequest = [requestModel.url isEqualToString:Auth_Refresh_Token_Url];
        BOOL transportReady = SOCKETMANAGER.gcdSocket.isConnected && [self isExchangeEcdhKeySuccess];
        BOOL requestChannelReady = isRefreshTokenRequest ? transportReady : [self socketConnectStatus];
        if (!requestChannelReady || ![self isExchangeEcdhKeySuccess]) {
            // socket连接没有成功不要发请求，否则会失败
            // 密钥交换不成功也不要发请求，否则会无法解密
            dispatch_async(self.waitSendQueue, ^{
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
            
                if ([requestModel.url isEqualToString:Auth_Refresh_Token_Url]) {
                    // token要第一条发送
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 当前socket未连接，当前是token请求请求进入 waitSendRequestModelArr：%@", requestModel.url]];
                    [self.waitSendRequestModelArr insertObject:requestModel atIndex:0];
                }else {
                    if (![self socketConnectStatus]) {
                        //  tcp没有连接，任何请求都需要缓存起来等待发送
                        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 未连接，请求进入 waitSendRequestModelArr：%@", requestModel.url]];
                    }else if (![self isExchangeEcdhKeySuccess]) {
                        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] ecdh交换还未成功，请求进入 waitSendRequestModelArr：%@", requestModel.url]];
                    }
                    [self.waitSendRequestModelArr addObject:requestModel];
                }
            });
            return;
        }
        
        if (self.isTokenExpired || self.isTokenRefreshing) {
            NSString *tokenAction = [requestModel.url isEqualToString:Auth_Refresh_Token_Url] ? @"direct_send_refresh" : @"cache_request";
            [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=TOKEN_REFRESH_TRIGGER_CHECK url=%@ isTokenExpired=%@ isTokenRefreshing=%@ action=%@",
                                  requestModel.url,
                                  self.isTokenExpired ? @"YES" : @"NO",
                                  self.isTokenRefreshing ? @"YES" : @"NO",
                                  tokenAction]];
            
            if ([requestModel.url isEqualToString:Auth_Refresh_Token_Url]) {
               // token要立即发送，不然请求token的协议不会发送
                [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 当前socket已连接，刷新Token中/Token失效，当前请求是获取token，直接发送：%@", requestModel.url]];
                [self executeTcpRequest:requestModel];
            }else {
                // 如果token过期时，请求的是刷新token，就不要将其添加在缓存中
                dispatch_async(self.waitSendQueue, ^{
                    __strong typeof(weakSelf) self = weakSelf;
                    if (!self) return;
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 当前socket已连接，刷新Token中/Token失效，请求进入 pending：%@", requestModel.url]];
                    [self.waitSendRequestModelArr addObject:requestModel];
                });
            }
            
            if (self.isTokenExpired && !self.isTokenRefreshing) {
                // 当前token过期，且没有请求token信息时，需要刷新token信息
                [NoaLocalLogger info:@"[AUTH链路] stage=TOKEN_REFRESH_TRIGGER_CHECK action=start_refresh"];
                [self handleTokenExpiration];
            }
            return;
        }
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 当前socket已连接，Token有效，请求直接发送：%@", requestModel.url]];
        [self executeTcpRequest:requestModel];
    });
}

- (void)executeTcpRequest:(LingIMTcpRequestModel *)requestModel {
    IMMessage *message = requestModel.sendMessage;
    //发送消息
    [SOCKETMANAGER sendSocketMessage:message timeOut:kMessageTimeOut tag:LingIMMessageTag];
    
    // 发送后延时20ms，避免请求发送过快
    CIMLog(@"[TCP请求追踪] 发送完成，延时20ms - requestId:%@, url:%@", requestModel.msgId, requestModel.url);
//    [NSThread sleepForTimeInterval:0.4]; // 20ms延时
}

/// 在 Token 已过期且当前没有刷新任务时，串行发起 Token 刷新并恢复缓存请求。
- (void)handleTokenExpiration {
    if (self.isTokenRefreshing) {
        [NoaLocalLogger info:@"[AUTH链路] stage=TOKEN_REFRESH_SKIPPED reason=refresh_in_progress"];
        return;
    }
    // 在进入串行队列前先占用刷新状态，防止多个业务请求同时排入重复刷新任务。
    self.isTokenRefreshing = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.tokenRefreshQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [NoaLocalLogger info:@"[短连接转长连接] 当前无请求Token刷新队列，创建"];
        [NoaLocalLogger info:@"[AUTH链路] stage=TOKEN_REFRESH_START"];
        
        [self authRefreshTokenExpiredWithSuccessFunc:^(id data, NSString *traceId) {
            
            self.isTokenRefreshing = NO;
            self.isTokenExpired = NO;
            
            // 记录token刷新成功的时间戳
            self.tokenRefreshTimeDate = [NSDate date];
            
            [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] Token刷新成功，记录刷新时间戳：%@，同时将之前缓存的数据全部重新发送", self.tokenRefreshTimeDate]];
            
        } FailureFunc:^(NSInteger code, NSString *msg, NSString *traceId) {
            
            // token请求失败，就退出登录页面了，所以置为NO也是无问题的
            self.isTokenRefreshing = NO;
            self.isTokenExpired = NO;
            [NoaLocalLogger error:@"[短连接转长连接] Token刷新失败"];
            [NoaLocalLogger error:[NSString stringWithFormat:@"[AUTH链路] stage=TOKEN_REFRESH_FAILURE code=%ld traceId=%@",
                                   (long)code,
                                   traceId ?: @""]];
            [self releaseAllCacheRequest];
            [self finishAuthWithLogoutCode:code message:msg.length > 0 ? msg : @"Token刷新失败，请重新登录"];
            
        }];
    });
}

/// 将连接成功之前的消息发送出去
- (void)sendAllCacheRequest {
    // ⚠️ 用 sync：用于读（立刻需要结果，保证原子性）。
    __block NSArray *requestModelArr = nil;
    
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.waitSendQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
    
        requestModelArr = [self.waitSendRequestModelArr copy];
        [self.waitSendRequestModelArr removeAllObjects];
    });
    [NoaLocalLogger info:@"[短连接转长连接] socket连接成功、也可能是token刷新成功"];
    for (LingIMTcpRequestModel *requestModel in requestModelArr) {
        [NoaLocalLogger info:@"[短连接转长连接] 将requestModel中的token信息进行更新"];
        [requestModel refreshToken];
        [NoaLocalLogger info:@"[短连接转长连接] 重新发送之前所有缓存的requestModel"];
        [self enqueueTcpRequest:requestModel];
    }
}

/// 退出账号后，将之前缓存的消息清除
- (void)releaseAllCacheRequest {
    // 标记token已过期，避免影响重连之后的处理
    [NoaLocalLogger info:@"[短连接转长连接] 账号退出，清理请求与token状态"];
    
    if (self.isTokenExpired) {
        self.isTokenExpired = NO;
    }
    
    if (self.isTokenRefreshing) {
        self.isTokenRefreshing = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.waitSendQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.waitSendRequestModelArr enumerateObjectsUsingBlock:^(LingIMTcpRequestModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.failureCallBack) {
                obj.failureCallBack(999991, @"", @"");
            }
        }];

        [self.waitSendRequestModelArr removeAllObjects];
    });
}

/// MARK: 刷新token
/// 请求新 Token，成功后同步更新 Kit 与 SDK，并使用新 Token 再次发送 Socket AUTH。
/// @param successCallBack Token 刷新成功回调，返回新 Token 与 traceId。
/// @param failureCallBack Token 刷新失败回调，返回错误码、错误信息与 traceId。
- (void)authRefreshTokenExpiredWithSuccessFunc:(LingTcpRequestSuccessCallback)successCallBack
                                   FailureFunc:(LingIMTcpRequestFailureCallback)failureCallBack {
    NSString *token = IMSDKManager.myUserToken;
    NSString *myUserId = IMSDKManager.myUserID;
    if (!token || token.length == 0 || !myUserId || myUserId.length == 0) {
        [NoaLocalLogger error:@"[短连接转长连接] Token刷新终止，原因:token、userId异常"];
        if (failureCallBack) {
            failureCallBack(0, @"", @"");
        }
        return;
    }
    // 刷新token请求参数
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   IMSDKManager.myUserToken,@"token",
                                   IMSDKManager.myUserID,@"userUid",nil];
    
    [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Refresh_Token_Url Method:LingRequestPost SuccessFunc:^(id  _Nullable data, NSString * _Nullable traceId) {
        // 退出或切换账号/Token 后，旧刷新回调不能覆盖当前登录信息。
        if (!SOCKETMANAGER.isCanReconnect || ![IMSDKManager.myUserID isEqualToString:myUserId] ||
            ![IMSDKManager.myUserToken isEqualToString:token]) return;
        NSString *newToken = (NSString *)data;
        if(newToken.length == 0 || newToken == nil) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[AUTH链路] stage=TOKEN_REFRESH_EMPTY_RESULT traceId=%@",
                                   traceId ?: @""]];
            if ([self.userDelegate respondsToSelector:@selector(noaSdkRefreshUsetToken: errorMsg:)]) {
                [self.userDelegate noaSdkRefreshUsetToken:@"" errorMsg:nil];
            }
            [NoaLocalLogger error:@"[短连接转长连接] token更新完成，但是token为空，还是失败"];
            if (failureCallBack) {
                failureCallBack(0, @"", traceId);
            }
        }else {
            //更新Kit层token
            [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=TOKEN_REFRESH_SUCCESS traceId=%@ newTokenEmpty=NO newTokenLength=%lu",
                                  traceId ?: @"",
                                  (unsigned long)newToken.length]];
            [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] token更新完成，token长度：%lu", (unsigned long)newToken.length]];
            if ([self.userDelegate respondsToSelector:@selector(noaSdkRefreshUsetToken: errorMsg:)]) {
                [self.userDelegate noaSdkRefreshUsetToken:newToken errorMsg:@""];
            }
            
            //更新SDK层token
            NoaIMSDKUserOptions *userOption = [NoaIMSDKUserOptions new];
            userOption.userToken = newToken;
            userOption.userID = IMSDKManager.myUserID;
            userOption.userNickname = IMSDKManager.myUserNickname;
            userOption.userAvatar = IMSDKManager.myUserAvatar;
            [IMSDKManager configSDKUserWith:userOption];
            
            // configSDKUserWith 会同步更新 Socket 用户并触发一次 AUTH，此处禁止再次显式发送，避免双 AUTH。
            [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=TOKEN_UPDATED_REAUTH traceId=%@ newTokenLength=%lu action=config_triggers_single_auth",
                                  traceId ?: @"",
                                  (unsigned long)newToken.length]];
            
            if (successCallBack) {
                successCallBack(newToken, traceId);
            }
        }
    } FailureFunc:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        if (!SOCKETMANAGER.isCanReconnect || ![IMSDKManager.myUserID isEqualToString:myUserId] ||
            ![IMSDKManager.myUserToken isEqualToString:token]) return;
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接]  token更新失败，code = %ld, msg = %@. traceId = %@", code, msg, traceId]];
        if ([self.userDelegate respondsToSelector:@selector(noaSdkRefreshUsetToken: errorMsg:)]) {
            [self.userDelegate noaSdkRefreshUsetToken:@"" errorMsg:msg];
        }
        
        if (failureCallBack) {
            failureCallBack(code, msg, traceId);
        }
        
        //账号封禁、设备封禁、IP封禁
        if (code == Auth_User_Account_Banned || code == Auth_User_Device_Banned || code == Auth_User_IPAddress_Banned) {
            if ([self.userDelegate respondsToSelector:@selector(noaSdkRefreshTokenAuthBanned:)]) {
                [self.userDelegate noaSdkRefreshTokenAuthBanned:code];
            }
            return;
        }
        
       
    }];
}

/// sock连接成功
- (BOOL)socketConnectStatus {
    return SOCKETMANAGER.currentSocketConnectStatus;
}

/// ecdh密钥交换成功
- (BOOL)isExchangeEcdhKeySuccess {
    return SOCKETMANAGER.isExchangeEcdhKeySuccess;
}

- (void)messageTimeOutWithRequestModel:(LingIMTcpRequestModel *)requestModel {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.waitSendQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
    
        [self.waitSendRequestModelArr removeObject:requestModel];
    });
}

#pragma mark - 时间戳比较方法

/// 比较传入的时间戳是否晚于token刷新时间
- (void)isNeedRefreshToken:(NSDate *)timestamp {
    if (!self.isTokenExpired) {
        // 当前已经记录过期了
        return;
    }
    
    if (!self.isTokenRefreshing) {
        // 当前正在刷新token
        return;
    }
    
    if (!timestamp) {
        // 传入的时间戳为空
        return;
    }
    
    if (!self.tokenRefreshTimeDate) {
        // 如果token刷新时间为空，表明之前没有刷新过，需要刷新
        self.isTokenExpired = YES;
        return;
    }
    
    if ([timestamp compare:self.tokenRefreshTimeDate] == NSOrderedDescending) {
        // 比较时间戳：传入时间戳 > token刷新时间,说明本次消息发送的时间，在上次刷新token时间之后，标记需要刷新
        self.isTokenExpired = YES;
    }
}

@end
