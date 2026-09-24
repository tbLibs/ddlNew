//
//  NoaIMSocketManagerTool+LingImTcpReplaceHttp.h
//  NoaChatSDKCore
//
//  Created by phl on 2025/8/25.
//

#import "NoaIMSocketManagerTool.h"

// 短连接转长连接发送数据类
#import "LingIMTcpRequestModel.h"

NS_ASSUME_NONNULL_BEGIN

@class LingIMTcpRequestModel;
@interface NoaIMSocketManagerTool (LingImTcpReplaceHttp)

/// token是否过期（默认没有过期）
@property (nonatomic, assign) BOOL isTokenExpired;

/// MARK: 请求的队列
/// 专用串行队列：刷新token队列
@property (nonatomic, strong) dispatch_queue_t tokenRefreshQueue;

/// 专用串行队列：tcp网络请求队列
@property (nonatomic, strong) dispatch_queue_t tcpRequestQueue;

/// 专用串行队列：缓存待发送请求
@property (nonatomic, strong) dispatch_queue_t waitSendQueue;

/// MARK: Token相关
/// 是否正在刷新token
@property (nonatomic, assign) BOOL isTokenRefreshing;

/// 当前连接的 AUTH 阶段是否已经使用过一次 Token 刷新机会。
@property (nonatomic, assign) BOOL hasRetriedAuthAfterTokenRefresh;

/// Token刷新成功的时间戳
@property (nonatomic, strong) NSDate *tokenRefreshTimeDate;

/// 缓存requestModel的数组，避免request请求后，requestModel被立即释放
@property (nonatomic, strong) NSMutableArray <LingIMTcpRequestModel *>*waitSendRequestModelArr;

/// 发送socket消息
- (void)sendSocketMessageWithRequestModel:(LingIMTcpRequestModel *)requestModel;

/// 发送socket消息超时，从队列中移除相关消息缓存
- (void)messageTimeOutWithRequestModel:(LingIMTcpRequestModel *)requestModel;

/// 将连接成功之前的消息发送出去
- (void)sendAllCacheRequest;

/// 退出账号后，将之前缓存的消息清除
- (void)releaseAllCacheRequest;

/// 刷新token
- (void)authRefreshTokenExpiredWithSuccessFunc:(nullable LingTcpRequestSuccessCallback)successCallBack
                                   FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureCallBack;

/// AUTH 返回 Token 失效时发起唯一一次刷新；刷新失败会直接结束登录态。
- (void)handleTokenExpiration;

/// 比较传入的时间戳是否晚于token刷新时间
/// @param timestamp 要比较的时间戳，如果时间戳 > 上次更新token的时间戳，需要刷新
- (void)isNeedRefreshToken:(NSDate *)timestamp;

@end

NS_ASSUME_NONNULL_END
