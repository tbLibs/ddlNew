//
//  NoaIMSocketManager.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/22.
//

// Socket封装
//长连接封装
#define SOCKETMANAGER [NoaIMSocketManager sharedTool]

#define LingIMMessageTag        1         //消息标签
#define LingIMHeartTag          6868      //心跳标签
#define LingIMHeartInterval     30        //心跳间隔
#define LingIMHeartFailureCount 5         //心跳失败次数(未收到pong次数)
#define LingIMReconnectPow      2         //2的n次方 重连时间间隔0 2 4 8 16...，2的n次方，从第5次开始，时间间隔固定为16
#define LingIMConnectTimeout    60        //长连接超时时间
#define LingIMMessageTimeout    3        //消息发送超时时间/消息重发时间间隔

#import <Foundation/Foundation.h>
#import "NoaIMSocketHostOptions.h"//网关配置信息
#import "NoaIMSocketUserOptions.h"//用户配置信息
#import "LingImmessage.pbobjc.h"//消息体
#import <GCDAsyncSocket.h>//长连接

NS_ASSUME_NONNULL_BEGIN
/// 检查是否有最优节点可用
typedef BOOL(^HasOptimalServerAvailableBlock)(void);

/// 获取最优服务器节点
typedef NSDictionary * _Nullable(^GetOptimalServerInfoBlock)(void);

/// 重连竞速只返回节点和稳定的失败原因码；无可用节点返回 nil、0、failureReason。
typedef void (^NoaTcpRaceCompletion)(NSString * _Nullable host, NSInteger port, NSString * _Nullable failureReason);

@interface NoaIMSocketManager : NSObject

#pragma mark - <<<<<<单例>>>>>>
+ (instancetype)sharedTool;

/// 套接字对象
@property (nonatomic, strong, readonly) GCDAsyncSocket *gcdSocket;

#pragma mark - <<<<<<业务>>>>>>
/// 配置/更新socket用户信息
/// - Parameter userOptions: 用户信息
- (void)configureSocketUser:(NoaIMSocketUserOptions *)userOptions;

#pragma mark - 配置socket网关信息
/// 配置/更新socket网关信息
/// - Parameter hostOptions: 网关信息
- (void)configureSocketHost:(NoaIMSocketHostOptions *)hostOptions;

/// 停止上一轮初始化并隔离旧 Socket 的断开回调。
- (void)prepareForConnectionInitialization;

/// 初始化尚未选出节点时也能启动自动重连；断网后等待网络恢复。
- (void)resumeInitializationReconnectWithOrgName:(NSString *)orgName;
/// 仅加入企业使用有限重试；0 恢复默认无限重连。回调在主线程执行。
- (void)setInitializationReconnectLimit:(NSUInteger)limit failureHandler:(nullable void (^)(NSString *reason))failureHandler;
- (void)resumeInitializationReconnectWithOrgName:(NSString *)orgName failureReason:(nullable NSString *)reason;

/// 开始连接
-(void)startSocketConnect;

/// 开始一次登录前初始化链路记录；仅在最终失败时将已记录步骤上报到 Sentry。
- (void)beginInitializationSentryTrace;

/// 记录初始化链路的一个阶段；result 为 nil 表示阶段开始，YES/NO 分别表示通过/未通过。
- (void)recordInitializationSentryStage:(NSString *)stage
                                 result:(nullable NSNumber *)result
                                 reason:(nullable NSString *)reason;

/// 以指定失败阶段终结本次初始化链路；App 侧会在全部竞速链路失败后统一决定是否上报。
- (void)captureInitializationSentryFailureAtStage:(NSString *)stage
                                            reason:(NSString *)reason
                                         errorCode:(NSString *)errorCode;

/// 标记初始化链路成功并丢弃内存中的步骤，不产生 Sentry 事件。
- (void)completeInitializationSentryTrace;

/// 断开socket连接
- (void)disconnectSocket;

/// 重连socket
- (void)startingSocketReconnect;
/// 回前台刷新网络状态，并在原连接上用 Ping/Pong 验证存活，5 秒无响应则重连。
- (void)verifyConnectionOnForeground;
/// 再次进入后台时取消前台探测，避免挂起后旧超时任务误断开连接。
- (void)cancelForegroundConnectionProbe;
/// 只接受本次前台探测对应的 Pong。
- (void)completeForegroundConnectionProbeWithMessageID:(NSString *)messageID;
/// 保留登录信息，因可恢复的 AUTH 错误断开并持续重试。
- (void)retryConnectionAfterAuthFailure:(NSInteger)code;

/// 当前socket连接状态
- (BOOL)currentSocketConnectStatus;

/// 是否交换ecdh key成功
- (BOOL)isExchangeEcdhKeySuccess;

/// 鉴权socket用户
- (void)authSocketUser;

/// 收到 AUTH 回执后结束本次等待，避免 10 秒超时任务继续生效。
- (void)completePendingAuthRequest;

/// 终止当前 AUTH 阶段并使所有已派发的 AUTH 超时任务失效。
- (void)cancelAuthPhase;

/// AUTH 成功后将连接提升为业务可用状态，并恢复连接成功后的业务流程。
- (void)finishAuthPhaseSuccessfully;

/// 恢复是否是重连reConnect状态为初始状态
- (void)configSetIsReconenctStatus;

/// 发送socket消息
/// - Parameter message: 消息体
/// - Parameter messageTag: 消息标签
- (void)sendSocketMessage:(id)message tag:(NSInteger)messageTag;

/// 发送socket消息
/// - Parameters:
///   - message: 消息体
///   - timeOut:· 超时时间，单位秒
///   - messageTag: 消息标签
- (void)sendSocketMessage:(id)message
                  timeOut:(NSInteger)timeOut
                      tag:(NSInteger)messageTag;

/// 开始心跳机制(用户鉴权成功后开始)
- (void)startSocketHeartbeat;

/// 重置未收到Pong响应次数
- (void)resetSocketHeartNoPongCount;

/// socket的用户id
- (NSString *)socketUserID;

/// socket的用户token
- (NSString *)socketUserToken;

/// socket 主机 地址
- (NSString *)socketHostValue;

/// socket 主机 端口
- (NSInteger)socketPortValue;

/// 清空用户信息
- (void)clearUserInfo;

/// 清理接收缓冲区
- (void)cleanupReceiveBuffers;

@property (nonatomic, copy) HasOptimalServerAvailableBlock hasOptimalServerAvailableBlock;

@property (nonatomic, copy) GetOptimalServerInfoBlock getOptimalServerInfoBlock;

/// 异步重新探测 TCP 节点，由 SocketManager 统一连接。
@property (nonatomic, copy, nullable) void (^raceTcpNodeBlock)(NoaTcpRaceCompletion completion);
/// 取消业务层本轮竞速，丢弃尚未返回的结果。
@property (nonatomic, copy, nullable) dispatch_block_t cancelTcpNodeRaceBlock;

/// 是否能够重新连接
@property (nonatomic, assign) BOOL isCanReconnect;

/// 当前是否处于 ECDH 完成、AUTH 尚未得到最终结果的阶段。
@property (nonatomic, assign, readonly) BOOL isAuthPhaseActive;

@end

NS_ASSUME_NONNULL_END
