//
//  NoaIMSocketManager.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/22.
//

#import "NoaIMSocketManager.h"
#import "LingIMMacorHeader.h"//宏header
#import "FCUUID.h"//获取设备唯一标识
#import "NoaIMManagerTool.h"//工具
#import "NoaIMSocketManagerTool.h"//消息处理工具类
#import "NoaIMDeviceTool.h"
#import <NetworkStatus/NetworkStatus-Swift.h>
#import "NovDecryptorManager.h"
#import "NoaLocalLogger.h"
#import "NoaIMSDKManager.h"
#import <QuartzCore/QuartzCore.h>

// echo 加密
#import "NoaIMSocketManager+EchoEncryption.h"
//
#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"

typedef NS_ENUM(NSInteger, LingIMSocketConnectState) {
    LingIMSocketConnectStateDisconnected,   // 未连接
    LingIMSocketConnectStateConnecting,     // 正在连接
    LingIMSocketConnectStateConnected       // 已连接
};

#define kEncryptionEnabled 1

// Socket日志开关 - 控制本文件中所有CIMLog输出
// Debug模式：可以设置开关，默认开启
// Release模式：强制关闭
#ifdef DEBUG
#define SOCKET_LOG_SWITCH 0
#else
#define SOCKET_LOG_SWITCH 0  // Release模式强制关闭
#endif

// 重定义CIMLog宏，根据开关控制是否输出
#if SOCKET_LOG_SWITCH
// 开关开启时，使用NSLog输出并添加Socket前缀
#undef CIMLog
#define CIMLog(fmt, ...) NSLog(@"[Socket] " fmt, ##__VA_ARGS__)
#else
// 开关关闭时，CIMLog为空操作
#undef CIMLog
#define CIMLog(fmt, ...)
#endif

/// 连接后多久发送第一个协议
static const NSTimeInterval kInitialDelayAfterConnect = 0.1;
static void *NoaSocketQueueKey = &NoaSocketQueueKey;

/// ECDH交换密钥超时时间
static const NSTimeInterval kKeyExchangeTimeout = 15.0;

@interface NoaIMSocketManager () <GCDAsyncSocketDelegate>

/// 是否是初始化(第一次连接)
@property (nonatomic, assign) BOOL initedSocket;

/// 能否联网
@property (nonatomic, assign) BOOL isReachable;

/// 能否联网的标识，默认为NO。当网络断开时，变为NO；当网络恢复时，变为YES。
@property (nonatomic, assign) BOOL isCanConnectNet;

/// socket 主机 地址
@property (nonatomic, copy) NSString *socketHost;
/// socket 主机 端口
@property (nonatomic, assign) NSInteger socketPort;
/// socket 主机 租户标识
@property (nonatomic, copy) NSString *socketOrgName;

/// socket 用户 id
@property (nonatomic, copy) NSString *socketUserID;
/// socket 用户 token
@property (nonatomic, copy) NSString *socketUserToken;

/// 套接字对象
@property (nonatomic, strong, readwrite) GCDAsyncSocket *gcdSocket;

/// 心跳机制定时器
@property (nonatomic, strong) dispatch_source_t heartTimer;

/// 心跳定时器专用锁（使用 NSLock 性能更好）
@property (nonatomic, strong) NSLock *heartTimerLock;

/// 发送Ping消息后，没有收到Pong响应次数
@property (nonatomic, assign) NSInteger heartNoPongCount;
@property (nonatomic, copy) NSString *foregroundProbeMessageID;
@property (nonatomic, assign) NSUInteger foregroundProbeSequence;

/// 已重连的次数
@property (nonatomic, assign) NSInteger reconnectCount;
/// 一轮从竞速开始，到 TCP/安全握手失败结束；重复失败回调只计一次。
@property (nonatomic, assign) BOOL reconnectAttemptPending;
@property (nonatomic, assign) NSUInteger reconnectFailedAttempts;
@property (nonatomic, assign) NSUInteger reconnectFailureGeneration;
@property (nonatomic, copy) NSString *reconnectFailureReason;
/// 加入企业的完整初始化重试预算，不随 ECDH/AUTH 成功清零。
@property (nonatomic, assign) NSUInteger initializationReconnectLimit;
@property (nonatomic, assign) NSUInteger initializationReconnectAttempts;
@property (nonatomic, assign) NSUInteger initializationReconnectGeneration;
@property (nonatomic, assign) BOOL initializationReconnectPending;
@property (nonatomic, assign) BOOL initializationReconnectExhausted;
@property (nonatomic, copy) void (^initializationReconnectFailureHandler)(NSString *reason);
@property (nonatomic, assign) BOOL reconnectScheduled;
@property (nonatomic, assign) NSUInteger reconnectSequence;
@property (nonatomic, assign) NSUInteger connectionSequence;

/// 仅在 internalQueue 上访问，用于合并重连及丢弃旧竞速结果。
@property (nonatomic, assign) BOOL isTcpRacing;
@property (nonatomic, assign) NSUInteger tcpRaceSequence;

/// socket接收到数据信息
@property (nonatomic, strong) NSMutableData *receiveData;

/// 是否是重连
@property (nonatomic, assign) BOOL isReconnect;

/// 内部连接串行队列，统一所有状态变更，避免竞态
@property (nonatomic, strong) dispatch_queue_t internalQueue;

/// 当前tcp的连接状态
@property (nonatomic, assign) LingIMSocketConnectState connectState;

/// 当前 AUTH 请求是否正在等待服务端回执。
@property (nonatomic, assign) BOOL authRequestPending;

/// 当前是否处于 ECDH 完成、AUTH 尚未得到最终结果的阶段。
@property (nonatomic, assign, readwrite) BOOL isAuthPhaseActive;

/// AUTH 请求序号，用于使已经派发的旧超时任务失效。
@property (nonatomic, assign) NSUInteger authRequestSequence;


/// 应用层复用相关属性
@property (nonatomic, strong) NSMutableData *frameBuffer;
@property (nonatomic, strong) dispatch_queue_t frameProcessingQueue;

/// ECDH密钥交换超时检测
@property (nonatomic, strong) dispatch_source_t keyExchangeTimer;

/// 密钥交换处理类
@property (nonatomic, strong) NovDecryptorManager *novDecryptorManager;

/// 当前初始化连接的随机关联标识，用于区分同一设备上的多次尝试。
@property (nonatomic, copy) NSString *initializationConnectionAttemptId;
/// 当前初始化连接已发生的有序阶段；成功时丢弃，失败时作为一个事件上报。
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *initializationSentryStages;
/// 当前初始化连接开始的单调时间，用于计算每个阶段耗时。
@property (nonatomic, assign) CFTimeInterval initializationSentryStartTime;
/// 是否正在记录登录前初始化链路，避免普通重连产生额外 Sentry 事件。
@property (nonatomic, assign) BOOL isInitializationSentryTraceActive;
/// 是否已终结并上报当前初始化链路，防止多个失败回调重复告警。
@property (nonatomic, assign) BOOL isInitializationSentryTraceFinalized;

@end

@implementation NoaIMSocketManager

#pragma mark - <<<<<<单例>>>>>>
+ (instancetype)sharedTool {
    
    static NoaIMSocketManager *_manager = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        //不能再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];

        //默认配置
        [_manager socketDefaultConfig];
        
        //开始网络状态监听
        [_manager startNetworkStatusMonitoring];
    });
    
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMSocketManager sharedTool];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMSocketManager sharedTool];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMSocketManager sharedTool];
}

#pragma mark - socket的用户id
- (NSString *)socketUserID {
    return _socketUserID;
}

#pragma mark - socket的用户token
- (NSString *)socketUserToken {
    return _socketUserToken;
}

#pragma mark - socket 主机 地址
- (NSString *)socketHostValue {
    return _socketHost;
}

#pragma mark - socket 主机 端口
- (NSInteger)socketPortValue {
    return _socketPort;
}

#pragma mark - 清空用户信息
- (void)clearUserInfo {
    _socketUserID = nil;
    _socketUserToken = nil;
    [self cancelAuthPhase];
    [self stopSocketReconnectWithReason:@"user_changed"];
}

#pragma mark - 默认配置
- (void)socketDefaultConfig {
    // 每次启动App默认不是重连
    _isReconnect = NO;
    // 心跳无响应次数
    _heartNoPongCount = 0;
    // 重连次数
    _reconnectCount = 0;
    // 初始化接收数据对象
    _receiveData = [[NSMutableData alloc] init];
    // 当前连接状态默认为未连接
    _connectState = LingIMSocketConnectStateDisconnected;
    // tcp连接队列
    _internalQueue = dispatch_queue_create("com.lingim.socket.internal", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(_internalQueue, NoaSocketQueueKey, (__bridge void *)self, NULL);
    // 当前网络状态
    _isReachable = [[NetWorkStatusManager shared] getConnectStatus];
    // 应用层复用相关属性初始化
    _frameBuffer = [[NSMutableData alloc] init];
    _frameProcessingQueue = dispatch_queue_create("com.lingim.frame.processing", DISPATCH_QUEUE_SERIAL);
    
    // 心跳定时器专用锁初始化（使用 NSLock，性能更好，便于调试）
    _heartTimerLock = [[NSLock alloc] init];
    _heartTimerLock.name = @"com.lingim.heartTimer.lock";
    
    // 密钥交换相关
    _novDecryptorManager = [[NovDecryptorManager alloc] init];
    
    // 网络连接处理
    [self configureSocketConnect];
}

#pragma mark - 开始网络状态监听
- (void)startNetworkStatusMonitoring {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange:) name:NetWorkStatusManager.NetworkStatusChangedNotification object:nil];
}

#pragma mark - 监听网络状态是否可用
- (void)networkChange:(NSNotification *)notification {
    self.isReachable = [[NetWorkStatusManager shared] getConnectStatus];
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=NETWORK_CHANGED reachable=%d", self.isReachable]];
    [self configureSocketConnect];
}

- (void)configureSocketConnect {
    if (self.isReachable) {
        // 网络现在可用
        self.isCanConnectNet = YES;
        
        // 处理连接
        if (self.initedSocket) {
            // socket配置完成之后的网络状态监听
            CIMLog(@"网络变化，准备重连...");
            [NoaLocalLogger info:@"[TCP重连链路] stage=NETWORK_RECONNECT_REQUEST reason=network_available"];
            [self scheduleReconnectIfNeeded];
        }else {
            // socket没有初始化，开始调用连接
            CIMLog(@"网络变化，正在连接...");
            [self startSocketConnect];
        }
    }else {
        CIMLog(@"网络不可用, 清理数据");
        
        // 网络现在不可用
        self.isCanConnectNet = NO;
        
        // 清理数据
        [self cleanForNetworkLoss];
    }
}

