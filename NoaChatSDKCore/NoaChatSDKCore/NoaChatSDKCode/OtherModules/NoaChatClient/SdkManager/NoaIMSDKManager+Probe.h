//
//  NoaIMSDKManager+Probe.h
//  NoaChatSDKCore
//
//  ECDH连通性探测（仅握手，不鉴权、不心跳）
//

#import "NoaIMSDKManager.h"
#define kDefaultRaceTimeOut 10.0
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LingIMSDKManagerProbeECDHConnectStatus) {
    LingIMSDKManagerProbeECDHConnectSuccess,
    LingIMSDKManagerProbeECDHExChangeKeyFail,
    LingIMSDKManagerProbeECDHConnectServerFail,
    LingIMSDKManagerProbeECDHConnectTimeout,
};

@interface NoaIMSDKManager (Probe)

/// 通过执行一次 ECDH 密钥交换来探测 host:port 是否可用
/// 仅用于连通性判定：成功握手即视为连通；不进行鉴权/心跳，也不污染全局密钥
/// - Parameters:
///   - host: 域名或IP
///   - port: 端口
///   - timeout: 超时时间（秒）
///   - type: ECDH探测类型: 0 - 竞速 1-网络探测
///   - completion: 回调（主线程）
- (void)probeECDHConnectivityWithHost:(NSString *)host
                                  port:(uint16_t)port
                               timeout:(NSTimeInterval)timeout
                                 type:(NSInteger)type
                            completion:(void(^)(BOOL success, LingIMSDKManagerProbeECDHConnectStatus status))completion;

@end

NS_ASSUME_NONNULL_END