#pragma mark - Connect
- (void)startSocketConnect {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.internalQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        // 主动停止或无网时不能启动旧连接任务。
        if (!self.isCanConnectNet || !self.isCanReconnect) return;
        
        // 判断tcp连接地址
        if (self.socketHost.length == 0) {
            [NoaLocalLogger error:@"[socket连接] 暂无主机信息，不再连接"];
            
            [self sentryUploadWithEventObj:@{
                @"event" : @"socket连接",
                @"error" : @"暂无主机信息，不再连接",
                @"host" : self.socketHost ? self.socketHost : @"",
                @"port" : @(self.socketPort)
            } errorCode:@""];
            [self captureInitializationSentryFailureAtStage:@"tcp_connect_failed"
                                                      reason:@"socket_host_missing"
                                                   errorCode:@""];
            
            return;
        }
        
        // 判断tcp连接状态，正在连接或已连接，避免重复
        if (self.connectState == LingIMSocketConnectStateConnecting ||
            self.connectState == LingIMSocketConnectStateConnected) {
            [NoaLocalLogger info:[NSString stringWithFormat:@"[socket连接] 当前状态为%@，跳过连接",
                          self.connectState == LingIMSocketConnectStateConnecting ? @"正在连接" : @"已连接"]];
            
            return;
        }
        
        [self stopSocketReconnectWithReason:@"connection_start"];
        NSUInteger connectionSequence = self.connectionSequence;

        // 标记socket已经初始化了
        if (!self.initedSocket) {
            self.initedSocket = YES;
        }
        
        // 重新设置为连接状态(此处手动将连接状态置为正在连接中，是因为连接是在0.1s后)
        [self updateConnectState:LingIMSocketConnectStateConnecting];
        [self recordInitializationSentryStage:@"tcp_connect_requested" result:nil reason:nil];
        
        // 强制清理旧连接，确保状态一致(如果已经在连接中了，会把连接状态置为没有连接)
        [self forceDisconnectSocket];
        
        // 等待一小段时间确保断开完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), self.internalQueue, ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            
            if (connectionSequence != self.connectionSequence || !self.isCanConnectNet ||
                !self.isCanReconnect || self.connectState != LingIMSocketConnectStateConnecting) {
                [NoaLocalLogger info:@"[TCP重连链路] stage=TCP_CONNECT_CANCELLED reason=stale_or_offline"];
                return;
            }
            // 重新设置为连接状态
            [self updateConnectState:LingIMSocketConnectStateConnecting];
            
            // 通知代理开始连接了
            [SOCKETMANAGERTOOL cimConnecting];
            
            NSError *error = nil;
            [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=TCP_CONNECT_BEGIN host=%@ port=%ld timeout=%d", self.socketHost, (long)self.socketPort, LingIMConnectTimeout]];
            BOOL ok = [self.gcdSocket connectToHost:self.socketHost
                                             onPort:self.socketPort
                                        withTimeout:LingIMConnectTimeout
                                              error:&error];
            [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=TCP_CONNECT_SUBMITTED accepted=%d error=%ld", ok, (long)error.code]];
            if (!ok || error) {
                [NoaLocalLogger error: [NSString stringWithFormat:@"[socket连接] 参数连接失败，失败信息:%@", error]];
                
                [self sentryUploadWithEventObj:@{
                    @"event" : @"socket连接",
                    @"error" : [NSString stringWithFormat:@"使用参数连接失败，失败信息:%@", error],
                    @"host" : self.socketHost ? self.socketHost : @"",
                    @"port" : @(self.socketPort)
                } errorCode:@""];
                
                self.reconnectFailureReason = @"tcp_connect_failed";

                [SOCKETMANAGERTOOL cimConnectFailWithError:error];
                [self updateConnectState:LingIMSocketConnectStateDisconnected];
                [self startingSocketReconnect];
                [NoaLocalLogger error:@"[邀请码竞速] 通知连接失败"];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"socketECDHDidConnectFailure" object:nil];
            } else {
                [NoaLocalLogger info: @"[socket连接] 参数配置成功，已成功创建连接，等待连接成功"];
            }
        });
    });
}

#pragma mark - Disconnect
- (void)disconnectSocket {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.internalQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        // 停止心跳机制
        [self stopSocketHeartbeat];
        
        //停止重连机制
        [self stopSocketReconnectWithReason:@"explicit_disconnect"];
        
        [self cancelAuthPhase];
        [self stopKeyExchangeTimer];
        [NoaLocalLogger info:@"调用disconnectSocket断开"];
        [self.gcdSocket disconnect];
        
        // 更新连接状态
        [self updateConnectState:LingIMSocketConnectStateDisconnected];
    });
}

/// 强制断开Socket连接，用于连接前清理
- (void)forceDisconnectSocket {
    // 强制断开连接，不等待回调
    if (self.gcdSocket.isConnected) {
        [self.gcdSocket disconnectAfterReadingAndWriting];
        [NoaLocalLogger info:@"强制断开旧连接"];
    }
    
    // 重置相关状态
    [self clearKeyExchangeInfo];
    
    // 停止ECDH密钥交换超时定时器
    [self stopKeyExchangeTimer];
    
    
    // 清理应用层复用相关状态
    [self cleanupReceiveBuffers];
}

/// 网络断开时的清理，不触发重连
- (void)cleanForNetworkLoss {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.internalQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        // 停止心跳机制
        [self stopSocketHeartbeat];
        
        //停止重连机制
        [self stopSocketReconnectWithReason:@"network_lost"];
        
        [self cancelAuthPhase];
        [self stopKeyExchangeTimer];
        [NoaLocalLogger info:@"无法连接外网，断开"];
        [self.gcdSocket disconnect];
        
        [self updateConnectState:LingIMSocketConnectStateDisconnected];
    });
}

#pragma mark - Reconnect
- (void)scheduleReconnectIfNeeded {
    // 当前连接状态为已连接或者未连接，取消连接
    if (self.connectState == LingIMSocketConnectStateConnected ||
        self.connectState == LingIMSocketConnectStateConnecting) {
        return;
    }
    [self startingSocketReconnect];
}

/// 无上限重试：1、2、4、8、16 秒，此后保持 16 秒。
- (void)prepareForConnectionInitialization {
    dispatch_async(self.internalQueue, ^{
        self.isCanReconnect = NO;
        [self stopSocketReconnectWithReason:@"initialization_restart"];
        [self stopSocketHeartbeat];
        [self resetSocketHeartNoPongCount];
        // 已在 internalQueue 内，同步使旧前台探测失效，避免影响新连接。
        self.foregroundProbeSequence++;
        self.foregroundProbeMessageID = nil;
        [self cancelAuthPhase];
        [self stopKeyExchangeTimer];
        GCDAsyncSocket *oldSocket = self->_gcdSocket;
        self->_gcdSocket = nil;
        oldSocket.delegate = nil;
        [oldSocket disconnect];
        self.socketHost = nil;
        self.socketPort = 0;
        [self clearKeyExchangeInfo];
        self.novDecryptorManager = [[NovDecryptorManager alloc] init];
        [self cleanupReceiveBuffers];
        [self updateConnectState:LingIMSocketConnectStateDisconnected];
    });
}

- (void)resumeInitializationReconnectWithOrgName:(NSString *)orgName {
    [self resumeInitializationReconnectWithOrgName:orgName failureReason:nil];
}

- (void)setInitializationReconnectLimit:(NSUInteger)limit failureHandler:(void (^)(NSString *reason))failureHandler {
    dispatch_async(self.internalQueue, ^{
        self.initializationReconnectGeneration++;
        self.initializationReconnectLimit = limit;
        self.initializationReconnectAttempts = 0;
        self.initializationReconnectPending = NO;
        self.initializationReconnectExhausted = NO;
        self.initializationReconnectFailureHandler = failureHandler;
    });
}

- (void)resumeInitializationReconnectWithOrgName:(NSString *)orgName failureReason:(NSString *)reason {
    dispatch_async(self.internalQueue, ^{
        if (self.initializationReconnectExhausted) return;
        if (self.initializationReconnectLimit > 0 && reason.length > 0) self.reconnectFailureReason = reason;
        self.socketOrgName = orgName;
        self.isCanReconnect = YES;
        // 即使还没有选中过节点，网络恢复也必须进入竞速重连而非连接空地址。
        self.initedSocket = YES;
        if (self.connectState != LingIMSocketConnectStateDisconnected) {
            // 系统配置请求失败时，重新握手后再获取配置。
            [self disconnectSocket];
        }
        [self startingSocketReconnect];
    });
}

/// 安全传输层建立成功、切换账号或主动终止后，下一段连续失败重新计数。
- (void)resetReconnectFailureNotice {
    self.reconnectAttemptPending = NO;
    self.reconnectFailedAttempts = 0;
    self.reconnectFailureReason = nil;

    self.reconnectFailureGeneration++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"IMReconnectFailureNotice" object:self userInfo:nil];
    });
}

/// 只在失败之后计数，发起第五次重连时不提示；第五次失败后继续原有退避。
- (void)completeFailedReconnectAttempt {
    if (self.initializationReconnectLimit > 0) return; // 加入失败由专用终止回调提示。
    if (!self.reconnectAttemptPending) return;
    self.reconnectAttemptPending = NO;
    if (self.reconnectFailureReason.length == 0) return;
    if (self.reconnectFailedAttempts < NSUIntegerMax) self.reconnectFailedAttempts++;
    if (self.reconnectFailedAttempts != 5) return;
    NSUInteger generation = self.reconnectFailureGeneration;
    NSDictionary *info = @{@"reason": self.reconnectFailureReason};
    dispatch_async(dispatch_get_main_queue(), ^{
        __block BOOL current;
        dispatch_sync(self.internalQueue, ^{
            current = generation == self.reconnectFailureGeneration && self.isCanReconnect;
        });
        if (current) [[NSNotificationCenter defaultCenter] postNotificationName:@"IMReconnectFailureNotice" object:self userInfo:info];
    });
}

/// 只在上一轮确实失败、准备开始下一轮时检查；第五轮成功仍可正常完成加入。
- (BOOL)finishLimitedInitializationRetryIfNeeded {
    if (self.initializationReconnectLimit == 0 || !self.initializationReconnectPending) return NO;
    self.initializationReconnectPending = NO;
    if (self.initializationReconnectAttempts < self.initializationReconnectLimit) return NO;
    NSString *reason = self.reconnectFailureReason ?: @"tcp_connect_failed";
    void (^failureHandler)(NSString *) = self.initializationReconnectFailureHandler;
    NSUInteger generation = self.initializationReconnectGeneration;
    self.initializationReconnectExhausted = YES;
    self.isCanReconnect = NO;
    [self stopSocketReconnectWithReason:@"join_retries_exhausted"];
    [self disconnectSocket];
    dispatch_async(dispatch_get_main_queue(), ^{
        __block BOOL current;
        dispatch_sync(self.internalQueue, ^{
            current = generation == self.initializationReconnectGeneration && self.initializationReconnectExhausted;
        });
        if (current && failureHandler) failureHandler(reason);
    });
    return YES;
}

- (void)startingSocketReconnect {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.internalQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=RECONNECT_ENTER allow=%d online=%d scheduled=%d racing=%d", self.isCanReconnect, self.isCanConnectNet, self.reconnectScheduled, self.isTcpRacing]];
        if (self.initializationReconnectExhausted || !self.isCanReconnect || !self.isCanConnectNet || self.reconnectScheduled || self.isTcpRacing ||
            self.connectState != LingIMSocketConnectStateDisconnected) return;

        if ([self finishLimitedInitializationRetryIfNeeded]) return;
        [self completeFailedReconnectAttempt];
        self.reconnectScheduled = YES;
        NSUInteger sequence = ++self.reconnectSequence;
        NSTimeInterval delay = (NSTimeInterval)(1 << MIN(MAX(self.reconnectCount, 0), 4));
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=RECONNECT_WAIT completedAttempts=%ld delay=%.0f sequence=%lu", (long)self.reconnectCount, delay, (unsigned long)sequence]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.internalQueue, ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || sequence != self.reconnectSequence || !self.reconnectScheduled) return;
            self.reconnectScheduled = NO;
            if (!self.isCanReconnect || !self.isCanConnectNet || self.isTcpRacing ||
                self.connectState != LingIMSocketConnectStateDisconnected) return;
            [self performSocketReconnect];
        });
    });
}

/// internalQueue 上执行一轮竞速和连接。
- (void)performSocketReconnect {
    if (self.initializationReconnectExhausted) return;
    __weak typeof(self) weakSelf = self;
    if (self.initializationReconnectLimit > 0) {
        self.initializationReconnectAttempts++;
        self.initializationReconnectPending = YES;
    }
    self.reconnectAttemptPending = YES;
    self.reconnectFailureReason = nil;

    if (self.reconnectCount < NSIntegerMax) self.reconnectCount++;
    [NoaLocalLogger info:[NSString stringWithFormat:@"[socket连接] 开始重连... 第%ld次", (long)self.reconnectCount]];
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=NOTIFY_RECONNECT attempt=%ld", (long)self.reconnectCount]];
    [SOCKETMANAGERTOOL cimDisconnect];

    if (self.raceTcpNodeBlock) {
        self.isTcpRacing = YES;
        NSUInteger sequence = ++self.tcpRaceSequence;
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=RACE_DISPATCH sdkRound=%lu oldHost=%@ oldPort=%ld timeout=60", (unsigned long)sequence, self.socketHost, (long)self.socketPort]];
        NoaTcpRaceCompletion completion = ^(NSString *host, NSInteger port, NSString *failureReason) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            dispatch_async(self.internalQueue, ^{
                if (!self.isTcpRacing || sequence != self.tcpRaceSequence) {
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=RACE_RESULT_IGNORED sdkRound=%lu current=%lu reason=cancelled_or_completed", (unsigned long)sequence, (unsigned long)self.tcpRaceSequence]];
                    return;
                }
                [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=RACE_RESULT sdkRound=%lu host=%@ port=%ld", (unsigned long)sequence, host ?: @"", (long)port]];
                [self cancelPendingTcpRaceWithReason:@"race_result_consumed"];
                if (!self.isCanReconnect || !self.isCanConnectNet ||
                    self.connectState != LingIMSocketConnectStateDisconnected) {
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=CONNECT_SKIP sdkRound=%lu allow=%d online=%d state=%ld", (unsigned long)sequence, self.isCanReconnect, self.isCanConnectNet, (long)self.connectState]];
                    return;
                }

                if (host.length > 0 && port > 0 && port <= UINT16_MAX) {
                    self.socketHost = host;
                    self.socketPort = port;
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=NODE_SELECTED sdkRound=%lu host=%@ port=%ld", (unsigned long)sequence, host, (long)port]];
                } else {
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=FALLBACK_OLD_NODE sdkRound=%lu host=%@ port=%ld", (unsigned long)sequence, self.socketHost, (long)self.socketPort]];
                }
                self.reconnectFailureReason = failureReason;
                // 冷启动可能还没有旧节点；本轮导航/探测失败后继续退避，不能停在空地址。
                if (self.socketHost.length == 0 || self.socketPort <= 0 || self.socketPort > UINT16_MAX) {
                    if (self.reconnectFailureReason.length == 0) self.reconnectFailureReason = @"tcp_nodes_empty";
                    [self startingSocketReconnect];
                    return;
                }
                self.reconnectFailureReason = nil; // 正式连接失败时使用实际 Socket 错误。
                // 不再读取缓存最优节点，避免覆盖本轮竞速结果。
                [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=CONNECT_DISPATCH sdkRound=%lu", (unsigned long)sequence]];
                [self startSocketConnect];
            });
        };
        self.raceTcpNodeBlock(completion);
        // SDK 兜底：业务层未回调也不能一直卡在竞速状态。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), self.internalQueue, ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || !self.isTcpRacing || sequence != self.tcpRaceSequence) return;
            [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=SDK_RACE_TIMEOUT sdkRound=%lu seconds=60", (unsigned long)sequence]];
            completion(nil, 0, @"tcp_probe_timeout");
        });
        return;
    }

    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=RACE_UNAVAILABLE action=legacy_reconnect"]];
    // 重连等待已经完成，未接入竞速时直接使用已有节点。
    if ([self hasOptimalServerAvailable]) [self connectWithOptimalServer];
    else [self startSocketConnect];
}

/// AUTH/刷新失败时保留用户信息，断开后统一进入退避重连。
- (void)retryConnectionAfterAuthFailure:(NSInteger)code {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.internalQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.isCanReconnect) return;
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_RETRY code=%ld action=backoff_reconnect", (long)code]];
        // AUTH/Token 属于业务认证，不计入网络连接失败，也不产生这条 Toast。
        [self resetReconnectFailureNotice];

        [self cancelAuthPhase];
        [self disconnectSocket];
        // 即使当前没有底层连接、不会产生断线回调，也能继续恢复。
        [self startingSocketReconnect];
    });
}

/// 在 internalQueue 上取消本轮竞速；探测的迟到回调不能再启动连接。
- (void)cancelPendingTcpRaceWithReason:(NSString *)reason {
    if (self.isTcpRacing) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=SDK_RACE_INVALIDATE sdkRound=%lu reason=%@ online=%d allow=%d state=%ld", (unsigned long)self.tcpRaceSequence, reason, self.isCanConnectNet, self.isCanReconnect, (long)self.connectState]];
    }
    self.tcpRaceSequence += 1;
    if (!self.isTcpRacing) return;
    self.isTcpRacing = NO;
    if (self.cancelTcpNodeRaceBlock) self.cancelTcpNodeRaceBlock();
}

#pragma mark - Socket连接状态维护 State

/// 当前socket连接状态
- (BOOL)currentSocketConnectStatus {
    return self.connectState == LingIMSocketConnectStateConnected;
}

/// 是否交换ecdh key成功
- (BOOL)isExchangeEcdhKeySuccess {
    return self.isECDHCompleted;
}

/// 更新socket连接状态
/// - Parameter state: 当前sock连接状态
- (void)updateConnectState:(LingIMSocketConnectState)state {
    if (_connectState == state) return;
    _connectState = state;
}

#pragma mark - <<<<<<业务>>>>>>
#pragma mark - 配置socket用户信息(此方法在用户名、密码输入后调用)
- (void)configureSocketUser:(NoaIMSocketUserOptions *)userOptions {
    if (!userOptions) {
        return;
    }
    [NoaLocalLogger info:[NSString stringWithFormat:@"[socket连接] 设置了用户 userId = %@, token = %@", userOptions.userID, userOptions.userToken]];
    
    BOOL isUserChange = NO;
    NSString *newUserId = userOptions.userID ? userOptions.userID : @"";
    NSString *newUserToken = userOptions.userToken ? userOptions.userToken : @"";
    BOOL accountChanged = _socketUserID.length > 0 && ![_socketUserID isEqualToString:newUserId];
    
    if (![_socketUserID isEqualToString:newUserId] || ![_socketUserToken isEqualToString:newUserToken]) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[socket连接] configureSocketUser:(LingIMSocketUserOptions *)userOptions 用户id、用户token出现差异，当前连接的userID = %@，token = %@", newUserId, newUserToken]];
        
        isUserChange = YES;
        _socketUserID = newUserId;
        _socketUserToken = newUserToken;
    }
    
    if (!isUserChange) {
        return;
    }
    
    if (accountChanged) {
        [self cancelAuthPhase];
        [self stopSocketReconnectWithReason:@"user_changed"];
        [self disconnectSocket];
        [self startingSocketReconnect];
        return;
    }

    // 设置成功用户信息后，发送用户信息认证(认证内部有条件判断，此处无需判断)
    [self authSocketUser];
}

#pragma mark - 配置socket网络信息
- (void)configureSocketHost:(NoaIMSocketHostOptions *)hostOptions {
    if (!hostOptions) {
        return;
    }
    
    if (self.initializationReconnectExhausted) return;
    if (!self.isCanReconnect) {
        self.isCanReconnect = YES;
    }
    
    [NoaLocalLogger info:[NSString stringWithFormat:@"[socket连接] 设置了socket地址 host = %@, port = %ld", hostOptions.socketHost, hostOptions.socketPort]];
    
    BOOL isNeedCreateNewConnect = NO;
    NSString *newHost = hostOptions.socketHost ? hostOptions.socketHost : @"";
    NSInteger newPort = hostOptions.socketPort;
    
    if (![_socketHost isEqualToString:newHost] || _socketPort != newPort) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[socket连接] !!!!!!!!!!! configSocketHost:(LingIMSocketHostOptions *)hostOptions user:(LingIMSocketUserOptions *)userOptions 地址与端口号出现差异 当前连接的ip = %@,端口号 = %ld, 新的ip = %@，新的端口号 = %ld", _socketHost, _socketPort, newHost, newPort]];
        
        isNeedCreateNewConnect = YES;
        _socketHost = newHost;
        _socketPort = newPort;
    }
    
    _socketOrgName = hostOptions.socketOrgName;
    [self recordInitializationSentryStage:@"tcp_endpoint_configured" result:@YES reason:nil];
    if (!isNeedCreateNewConnect && self.connectState != LingIMSocketConnectStateDisconnected) {
        // 为什么连接的ip端口号，且忽略未连接状态:因为邀请码配置页面，需要断开socket连接，并且不能重连
        if ([self currentSocketConnectStatus]) {
            // 已连接,且ip与端口号一致,直接通知上层连接成功
            [NoaLocalLogger info:@"[邀请码竞速] 邀请码竞速成功，通知连接成功"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"socketECDHDidConnectSuccese" object:nil];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[邀请码竞速] 正在连接中,且ip与端口号一致,暂不处理，等待连接回调发送通知，当前连接状态:%ld, 是否支持重连:%@", (long)self.connectState, self.isCanReconnect ? @"支持" : @"禁止"]];
        }
        return;
    }
    
    if ([self currentSocketConnectStatus]) {
        [NoaLocalLogger info:@"[socket连接] configSocketHost:(LingIMSocketHostOptions *)hostOptions user:(LingIMSocketUserOptions *)userOptions 当前已连接，但是地址与端口号出现差异，需要先断开后连接\n正在断开中"];
        
        // 如果当前socket已经连接成功，直接断开连接，通过disconnect触发diddisconnect回调，然后重新竞速连接
        [self disconnectSocket];
        
    }
    [NoaLocalLogger info:@"[socket连接] configSocketHost:(LingIMSocketHostOptions *)hostOptions user:(LingIMSocketUserOptions *)userOptions 已断开，正在连接"];
    
    // 当前socket已断开，直接连接
    [self startSocketConnect];
}

/// 恢复是否是重连reConnect状态为初始状态
- (void)configSetIsReconenctStatus {
    _isReconnect = NO;
}

#pragma mark - 鉴权socket用户
/// 使用当前用户信息构造并提交 Socket 鉴权消息；前置条件不满足时仅记录原因并返回。
- (void)authSocketUser {
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_ENTER socketConnected=%d ecdh=%d hasKey=%d hasUser=%d hasToken=%d hasOrg=%d", self.gcdSocket.isConnected, self.isECDHCompleted, self.novDecryptorManager.shareKey.length > 0, _socketUserID.length > 0, _socketUserToken.length > 0, _socketOrgName.length > 0]];
    [NoaLocalLogger info:@"开始发送用户鉴权信息..."];

    if (self.authRequestPending) {
        [NoaLocalLogger info:@"[AUTH链路] stage=AUTH_SEND_SKIPPED reason=request_pending"];
        return;
    }
    
    if (!self.isECDHCompleted) {
        [NoaLocalLogger error:@"[用户鉴权] 用户鉴权信息未发送，原因:ecdh密钥交换未成功"];
        return;
    }
    
    if (!self.novDecryptorManager.shareKey || self.novDecryptorManager.shareKey.length == 0) {
        [NoaLocalLogger error:@"[用户鉴权] 用户鉴权信息未发送，原因: shareKey未生成"];
        return;
    }
    
    if (!_socketUserID || _socketUserID.length == 0) {
        [NoaLocalLogger error:@"[用户鉴权] 用户信息鉴权未发送，原因:用户id异常"];
        return;
    }
    
    if (!_socketUserToken || _socketUserToken.length == 0) {
        [NoaLocalLogger error:@"[用户鉴权] 用户信息鉴权未发送，原因:用户Token异常"];
        return;
    }
    
    if (!_socketOrgName || _socketOrgName.length == 0) {
        [NoaLocalLogger error:@"[用户鉴权] 用户信息鉴权未发送，原因:_socketOrgName异常"];
        return;
    }
    
    IMAuthMessage *authMessage = [[IMAuthMessage alloc] init];
    authMessage.userId = _socketUserID;//用户ID
    authMessage.token = _socketUserToken;//用户token
    authMessage.orgName = _socketOrgName;//用户租户标识
    authMessage.msgId = [[NoaIMManagerTool sharedManager] getMessageID];//变化的UUID
    authMessage.loginIp = [[NoaIMManagerTool sharedManager] getDevicePublicNetworkIP];//ip地址
    authMessage.deviceType = @"IOS";//设备平台
    authMessage.deviceUuid = [FCUUID uuidForDevice];//固定不变的UUID
    authMessage.platform = @"iOS";
    authMessage.versionNumber = [NoaIMDeviceTool appVersion];//客户端版本号
    
    IMMessage *message = [[IMMessage alloc] init];
    message.dataType = IMMessage_DataType_ImauthMessage;
    message.authMessage = authMessage;

    self.authRequestPending = YES;
    self.isAuthPhaseActive = YES;
    self.authRequestSequence += 1;
    NSUInteger requestSequence = self.authRequestSequence;

    [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=AUTH_ENQUEUE msgId=%@ connectState=%ld socketConnected=%@ ecdh=%@ auth=%@ tokenEmpty=%@ tokenLength=%lu reconnectCount=%ld",
                          authMessage.msgId,
                          (long)self.connectState,
                          self.gcdSocket.isConnected ? @"YES" : @"NO",
                          self.isECDHCompleted ? @"YES" : @"NO",
                          SOCKETMANAGERTOOL.isAuth ? @"YES" : @"NO",
                          authMessage.token.length == 0 ? @"YES" : @"NO",
                          (unsigned long)authMessage.token.length,
                          (long)self.reconnectCount]];
    
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_SEND msgId=%@", authMessage.msgId]];
    [self sendSocketMessage:message tag:LingIMMessageTag];
    [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=AUTH_SEND_REQUESTED msgId=%@",
                          authMessage.msgId]];

    // AUTH 超过 10 秒未返回则重建连接，保留登录态。
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), self.internalQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.authRequestPending || self.authRequestSequence != requestSequence) {
            return;
        }
        self.authRequestPending = NO;
        self.isAuthPhaseActive = NO;
        self.authRequestSequence += 1;
        [NoaLocalLogger info:@"[TCP重连链路] stage=AUTH_TIMEOUT seconds=10 action=backoff_reconnect"];
        [NoaLocalLogger error:@"[AUTH链路] stage=AUTH_TIMEOUT timeoutSeconds=10 action=reconnect"];
        [SOCKETMANAGERTOOL finishAuthWithLogoutCode:999992 message:@"连接认证超时，正在重连"];
    });
}

/// 收到 AUTH 回执后结束本次等待，旧的超时任务会因序号变化而自动失效。
- (void)completePendingAuthRequest {
    self.authRequestPending = NO;
    self.authRequestSequence += 1;
}

/// 终止 AUTH 阶段，供失败退出路径在断开 Socket 前清理认证状态。
- (void)cancelAuthPhase {
    [self completePendingAuthRequest];
    self.isAuthPhaseActive = NO;
}

/// AUTH 成功后才对外标记业务连接成功，并恢复原有回调、缓存请求和重连状态。
- (void)finishAuthPhaseSuccessfully {
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_SUCCESS action=business_connected"]];
    [self completePendingAuthRequest];
    self.isAuthPhaseActive = NO;
    [self updateConnectState:LingIMSocketConnectStateConnected];

    if (self.isReconnect) {
        [SOCKETMANAGERTOOL cimReConnectSuccess];
    }
    [SOCKETMANAGERTOOL cimConnectSuccess];
    if (!self.isReconnect) {
        self.isReconnect = YES;
    }
    self.reconnectCount = 0;
    [self stopSocketReconnectWithReason:@"auth_success"];
    [SOCKETMANAGERTOOL sendAllCacheRequest];
}

#pragma mark - 发送socket消息
- (void)sendSocketMessage:(id)message tag:(NSInteger)messageTag{
    [self sendSocketMessage:message timeOut:LingIMMessageTimeout tag:messageTag];
}

/// 加密并提交 Socket 消息；聊天消息会继续进入现有的超时监听流程。
/// @param message 待发送的 IMMessage 消息对象。
/// @param timeOut Socket 写入超时时间，单位为秒。
/// @param messageTag GCDAsyncSocket 写入标签。
- (void)sendSocketMessage:(id)message
                  timeOut:(NSInteger)timeOut
                      tag:(NSInteger)messageTag {
    if ([message isKindOfClass:[IMMessage class]]) {
        IMMessage *imMsg = (IMMessage *)message;
        if (!self.isECDHCompleted) {
            [NoaLocalLogger error:@"[socket] 消息未发送，原因:ecdh密钥交换未成功"];
            // TODO: 避免对发送的聊天消息进行拦截，导致无法超时
            [SOCKETMANAGERTOOL sendMessageDealWith:imMsg];
            return;
        }
        
        if (!self.novDecryptorManager.shareKey || self.novDecryptorManager.shareKey.length == 0) {
            [NoaLocalLogger error:@"[socket] 消息未发送，原因: shareKey未生成"];
            // TODO: 避免对发送的聊天消息进行拦截，导致无法超时
            [SOCKETMANAGERTOOL sendMessageDealWith:imMsg];
            return;
        }
        
        if (!SOCKETMANAGERTOOL.isAuth) {
            if (imMsg.dataType == IMMessage_DataType_ImchatMessage && imMsg.chatMessage.mType != IMChatMessage_MessageType_HaveReadMessage) {
                // TODO: auth未成功时，聊天消息无法发送，需要对发送的聊天消息进行拦截
                [SOCKETMANAGERTOOL sendMessageDealWith:message];
                return;
            }
        }
        
        //消息转换二进制流
        IMMessage *sendMessage = (IMMessage *)message;
        [NoaLocalLogger verbose:[NSString stringWithFormat:@"[socket] 发送消息中。。。 message = %@", sendMessage]];
        
        // 使用增强帧协议格式进行加密
        NSData *frameData = [self.novDecryptorManager buildEncryptedMessageFrameWithData:[sendMessage delimitedData]];
        if (!frameData) {
            [NoaLocalLogger error:@"[socket] ❌ 消息加密失败，无法发送"];
            if (sendMessage.dataType == IMMessage_DataType_ImchatMessage &&
                sendMessage.chatMessage.mType != IMChatMessage_MessageType_HaveReadMessage) {
                [SOCKETMANAGERTOOL notifyMessageSendFail:sendMessage.chatMessage.msgId reason:CIMMessageSendFailureReasonEncryption];
            }
            return;
        }

        if (sendMessage.dataType == IMMessage_DataType_ImauthMessage) {
            [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=AUTH_FRAME_READY msgId=%@ frameLength=%lu",
                                  sendMessage.authMessage.msgId,
                                  (unsigned long)frameData.length]];
        }
        
        // TODO: 确保 writeData 在主队列（delegateQueue）调用 原因：GCDAsyncSocket 的 delegateQueue 是主队列，所有操作应在同一队列
        if ([NSThread isMainThread]) {
            // 已在主线程，直接发送
            if (sendMessage.dataType == IMMessage_DataType_ImauthMessage) {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=AUTH_WRITE_SCHEDULED msgId=%@ thread=main socketConnected=%@",
                                      sendMessage.authMessage.msgId,
                                      self.gcdSocket.isConnected ? @"YES" : @"NO"]];
            }
            [self.gcdSocket writeData:frameData withTimeout:timeOut tag:messageTag];
        } else {
            // 不在主线程，调度到主队列
            if (sendMessage.dataType == IMMessage_DataType_ImauthMessage) {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[AUTH链路] stage=AUTH_WRITE_SCHEDULED msgId=%@ thread=dispatch_to_main socketConnected=%@",
                                      sendMessage.authMessage.msgId,
                                      self.gcdSocket.isConnected ? @"YES" : @"NO"]];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.gcdSocket writeData:frameData withTimeout:timeOut tag:messageTag];
            });
        }
        
        //对发送的消息进行超时监听处理
        [SOCKETMANAGERTOOL sendMessageDealWith:sendMessage];
        
    }else {
        [NoaLocalLogger error:@"[socket] ❌ 消息格式错误，发送失败"];
    }
}


#pragma mark - 开始心跳机制(用户鉴权成功后开始)❤️❤️❤️❤️❤️❤️
- (void)startSocketHeartbeat {
    CIMWeakSelf
    
    [_heartTimerLock lock];
    
    if (_heartTimer) {
        CIMLog(@"⚠️ 心跳定时器已存在，跳过创建");
        [_heartTimerLock unlock];
        return;
    }
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    if (!queue) {
        CIMLog(@"❌ 无法获取全局队列");
        [_heartTimerLock unlock];
        return;
    }
    
    @try {
        _heartTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        if (!_heartTimer) {
            CIMLog(@"❌ 心跳定时器创建失败");
            [_heartTimerLock unlock];
            return;
        }
        
        // 设置事件处理
        dispatch_source_set_event_handler(_heartTimer, ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) {
                CIMLog(@"⚠️ 心跳定时器回调时对象已释放");
                return;
            }
            
            if (!self->_heartTimer) {
                CIMLog(@"⚠️ 心跳定时器已失效");
                return;
            }
            
            @try {
                // 执行心跳
                [self sendSocketPingMessage];
                
                // 每次执行后立即更新下次执行时间
                [self updateNextHeartbeatTime];
                
            } @catch (NSException *exception) {
                CIMLog(@"❌ 心跳处理异常: %@", exception);
                [self stopSocketHeartbeat];
            }
        });
        
        // 启动定时器，初始延迟为0（立即执行）
        dispatch_source_set_timer(_heartTimer,
                                  DISPATCH_TIME_NOW,
                                  DISPATCH_TIME_FOREVER,
                                  0);
        
        dispatch_resume(_heartTimer);
        CIMLog(@"✅ 心跳定时器启动成功，立即执行第一次心跳");
        
    } @catch (NSException *exception) {
        CIMLog(@"❌ 心跳定时器创建异常: %@", exception);
        if (_heartTimer) {
            dispatch_source_cancel(_heartTimer);
            _heartTimer = nil;
        }
        [_heartTimerLock unlock];
        return;
    }
    
    [_heartTimerLock unlock];
}

// 修改后的方法：每次执行后更新下次时间
- (void)updateNextHeartbeatTime {
    [_heartTimerLock lock];
    
    // 保存本地副本，防止多线程竞态条件
    dispatch_source_t localTimer = _heartTimer;
    if (!localTimer) {
        CIMLog(@"⚠️ 心跳定时器不存在，无法更新时间");
        [_heartTimerLock unlock];
        return;
    }
    
    @try {
        // 计算下次随机间隔
        int min = (int)(30 * 0.85);  // 51s
        int max = (int)(30 * 1.25);  // 75s
        
        NSTimeInterval randomInterval = min + arc4random_uniform(max - min + 1);
        
        // 从当前时间开始计算下次执行时间
        dispatch_time_t nextTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(randomInterval * NSEC_PER_SEC));
        
        // 使用本地副本更新定时器，防止竞态
        dispatch_source_set_timer(localTimer,
                                  nextTime,
                                  DISPATCH_TIME_FOREVER,
                                  0);
        
#ifdef DEBUG
        CIMLog(@"下次心跳将在 %.0f 秒后执行", randomInterval);
#endif
        
    } @catch (NSException *exception) {
        CIMLog(@"❌ 更新心跳时间异常: %@", exception);
        // 异常情况下使用默认间隔，仍使用本地副本
        dispatch_time_t defaultTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC));
        dispatch_source_set_timer(localTimer, defaultTime, DISPATCH_TIME_FOREVER, 0);
    }
    
    [_heartTimerLock unlock];
}

#pragma mark - 发送心跳消息❤️❤️❤️❤️❤️❤️
- (void)sendSocketPingMessage {
    if (!self.isECDHCompleted) {
        CIMLog(@"心跳消息未发送，原因:ecdh密钥交换未成功");
        return;
    }
    
    if (!self.novDecryptorManager.shareKey || self.novDecryptorManager.shareKey.length == 0) {
        CIMLog(@"心跳消息未发送，原因: shareKey未生成");
        return;
    }
    
    if (self.connectState != LingIMSocketConnectStateConnected) return;
    
    if (_heartNoPongCount >= LingIMHeartFailureCount) {
        
        //如果服务器长时间不响应心跳，则应执行重连机制
        [self disconnectSocket];
        
        CIMLog(@"==========startingSocketReconnect");
        
        //重连机制(此处不需要给网络监听时间)
        [self startingSocketReconnect];
        
        [SOCKETMANAGERTOOL cimConnectFailWithError:nil];
        
        return;
    }
    
    //自增一次
    _heartNoPongCount++;
    
    //配置Ping消息
    IMPingMessage *pingMessage = [[IMPingMessage alloc] init];
    pingMessage.userId = _socketUserID.length == 0 ? @"" : _socketUserID;
    pingMessage.msgId = [[NoaIMManagerTool sharedManager] getMessageID];
    //配置消息
    IMMessage *message = [[IMMessage alloc] init];
    message.dataType = IMMessage_DataType_ImpingMessage;
    message.pingMessage = pingMessage;
    int randomNumber = 10 + arc4random_uniform(991);
    //发送心跳消息
    [self sendSocketMessage:message tag:randomNumber];
    
    CIMLog(@"发送Ping消息");
}

#pragma mark - 停止心跳机制❤️❤️❤️❤️❤️❤️
- (void)stopSocketHeartbeat {
    [_heartTimerLock lock];
    if (_heartTimer) {
        dispatch_source_cancel(_heartTimer);
        _heartTimer = nil;
        CIMLog(@"✅ 心跳定时器已停止");
    }
    [_heartTimerLock unlock];
}

#pragma mark - 重置未收到Pong响应次数❤️❤️❤️❤️❤️❤️
- (void)resetSocketHeartNoPongCount {
    _heartNoPongCount = 0;
}

- (void)cancelForegroundConnectionProbe {
    dispatch_async(self.internalQueue, ^{
        self.foregroundProbeSequence++;
        self.foregroundProbeMessageID = nil;
        [NoaLocalLogger info:@"[TCP重连链路] stage=FOREGROUND_PROBE_CANCEL reason=background"];
    });
}

- (void)completeForegroundConnectionProbeWithMessageID:(NSString *)messageID {
    dispatch_async(self.internalQueue, ^{
        if (messageID.length == 0 || ![self.foregroundProbeMessageID isEqualToString:messageID]) return;
        self.foregroundProbeMessageID = nil;
        self.foregroundProbeSequence++;
        [NoaLocalLogger info:@"[TCP重连链路] stage=FOREGROUND_PROBE_SUCCESS"];
    });
}

- (void)verifyConnectionOnForeground {
    dispatch_async(self.internalQueue, ^{
        NSUInteger probeSequence = ++self.foregroundProbeSequence;
        self.foregroundProbeMessageID = nil;
        // 回前台主动读取网络状态，不依赖一定收到网络变化通知。
        self.isReachable = [[NetWorkStatusManager shared] getConnectStatus];
        self.isCanConnectNet = self.isReachable;
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=FOREGROUND_CHECK online=%d allow=%d state=%ld", self.isCanConnectNet, self.isCanReconnect, (long)self.connectState]];
        if (!self.isCanReconnect || self.socketUserID.length == 0) return;
        if (!self.isCanConnectNet) {
            [self cleanForNetworkLoss];
            return;
        }
        if (self.connectState == LingIMSocketConnectStateDisconnected) {
            [self startingSocketReconnect];
            return;
        }
        // 建连/ECDH/AUTH 中沿用各阶段原有超时，不重复建立连接。
        if (self.connectState == LingIMSocketConnectStateConnecting) return;
        if (!self.gcdSocket.isConnected || !self.isECDHCompleted) {
            [self disconnectSocket];
            [self startingSocketReconnect];
            return;
        }
        NSString *messageID = NSUUID.UUID.UUIDString;
        self.foregroundProbeMessageID = messageID;
        NSUInteger connectionSequence = self.connectionSequence;
        IMPingMessage *ping = [IMPingMessage new];
        ping.userId = self.socketUserID;
        ping.msgId = messageID;
        IMMessage *message = [IMMessage new];
        message.dataType = IMMessage_DataType_ImpingMessage;
        message.pingMessage = ping;
        [NoaLocalLogger info:@"[TCP重连链路] stage=FOREGROUND_PROBE_BEGIN timeout=5"];
        [self sendSocketMessage:message tag:LingIMHeartTag];
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), self.internalQueue, ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.foregroundProbeSequence != probeSequence ||
                self.connectionSequence != connectionSequence ||
                ![self.foregroundProbeMessageID isEqualToString:messageID] || !self.isCanReconnect) return;
            self.foregroundProbeMessageID = nil;
            self.isReachable = [[NetWorkStatusManager shared] getConnectStatus];
            self.isCanConnectNet = self.isReachable;
            [NoaLocalLogger info:@"[TCP重连链路] stage=FOREGROUND_PROBE_TIMEOUT action=reconnect"];
            if (!self.isCanConnectNet) {
                [self cleanForNetworkLoss];
                return;
            }
            [self disconnectSocket];
            [self startingSocketReconnect];
        });
    });
}

/// 清理接收缓冲区
- (void)cleanupReceiveBuffers {
    // 清理主接收缓冲区
    if (_receiveData.length > 0) {
        CIMLog(@"[重连清理] 清理主接收缓冲区，原长度:%lu字节", (unsigned long)_receiveData.length);
        [_receiveData setLength:0];
    }
    
    // 清理帧缓冲区
    if (_frameBuffer.length > 0) {
        CIMLog(@"[重连清理] 清理帧缓冲区，原长度:%lu字节", (unsigned long)_frameBuffer.length);
        [_frameBuffer setLength:0];
    }
}

#pragma mark - 停止重连机制🔗🔗🔗🔗🔗🔗
- (void)stopSocketReconnectWithReason:(NSString *)reason {
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=STOP_RECONNECT_REQUEST reason=%@", reason]];
    void (^stop)(void) = ^{
        self.reconnectSequence += 1;
        self.connectionSequence += 1;
        self.reconnectScheduled = NO;
        [self cancelPendingTcpRaceWithReason:reason];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        if ([reason isEqualToString:@"network_lost"]) {
            // 断网取消的在途尝试没有得到失败结果，恢复网络后仍保留这次机会。
            if (self.initializationReconnectPending && self.initializationReconnectAttempts > 0) {
                self.initializationReconnectAttempts--;
                self.initializationReconnectPending = NO;
            }
            self.reconnectAttemptPending = NO; // 断网中断的轮次不算一次服务器连接失败。
            self.reconnectFailureReason = nil;
        }
        // 单次失败及断网只取消任务，不重置退避；成功或主动终止才重置。
        if (!self.isCanReconnect || [reason isEqualToString:@"auth_success"] ||
            [reason isEqualToString:@"guest_ready"] || [reason isEqualToString:@"user_changed"]) {
            self.reconnectCount = 0;
            [self resetReconnectFailureNotice];
        }
    };
    if (dispatch_get_specific(NoaSocketQueueKey) == (__bridge void *)self) stop();
    else dispatch_async(self.internalQueue, stop);
}

#pragma mark - 处理接收到的数据信息
- (void)dealReceiveData:(int32_t)headLength contentLength:(int32_t)contentLength {
    // 检查范围是否越界
    if (headLength + contentLength > _receiveData.length) {
        CIMLog(@"数据越界");
        return;
    }
    //本次解析data的范围
    NSRange range = NSMakeRange(0, headLength + contentLength);
    //本次解析的data
    NSData *data = [_receiveData subdataWithRange:range];
    
    GPBCodedInputStream *inputStream = [GPBCodedInputStream streamWithData:data];
    
    NSError *error;
    IMMessage *obj = [IMMessage parseDelimitedFromCodedInputStream:inputStream extensionRegistry:nil error:&error];
    
    if (!error){
        //保存解析正确的模型对象
        if (obj) {
            CIMLog(@"[TCP请求追踪] 📨 成功解析消息，类型:%d", obj.dataType);
            [SOCKETMANAGERTOOL receiveMessageDealWith:obj];
        }
        //移出已经解析过的data - 增加防越界判断
        if (range.location + range.length <= _receiveData.length) {
            [_receiveData replaceBytesInRange:range withBytes:NULL length:0];
        }
    } else {
        //移出已经解析过的data - 增加防越界判断
        if (range.location + range.length <= _receiveData.length) {
            [_receiveData replaceBytesInRange:range withBytes:NULL length:0];
        }
        CIMLog(@"[TCP请求追踪] ❌ 消息解析失败: %@", error);
        return;
    }

    
    if (_receiveData.length < 1) return;
    
    //对于粘包情况下被合并的多条消息，循环递归直至解析完所有消息
    headLength = 0;
    contentLength = [[NoaIMManagerTool sharedManager] getMessageContentLenght:_receiveData withHeaderLength:&headLength];
    
    
    //实际包不足解析，继续接收下一个包
    if (headLength + contentLength > _receiveData.length) return;
    
    
    //继续解析下一条
    [self dealReceiveData:headLength contentLength:contentLength];
}

#pragma mark - GET
- (GCDAsyncSocket *)gcdSocket {
    if (!_gcdSocket) {
        _gcdSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        _gcdSocket.IPv4Enabled = YES;
        _gcdSocket.IPv6Enabled = YES;
        _gcdSocket.IPv4PreferredOverIPv6 = NO;
    }
    return _gcdSocket;
}

#pragma mark - 网络质量检测相关方法

/// 检查是否有最优节点可用
- (BOOL)hasOptimalServerAvailable {
    // 检查代理对象是否存在
    if (!self.hasOptimalServerAvailableBlock) {
        return NO;
    }
    return self.hasOptimalServerAvailableBlock();
}

/// 获取最优服务器节点信息
- (NSDictionary *)getOptimalServerInfo {
    if (!self.getOptimalServerInfoBlock) {
        return nil;
    }
    // 如果没有实现hasOptimalServerAvailable方法，则通过getOptimalServerInfo来判断
    NSDictionary *serverInfo = self.getOptimalServerInfoBlock();
    return serverInfo;
}

/// 使用最优节点进行连接
- (void)connectWithOptimalServer {
    NSDictionary *serverInfo = [self getOptimalServerInfo];
    if (!serverInfo) {
        [NoaLocalLogger info:@"[网络检测] 没有可用的最优节点，使用原有连接逻辑"];
        [self startSocketConnect];
        return;
    }
    
    NSString *ip = serverInfo[@"ip"];
    NSNumber *portNumber = serverInfo[@"port"];
    
    if (!ip || ip.length == 0 || !portNumber || portNumber.integerValue <= 0) {
        [NoaLocalLogger info:@"[网络检测] 最优节点信息无效，使用原有连接逻辑"];
        [self startSocketConnect];
        return;
    }
    
    NSInteger port = portNumber.integerValue;
    [NoaLocalLogger info:[NSString stringWithFormat:@"[网络检测] 使用最优节点连接:ip = %@, port = %ld", ip, (long)port]];
    
    // 更新socket连接信息
    self.socketHost = ip;
    self.socketPort = port;

    // 开始连接
    [self startSocketConnect];
}

#pragma mark - 销毁
- (void)dealloc {
    [self stopSocketHeartbeat];
    [self stopSocketReconnectWithReason:@"dealloc"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - <GCDAsyncSocketDelegate>
//socket连接成功的回调
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=TCP_CONNECTED host=%@ port=%u", host, port]];
    [NoaLocalLogger info:[NSString stringWithFormat:@"[socket] 收到连接成功回调(建立socket连接)，地址：%@端口：%u", host, port]];
    [self recordInitializationSentryStage:@"tcp_connected" result:@YES reason:nil];

    // 延迟一点时间确保连接完全建立
    if (kEncryptionEnabled) {
        if (self.isKeyExchangeInProgress) {
            return;
        }
        self.isKeyExchangeInProgress = YES;
        [NoaLocalLogger info:@"[socket] socket连接成功，准备启动ECDH密钥交换"];
        [self recordInitializationSentryStage:@"ecdh_started" result:nil reason:nil];
        
        NSUInteger connectionSequence = self.connectionSequence;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kInitialDelayAfterConnect * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (connectionSequence != self.connectionSequence || !self.isCanReconnect ||
                !self.isCanConnectNet || !sock.isConnected) return;
            // 连接成功后，开始读取数据
            [self.gcdSocket readDataWithTimeout:-1 tag:0];
            
            // 启动ECDH密钥交换超时定时器
            [self startKeyExchangeTimer];
            
            // 启动ECDH密钥交换
            [self startKeyExchangeProcess];
        });
    }
}

//socket连接失败的回调
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    BOOL disconnectedDuringAuth = self.isAuthPhaseActive;
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=SOCKET_DISCONNECTED host=%@ port=%ld error=%ld duringAuth=%d allow=%d", self.socketHost, (long)self.socketPort, (long)err.code, disconnectedDuringAuth, self.isCanReconnect]];
    if (err) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[socket] 断开了连接，错误码:%ld，原因:%@", (long)err.code, err]];
        
        [self sentryUploadWithEventObj:@{
            @"event" : @"socket连接",
            @"error" : [NSString stringWithFormat:@"socketDidDisconnect回调断开了连接，原因:%@", err],
            @"host" : self.socketHost ? self.socketHost : @"",
            @"port" : @(self.socketPort)
        } errorCode:@""];
        
    }else {
        [NoaLocalLogger info:@"[socket] 断开了连接，原因:客户端主动断开"];
        
        [self sentryUploadWithEventObj:@{
            @"event" : @"socket连接",
            @"error" : @"socketDidDisconnect断开了连接，原因:客户端主动断开",
            @"host" : self.socketHost ? self.socketHost : @"",
            @"port" : @(self.socketPort)
        } errorCode:@""];
    }
    
    [NoaLocalLogger error:@"[邀请码竞速] socketDidDisconnect断开连接"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"socketECDHDidConnectFailure" object:nil];
    
    if (self.reconnectAttemptPending && self.reconnectFailureReason.length == 0 && !disconnectedDuringAuth) {
        self.reconnectFailureReason = self.isKeyExchangeInProgress ? @"ecdh_interrupted" : @"tcp_disconnected";

    }
    // 更新连接状态
    [self updateConnectState:LingIMSocketConnectStateDisconnected];
    
    // 清理相关状态
    [self clearKeyExchangeInfo];
    
    // 停止ECDH密钥交换超时定时器
    [self stopKeyExchangeTimer];
    
    // 清理缓存数据
    [self cleanupReceiveBuffers];
    
    // 停止心跳和重连机制
    [self stopSocketHeartbeat];
    [self stopSocketReconnectWithReason:@"socket_disconnected"];
    
    // 通知上层连接断开了
    [SOCKETMANAGERTOOL cimConnectFailWithError:err];

    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=DISCONNECT_CLEANUP_DONE"]];
    if (disconnectedDuringAuth) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_DISCONNECT action=backoff_reconnect code=999993"]];
        self.authRequestPending = NO;
        self.isAuthPhaseActive = NO;
        self.authRequestSequence += 1;
        [NoaLocalLogger error:@"[AUTH链路] stage=AUTH_SOCKET_DISCONNECTED action=reconnect"];
        [SOCKETMANAGERTOOL finishAuthWithLogoutCode:999993 message:@"连接认证中断，正在重连"];
        return;
    }
    
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=DISCONNECT_TO_RECONNECT"]];
    // 重连机制(给网络监听一点时间)
    [self startingSocketReconnect];
}

//socket接收到数据
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    CIMLog(@"[TCP请求追踪] socket:接收到数据，数据标识:%ld，数据长度:%lu字节", tag, (unsigned long)data.length);
    
    // 数据有效性检查
    if (!data || data.length == 0) {
        CIMLog(@"[TCP请求追踪] ⚠️ 接收到空数据，继续读取");
        [sock readDataWithTimeout:-1 tag:0];
        return;
    }
    
    // 如果需要支持ecdh且当前未完成，则不处理其他数据
    if (!self.isECDHCompleted && kEncryptionEnabled) {
        // 此时没有拿到服务器公钥，则不处理其他数据，但要发送心跳保活
        [self startSocketHeartbeat];
        BOOL isGetServerPublicKeySuccess = [self.novDecryptorManager parseServerPublicKeyMessageSync:data];
        if (isGetServerPublicKeySuccess) {
            [NoaLocalLogger info:@"[Socket-ECDH] 获取服务器公钥成功，开始生成共享密钥..."];
            
            BOOL isGetShareKeySuccess = [self.novDecryptorManager generateSharedSecret];
            if (isGetShareKeySuccess) {
                [NoaLocalLogger info:@"[Socket-ECDH] 生成共享密钥成功！ECDH密钥交换完成"];
                
                // 标记ECDH完成↓
                self.isKeyExchangeInProgress = NO;
                self.isECDHCompleted = YES;
                [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=ECDH_SUCCESS"]];
                [self recordInitializationSentryStage:@"ecdh_succeeded" result:@YES reason:nil];
                
                // 停止ECDH密钥交换超时定时器
                [self stopKeyExchangeTimer];
                // 标记ECDH完成↑
                
                BOOL hasSocketUserID = _socketUserID.length > 0;
                BOOL hasSocketUserToken = _socketUserToken.length > 0;
                BOOL isGuestBootstrapConnection = !hasSocketUserID && !hasSocketUserToken;

                [SOCKETMANAGERTOOL prepareForAuthPhase];
                SOCKETMANAGERTOOL.isTokenExpired = NO;
                SOCKETMANAGERTOOL.isTokenRefreshing = NO;
                SOCKETMANAGERTOOL.hasRetriedAuthAfterTokenRefresh = NO;
                [self stopSocketReconnectWithReason:@"ecdh_success"];
                // 安全传输层已建立；后续认证或系统配置失败不属于网络连接失败。
                [self resetReconnectFailureNotice];

                if (isGuestBootstrapConnection) {
                    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_SKIP reason=guest_bootstrap"]];
                    // 邀请码和登录前初始化没有用户凭证，只需要 ECDH 传输层发送未登录 systemConfig。
                    // 此分支不能标记 isAuth，也不能触发用户登录成功及首页数据同步。
                    self.authRequestPending = NO;
                    self.isAuthPhaseActive = NO;
                    self.authRequestSequence += 1;
                    self.reconnectCount = 0;
                    [self updateConnectState:LingIMSocketConnectStateConnected];
                    [NoaLocalLogger info:@"[AUTH链路] stage=GUEST_BOOTSTRAP_READY action=skip_auth_allow_system_config"];
                } else {
                    // 只要存在任一用户凭证就属于登录链路；凭证不完整不能降级成未登录连接。
                    // AUTH 10000 后才会标记业务连接成功并通知首页。
                    self.isAuthPhaseActive = YES;
                    self.authRequestPending = NO;
                    self.authRequestSequence += 1;

                    // 发送用户鉴权信息(鉴权成功后，开始心跳机制)
                    [self authSocketUser];

                    // 用户资料尚未配置完整时 AUTH 无法立即发送，仍以 10 秒为上限等待配置完成。
                    if (!self.authRequestPending) {
                        NSUInteger prerequisiteSequence = self.authRequestSequence;
                        __weak typeof(self) weakSelf = self;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), self.internalQueue, ^{
                            __strong typeof(weakSelf) self = weakSelf;
                            if (!self || !self.isAuthPhaseActive || self.authRequestPending || self.authRequestSequence != prerequisiteSequence) {
                                return;
                            }
                            [NoaLocalLogger error:@"[AUTH链路] stage=AUTH_PREREQUISITE_TIMEOUT timeoutSeconds=10 action=reconnect"];
                            [SOCKETMANAGERTOOL finishAuthWithLogoutCode:999994 message:@"连接认证信息不完整，正在重连"];
                        });
                    }
                }
                
                [NoaLocalLogger info:@"[邀请码竞速] ECDH交换,通知连接成功"];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"socketECDHDidConnectSuccese" object:nil];
                
                //持续获取消息，需要调用此方法(因为socket就是这么设计的)
                [_gcdSocket readDataWithTimeout:-1 tag:0];
                return;
            }else {
                self.reconnectFailureReason = @"ecdh_shared_secret_failed";
                [NoaLocalLogger error:@"[Socket-ECDH] 生成共享密钥失败，开始断开重连..."];
                
                [self sentryUploadWithEventObj:@{
                    @"event" : @"socket连接 - ECDH",
                    @"error" : @"生成共享密钥失败，开始断开重连...",
                    @"host" : self.socketHost ? self.socketHost : @"",
                    @"port" : @(self.socketPort)
                } errorCode:@""];
                
                [self handleKeyExchangeFailure];
                return;
            }
        }else {
            self.reconnectFailureReason = @"ecdh_server_key_invalid";
            [NoaLocalLogger error:@"[Socket-ECDH] 获取服务器公钥失败，开始断开重连..."];
            
            [self sentryUploadWithEventObj:@{
                @"event" : @"socket连接 - ECDH",
                @"error" : @"获取服务器公钥失败，开始断开重连...",
                @"host" : self.socketHost ? self.socketHost : @"",
                @"port" : @(self.socketPort)
            } errorCode:@""];
            
            [self handleKeyExchangeFailure];
            return;
        }
    }
    
    [self processEnhancedFrameProtocolData:data];
    
    // 持续获取消息，需要调用此方法(因为socket就是这么设计的)
    [sock readDataWithTimeout:-1 tag:0];
}

#pragma mark - 增强帧协议数据处理

/// 处理协议数据
/// @param data 接收到的原始数据
- (void)processEnhancedFrameProtocolData:(NSData *)data {
    if (!data || data.length == 0) {
        CIMLog(@"[帧协议] ❌ 接收数据为空");
        return;
    }
    
    // 将新数据添加到缓冲区
    [self.frameBuffer appendData:data];
    CIMLog(@"[帧协议] 📥 数据已添加到缓冲区，当前长度:%lu字节", (unsigned long)self.frameBuffer.length);
    
    // 循环处理缓冲区中的数据
    [self processFrameBuffer];
}

/// 处理帧缓冲区中的数据
- (void)processFrameBuffer {
    while (self.frameBuffer.length >= MESSAGE_FRAME_HEADER_SIZE) {
        // 查找消息头
        NSUInteger headerPosition = [self findMessageFrameHeader];
        
        if (headerPosition == NSNotFound) {
            // 未找到有效的消息头，逐字节移动查找
            if (self.frameBuffer.length > 1) {
                // 移除第一个字节，继续查找
                [self.frameBuffer replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
                CIMLog(@"🔄 未找到有效消息头，移除1字节继续查找，剩余%lu字节", (unsigned long)self.frameBuffer.length);
                // 继续循环处理
                continue;
            } else {
                // 缓冲区只剩1字节或为空，无法继续查找
                CIMLog(@"🔄 缓冲区数据不足，等待更多数据");
                break;
            }
        }
        
        // 如果消息头不在开头，丢弃消息头之前的数据
        if (headerPosition > 0) {
            NSData *validData = [self.frameBuffer subdataWithRange:NSMakeRange(headerPosition, self.frameBuffer.length - headerPosition)];
            // ✅ 改进：使用 replaceBytesInRange 代替 setLength:0 + appendData，避免中间状态
            if (validData && validData.length > 0) {
                [self.frameBuffer replaceBytesInRange:NSMakeRange(0, headerPosition) withBytes:NULL length:0];
                CIMLog(@"🔄 消息头不在开头，丢弃前%lu字节数据", (unsigned long)headerPosition);
            } else {
                // 如果没有有效数据，直接清空
                [self.frameBuffer setLength:0];
                CIMLog(@"⚠️ 移除无效数据后缓冲区为空");
                break;
            }
        }
        
        // 尝试解析完整的消息帧
        NSData *completeFrame = [self extractCompleteFrame];
        if (completeFrame) {
            // 成功提取到完整帧，进行解密处理
            [self decryptAndProcessFrame:completeFrame];
        } else {
            // 数据不完整，等待更多数据
            CIMLog(@"🔄 消息数据不完整，等待更多数据中....");
            break;
        }
    }
    
    // 添加退出循环的日志
    if (self.frameBuffer.length < MESSAGE_FRAME_HEADER_SIZE) {
        CIMLog(@"⚠️ 缓冲区数据不足，退出处理");
    }
}

/// 查找消息帧头位置
/// @return 消息帧头的位置，如果未找到返回NSNotFound
- (NSUInteger)findMessageFrameHeader {
    if (self.frameBuffer.length < MESSAGE_FRAME_HEADER_SIZE) {
        return NSNotFound;
    }
    
    // 检查 frameBuffer.bytes 是否为 NULL
    const uint8_t *bytes = (const uint8_t *)self.frameBuffer.bytes;
    if (!bytes) {
        CIMLog(@"❌ [帧协议] frameBuffer.bytes 为 NULL，length=%lu", (unsigned long)self.frameBuffer.length);
        return NSNotFound;
    }
    
    NSUInteger dataLength = self.frameBuffer.length;
    
    // 获取期望的帧头标识（AES密钥的前8字节）- 使用安全方法
    NSData *expectedFrameIdentifier = [self.novDecryptorManager getFrameIdentifier];
    if (!expectedFrameIdentifier) {
        CIMLog(@"❌ 无法获取帧标识符，shareKey未准备好");
        return NSNotFound;
    }
    
    // 检查 expectedFrameIdentifier.bytes 是否为 NULL
    const uint8_t *expectedBytes = (const uint8_t *)expectedFrameIdentifier.bytes;
    if (!expectedBytes || expectedFrameIdentifier.length < 8) {
        CIMLog(@"❌ [帧协议] expectedFrameIdentifier.bytes 为 NULL 或长度不足，length=%lu", (unsigned long)expectedFrameIdentifier.length);
        return NSNotFound;
    }
    
    // 搜索帧头标识
    for (NSUInteger i = 0; i <= dataLength - MESSAGE_FRAME_HEADER_SIZE; i++) {
        // 比较帧头标识（前8字节）
        BOOL isHeaderMatch = YES;
        for (NSUInteger j = 0; j < 8; j++) {
            if (bytes[i + j] != expectedBytes[j]) {
                isHeaderMatch = NO;
                break;
            }
        }
        
        if (isHeaderMatch) {
            // 验证消息体长度字段的合理性
            uint32_t messageBodyLength = CFSwapInt32BigToHost(*(uint32_t *)(bytes + i + 8));
            if (messageBodyLength > 0) { // 合理的消息体长度范围
                CIMLog(@"✅ 找到有效消息头，位置:%lu，消息体长度:%u", (unsigned long)i, messageBodyLength);
                return i;
            }
        }
    }
    
    CIMLog(@"❌ 未找到有效消息头， %@", self.frameBuffer);
    return NSNotFound;
}

/// 提取完整的消息帧
/// @return 完整的消息帧数据，如果数据不完整返回nil
- (NSData *)extractCompleteFrame {
    if (self.frameBuffer.length < MESSAGE_FRAME_HEADER_SIZE) {
        return nil;
    }
    
    // 检查 frameBuffer.bytes 是否为 NULL
    const uint8_t *bytes = (const uint8_t *)self.frameBuffer.bytes;
    if (!bytes) {
        CIMLog(@"❌ [帧协议] extractCompleteFrame: frameBuffer.bytes 为 NULL，length=%lu", (unsigned long)self.frameBuffer.length);
        return nil;
    }
    
    // 读取消息体长度
    uint32_t messageBodyLength = CFSwapInt32BigToHost(*(uint32_t *)(bytes + 8));
    
    // 计算完整帧的长度：消息头 + 消息体 + 扰乱数据
    // 扰乱数据长度 = 总数据长度 - 消息头长度 - 消息体长度
    NSUInteger totalFrameLength = MESSAGE_FRAME_HEADER_SIZE + messageBodyLength;
    
    // 检查是否有足够的数据
    if (self.frameBuffer.length < totalFrameLength) {
        CIMLog(@"⏳ 数据不完整，需要%lu字节，当前有%lu字节",
               (unsigned long)totalFrameLength, (unsigned long)self.frameBuffer.length);
        return nil;
    }
    
    // 提取完整帧数据
    NSData *completeFrame = [self.frameBuffer subdataWithRange:NSMakeRange(0, totalFrameLength)];
    
    // 从缓冲区中移除已处理的数据
    [self.frameBuffer replaceBytesInRange:NSMakeRange(0, totalFrameLength) withBytes:NULL length:0];
    
    CIMLog(@"📦 提取完整帧，长度:%lu字节", (unsigned long)completeFrame.length);
    return completeFrame;
}

/// 解密并处理消息帧
/// @param frameData 完整的消息帧数据
- (void)decryptAndProcessFrame:(NSData *)frameData {
    if (!frameData || frameData.length == 0) {
        CIMLog(@"❌ 消息帧数据为空");
        return;
    }
    
    CIMLog(@"🔓 开始解密消息帧，长度:%lu字节", (unsigned long)frameData.length);
    
    // 使用增强帧协议解密
    NSData *decryptedData = [self.novDecryptorManager parseEnhancedFrameProtocolMessage:frameData];
    
    if (decryptedData) {
        CIMLog(@"✅ 消息解密成功，解密后长度:%lu字节", (unsigned long)decryptedData.length);
        
        // 将解密后的数据添加到接收缓冲区进行处理
        [self appendToReceiveBuffer:decryptedData];
        
        // 处理接收缓冲区中的数据
        [self processReceiveBuffer];
    } else {
        CIMLog(@"❌ 消息解密失败，忽略当前帧");
        // 解密失败时，继续处理缓冲区中的下一个消息
        [self processFrameBuffer];
    }
}

#pragma mark - 接收缓冲区管理

- (void)appendToReceiveBuffer:(NSData *)data {
    if (!data || data.length == 0) {
        return;
    }
    
    [_receiveData appendData:data];
    CIMLog(@"[TCP请求追踪] 📥 数据已添加到接收缓冲区，当前缓冲区大小:%lu字节", (unsigned long)_receiveData.length);
}

- (void)processReceiveBuffer {
    if (_receiveData.length < 1) {
        return;
    }
    
    // 循环处理缓冲区中的所有完整消息
    while (_receiveData.length > 0) {
        // 获取消息头长度
        int32_t headLength = 0;
        int32_t contentLength = [[NoaIMManagerTool sharedManager] getMessageContentLenght:_receiveData withHeaderLength:&headLength];
        
        // 检查数据完整性
        if (contentLength < 1 || headLength < 0) {
            CIMLog(@"[TCP请求追踪] ⚠️ 消息头解析失败，清空缓冲区");
            [_receiveData setLength:0];
            break;
        }
        
        // 检查是否有完整的消息
        if (headLength + contentLength > _receiveData.length) {
            CIMLog(@"[TCP请求追踪] ⏳ 数据包不完整，等待更多数据。需要:%d字节，当前有:%lu字节",
                   headLength + contentLength, (unsigned long)_receiveData.length);
            break;
        }
        
        // 处理完整的消息
        [self dealReceiveData:headLength contentLength:contentLength];
    }
}

#pragma mark - 密钥交换方法

- (void)startKeyExchangeProcess {
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=ECDH_BEGIN"]];
    [NoaLocalLogger info:[NSString stringWithFormat:@"[Socket-ECDH] startKeyExchangeProcess 开始 [当前线程: %@]", [NSThread isMainThread] ? @"主线程" : @"后台线程"]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NoaLocalLogger info:@"[Socket-ECDH] 开始ECDH密钥交换流程 [后台队列]"];
        
        [self.novDecryptorManager generateKeyPairWithComplete:^(SecKeyRef  _Nonnull publicKey, SecKeyRef  _Nonnull privateKey) {
            if (!publicKey || !privateKey) {
                [NoaLocalLogger error:@"[Socket-ECDH] ❌ 生成密钥对失败，立即断开重连"];
                
                [self sentryUploadWithEventObj:@{
                    @"event" : @"socket连接 - ECDH",
                    @"error" : @"生成密钥对失败，立即断开重连",
                    @"host" : self.socketHost ? self.socketHost : @"",
                    @"port" : @(self.socketPort)
                } errorCode:@""];
                
                self.reconnectFailureReason = @"ecdh_prepare_failed";
                [self handleKeyExchangeFailure];
                return;
            }
            
            [NoaLocalLogger info:@"[Socket-ECDH] 密钥对生成成功 [后台队列]"];
            [self recordInitializationSentryStage:@"ecdh_keypair_ready" result:@YES reason:nil];
            
            NSData *publicKeyBase64Data = [self.novDecryptorManager secKeyRefToData:publicKey];
            NSData *sendData = [self.novDecryptorManager buildServerPublicKeyRequestMessage:publicKeyBase64Data];
            
            [NoaLocalLogger info:[NSString stringWithFormat:@"[Socket-ECDH] 准备切换到主队列发送数据 (公钥大小: %lu bytes)", (unsigned long)sendData.length]];
            
            // TODO: writeData 调度回主队列（GCDAsyncSocket 的 delegateQueue） 原因：GCDAsyncSocket 要求所有操作在 delegateQueue 上调用，避免竞态条件
            dispatch_async(dispatch_get_main_queue(), ^{
                [NoaLocalLogger info:@"[Socket-ECDH] 已切换到主队列，检查连接状态..."];
                
                // 再次检查socket状态，确保连接有效
                if (self.gcdSocket && self.gcdSocket.isConnected) {
                    [NoaLocalLogger info:@"[Socket-ECDH] Socket已连接，发送公钥到服务器 [主队列]"];
                    [self.gcdSocket writeData:sendData withTimeout:-1 tag:0];
                    [NoaLocalLogger info:@"[Socket-ECDH] writeData 调用完成，等待服务器响应..."];
                    [self recordInitializationSentryStage:@"ecdh_public_key_write_requested" result:@YES reason:nil];
                } else {
                    self.reconnectFailureReason = @"ecdh_interrupted";
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[Socket-ECDH] Socket未连接(isConnected=%@)，无法发送公钥，立即断开重连",
                                   self.gcdSocket.isConnected ? @"YES" : @"NO"]];
                    [self handleKeyExchangeFailure];
                }
            });
        }];
    });
}

#pragma mark - ECDH密钥交换超时处理

/// 启动ECDH密钥交换超时定时器
- (void)startKeyExchangeTimer {
    [self stopKeyExchangeTimer]; // 先停止之前的定时器
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.keyExchangeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (self.keyExchangeTimer) {
        dispatch_source_set_timer(self.keyExchangeTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKeyExchangeTimeout * NSEC_PER_SEC)),
                                  DISPATCH_TIME_FOREVER,
                                  0);
        
        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(self.keyExchangeTimer, ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [NoaLocalLogger error:[NSString stringWithFormat:@"[Socket-ECDH] 密钥交换超时(%.1f秒)，立即断开重连", kKeyExchangeTimeout]];
            self.reconnectFailureReason = @"ecdh_timeout";
            [self recordInitializationSentryStage:@"ecdh_timeout" result:@NO reason:@"key_exchange_timeout"];
            
            [self handleKeyExchangeFailure];
        });
        
        dispatch_resume(self.keyExchangeTimer);
        [NoaLocalLogger info:[NSString stringWithFormat:@"[Socket-ECDH] 密钥交换超时定时器启动，超时时间:%.1f秒", kKeyExchangeTimeout]];
    }
}

/// 停止ECDH密钥交换超时定时器
- (void)stopKeyExchangeTimer {
    if (self.keyExchangeTimer) {
        dispatch_source_cancel(self.keyExchangeTimer);
        self.keyExchangeTimer = nil;
        [NoaLocalLogger info:@"[Socket-ECDH] 停止密钥交换超时定时器"];
    }
}

/// 处理ECDH密钥交换失败
- (void)handleKeyExchangeFailure {
    if (self.reconnectFailureReason.length == 0) self.reconnectFailureReason = @"ecdh_interrupted";
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=ECDH_FAILURE action=disconnect_reconnect"]];
    [NoaLocalLogger error:@"[Socket-ECDH] 密钥交换失败，立即断开连接并重连"];
    
    [self sentryUploadWithEventObj:@{
        @"event" : @"socket连接 - ECDH",
        @"error" : @"密钥交换失败，立即断开连接并重连",
        @"host" : self.socketHost ? self.socketHost : @"",
        @"port" : @(self.socketPort)
    } errorCode:@""];
    
    // 停止ECDH密钥交换超时定时器
    [self stopKeyExchangeTimer];
    
    // 重置ECDH相关状态
    [self clearKeyExchangeInfo];
    
    // 清除缓存数据
    [self cleanupReceiveBuffers];
    
    // 强制断开连接
    [self disconnectSocket];
}

/// 重置ECDH相关状态
- (void)clearKeyExchangeInfo {
    self.isKeyExchangeInProgress = NO;
    self.isECDHCompleted = NO;
    self.novDecryptorManager.shareKey = nil;
    self.novDecryptorManager.serverPublicKeyData = nil;
    SOCKETMANAGERTOOL.isAuth = NO;
}

// MARK: SENTRY
- (void)sentryUploadWithEventObj:(id)eventObj
                       errorCode:(NSString *)errorCode {
    NSString *stage = @"socket_failed";
    NSString *reason = @"socket_unknown_failure";
    if ([eventObj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *eventDictionary = (NSDictionary *)eventObj;
        NSString *event = eventDictionary[@"event"];
        NSString *error = eventDictionary[@"error"];
        if (event.length > 0) stage = event;
        if (error.length > 0) reason = error;
    } else if ([eventObj isKindOfClass:[NSString class]] && [(NSString *)eventObj length] > 0) {
        reason = (NSString *)eventObj;
    }
    [self recordInitializationSentryStage:stage result:@NO reason:reason];
}

#pragma mark - Initialization Sentry Trace

/// 开始新的登录前初始化链路，并替换上一次未终结的内存记录。
- (void)beginInitializationSentryTrace {
    @synchronized (self) {
        self.initializationConnectionAttemptId = NSUUID.UUID.UUIDString;
        self.initializationSentryStages = [NSMutableArray array];
        self.initializationSentryStartTime = CACurrentMediaTime();
        self.isInitializationSentryTraceActive = YES;
        self.isInitializationSentryTraceFinalized = NO;
        [self recordInitializationSentryStage:@"node_race_started" result:nil reason:nil];
    }
}

/// 记录一个初始化阶段及其耗时；该记录只保留在内存中，直到失败终结。
- (void)recordInitializationSentryStage:(NSString *)stage
                                 result:(NSNumber *)result
                                 reason:(NSString *)reason {
    if (stage.length == 0) return;
    @synchronized (self) {
        if (!self.isInitializationSentryTraceActive || self.isInitializationSentryTraceFinalized) return;
        NSMutableDictionary *entry = [@{
            @"stage": stage,
            @"elapsedMs": @((NSInteger)((CACurrentMediaTime() - self.initializationSentryStartTime) * 1000)),
            @"host": self.socketHost ?: @"",
            @"port": @(self.socketPort)
        } mutableCopy];
        if (result != nil) entry[@"result"] = result.boolValue ? @"passed" : @"failed";
        if (reason.length > 0) entry[@"failureReason"] = reason;
        [self.initializationSentryStages addObject:entry];
    }
}

/// 记录初始化失败终点；最终 Sentry 汇总由 App 侧竞速管理器在全部链路失败后决定。
- (void)captureInitializationSentryFailureAtStage:(NSString *)stage
                                            reason:(NSString *)reason
                                         errorCode:(NSString *)errorCode {
    @synchronized (self) {
        if (!self.isInitializationSentryTraceActive || self.isInitializationSentryTraceFinalized) return;
        [self recordInitializationSentryStage:stage result:@NO reason:reason];
        self.isInitializationSentryTraceFinalized = YES;
        (void)errorCode;
        self.isInitializationSentryTraceActive = NO;
        self.initializationSentryStages = nil;
    }
}

/// 终结一次成功初始化并清理内存步骤，确保成功路径不上传 Sentry。
- (void)completeInitializationSentryTrace {
    @synchronized (self) {
        self.isInitializationSentryTraceActive = NO;
        self.isInitializationSentryTraceFinalized = NO;
        self.initializationConnectionAttemptId = nil;
        self.initializationSentryStages = nil;
    }
}

//毫秒转换成： 03:23
- (NSString *)transSecondToTimeStr {
    NSDate *date = [NSDate date];
    NSInteger time = [date timeIntervalSince1970];
    //时
    NSString *str_hour = [NSString stringWithFormat:@"%02ld", time / 3600];
    //分
    NSString *str_minute = [NSString stringWithFormat:@"%02ld", (time % 3600) / 60];
    //秒
    NSString *str_second = [NSString stringWithFormat:@"%02ld", time % 60];

    NSString *format_time = @"";
    if (![str_hour isEqualToString:@"00"]) {
        format_time = [NSString stringWithFormat:@"%@:%@:%@", str_hour, str_minute, str_second];
    } else {
        format_time = [NSString stringWithFormat:@"%@:%@",str_minute, str_second];
    }
    
    return format_time;
}


@end
