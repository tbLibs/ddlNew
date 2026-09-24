//
//  NoaIMSDKManager+Probe.m
//  NoaChatSDKCore
//
//  ECDH连通性探测（仅握手，不鉴权、不心跳）
//

#import "NoaIMSDKManager+Probe.h"
#import <GCDAsyncSocket.h>
#import "NovDecryptorManager.h"
#import <objc/runtime.h>
#import "NoaLocalLogger.h"
#import <NetworkStatus/NetworkStatus-Swift.h>

// 先声明存储容器，确保在使用前有可见声明
static const void *kLingIMSDKManagerActiveProbesKey = &kLingIMSDKManagerActiveProbesKey;

@interface NoaIMSDKManager (ProbeStorage)
- (NSMutableSet *)_activeProbes;
@end

@interface _LingIMEcdhProbeWrapper : NSObject <GCDAsyncSocketDelegate>

/// tcp对象
@property (nonatomic, strong) GCDAsyncSocket *socket;

/// ECDH探测类型: 0 - 竞速 2-网络探测
@property (nonatomic, assign) NSInteger type;

/// ip
@property (nonatomic, copy) NSString *ip;

/// 端口号
@property (nonatomic, assign) uint16_t port;

/// 队列
@property (nonatomic, strong) dispatch_queue_t queue;

/// 超时时间
@property (nonatomic, assign) NSTimeInterval timeout;

/// 超时计时器
@property (nonatomic, strong) dispatch_source_t timer;

/// 完成回调
@property (nonatomic, copy) void (^completion)(BOOL success, LingIMSDKManagerProbeECDHConnectStatus status);

/// 是否完成
@property (nonatomic, assign) BOOL finished;

/// 密钥交换处理类
@property (nonatomic, strong) NovDecryptorManager *novDecryptorManager;

- (void)probeECDHConnectivityWithHost:(NSString *)host
                                  port:(uint16_t)port
                               timeout:(NSTimeInterval)timeout
                                 type:(NSInteger)type
                            completion:(void(^)(BOOL success, LingIMSDKManagerProbeECDHConnectStatus status))completion;

@end

@implementation _LingIMEcdhProbeWrapper

#pragma mark - dealloc
- (void)dealloc {
    if (self.type == 0) {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] dealloc: host=%@, port=%d", self.ip, self.port]];
    }else {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] dealloc: host=%@, port=%d", self.ip, self.port]];
    }
    [self cleanup];
}

#pragma mark - init
- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.noa.sdkcore.ecdh.probe", DISPATCH_QUEUE_SERIAL);
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_queue];
        _novDecryptorManager = [[NovDecryptorManager alloc] init];
    }
    return self;
}

#pragma mark - 连接交换密钥处理
- (void)startWithHost:(NSString *)host
                 port:(uint16_t)port
              timeout:(NSTimeInterval)timeout
                 type:(NSInteger)type
           completion:(void(^)(BOOL, LingIMSDKManagerProbeECDHConnectStatus))completion {
    if (self.finished) return;
    
    self.ip = host;
    self.port = port;
    
    self.type = type;
    // 参数验证
    if (!host || host.length == 0 || port == 0) {
        if (self.type == 0) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 无效的连接参数: host=%@, port=%d", self.ip, self.port]];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 无效的连接参数: host=%@, port=%d", self.ip, self.port]];
        }
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, LingIMSDKManagerProbeECDHConnectServerFail);
            });
        }
        return;
    }
    self.timeout = timeout > 0 ? timeout : kDefaultRaceTimeOut;
    self.completion = completion;
    
    CIMLog(@"[TCP竞速] 🚀 开始连接服务器: %@:%d, 超时: %.1f秒", host, port, self.timeout);
    
    // 设置超时定时器
    __weak typeof(self) weakSelf = self;
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(self.timer, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.finished) return;
        if (self.type == 0) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ⏰ 连接超时: host=%@, port=%d", self.ip, self.port]];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ⏰ 连接超时: host=%@, port=%d", self.ip, self.port]];
        }
        CIMLog();
        [self finish:NO status:LingIMSDKManagerProbeECDHConnectTimeout];
    });
    dispatch_resume(self.timer);
    
    // 开始连接
    NSError *err = nil;
    [self.socket connectToHost:host onPort:port withTimeout:self.timeout error:&err];
    if (err) {
        if (self.type == 0) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 连接失败: %@, host=%@, port=%d", err.localizedDescription, self.ip, self.port]];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 连接失败: %@, host=%@, port=%d", err.localizedDescription, self.ip, self.port]];
        }
        [self finish:NO status:LingIMSDKManagerProbeECDHConnectServerFail];
    }
}

- (void)finish:(BOOL)success
        status:(LingIMSDKManagerProbeECDHConnectStatus)status {
    if (self.finished) return;
    
    self.finished = YES;
    void (^cb)(BOOL, LingIMSDKManagerProbeECDHConnectStatus) = self.completion;
    
    if (self.type == 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] 🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁 密钥交换流程结束，结果: %@, host=%@, port=%d", success ? @"成功" : @"失败", self.ip, self.port]];
    }else {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志]  🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁🏁 密钥交换流程结束，结果: %@, host=%@, port=%d", success ? @"成功" : @"失败", self.ip, self.port]];
    }
    
    // 先清理资源
    [self cleanup];
    
    // 然后通知上层
    if (cb) {
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(success, status);
        });
    }
}

- (void)cleanup {
    // 清理定时器
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    
    // 清理socket连接
    if (self.socket) {
        if (self.socket.isConnected) {
            [self.socket disconnect];
        }
        self.socket.delegate = nil;
        self.socket = nil;
    }
    
    // 清理回调
    self.completion = nil;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if (self.finished) return;
    
    if (self.type == 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] 连接成功，开始密钥交换流程，ip:%@, 端口号:%d", self.ip, self.port]];
    }else {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] 连接成功，开始密钥交换流程，ip:%@, 端口号:%d", self.ip, self.port]];
    }
    
    // 连接成功后立即开始密钥交换流程
    [self startKeyExchangeProcess];
}

//socket接收到数据
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (self.finished) return;
    
    if (self.type == 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] 📥 接收到数据，ip:%@, 端口号:%d，数据标识:%ld，数据长度:%lu字节", self.ip, self.port, tag, (unsigned long)data.length]];
    }else {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] 📥 接收到数据，ip:%@, 端口号:%d，数据标识:%ld，数据长度:%lu字节", self.ip, self.port, tag, (unsigned long)data.length]];
    }
    
    // 数据有效性检查
    if (!data || data.length == 0) {
        CIMLog(@"[TCP竞速] ⚠️ 接收到空数据，继续读取");
        [sock readDataWithTimeout:self.timeout tag:0];
        return;
    }
    
    // 解析服务器公钥消息
    BOOL isGetServerPublicKeySuccess = [self.novDecryptorManager parseServerPublicKeyMessageSync:data];
    if (isGetServerPublicKeySuccess) {
        
        if (self.type == 0) {
            [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] ✅, 解析服务器公钥成功, ip:%@, 端口号:%d", self.ip, self.port]];
        }else {
            [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] ✅, 解析服务器公钥成功, ip:%@, 端口号:%d", self.ip, self.port]];
        }
        
        // 生成共享密钥
        BOOL isGetShareKeySuccess = [self.novDecryptorManager generateSharedSecret];
        if (isGetShareKeySuccess) {
            if (self.type == 0) {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] ✅ ,生成共享密钥成功,密钥交换完成, ip:%@, 端口号:%d", self.ip, self.port]];
            }else {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] ✅  ,生成共享密钥成功,密钥交换完成, ip:%@, 端口号:%d", self.ip, self.port]];
            }
            [self finish:YES status:LingIMSDKManagerProbeECDHConnectSuccess];
        } else {
            if (self.type == 0) {
                [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 生成共享密钥失败, ip:%@, 端口号:%d", self.ip, self.port]];
            }else {
                [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 生成共享密钥失败, ip:%@, 端口号:%d", self.ip, self.port]];
            }
            [self finish:NO status:LingIMSDKManagerProbeECDHExChangeKeyFail];
        }
    } else {
        if (self.type == 0) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 解析服务器公钥失败, ip:%@, 端口号:%d", self.ip, self.port]];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 解析服务器公钥失败, ip:%@, 端口号:%d", self.ip, self.port]];
        }
        [self finish:NO status:LingIMSDKManagerProbeECDHExChangeKeyFail];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (self.finished) return;
   
    if (self.type == 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] ✅ ECDH密钥数据发送完成, ip:%@, 端口号:%d", self.ip, self.port]];
    }else {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] ✅ ECDH密钥数据发送完成, ip:%@, 端口号:%d", self.ip, self.port]];
    }
    
    // 数据发送完成后，继续读取服务器响应
    [sock readDataWithTimeout:self.timeout tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (self.finished) return;
    
    if (err) {
        if (self.type == 0) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 服务器断开连接, ip:%@, 端口号:%d，错误: %@", self.ip, self.port, err.localizedDescription]];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 服务器断开连接, ip:%@, 端口号:%d，错误: %@", self.ip, self.port, err.localizedDescription]];
        }
        // 如果还没有连接服务器，则标记为失败（有错误，非自己主动断开,故认为是密钥交换失败）
        if ([[NetWorkStatusManager shared] getConnectStatus]) {
            // 当前能联网，认为是密钥交换失败
            [self finish:NO status:LingIMSDKManagerProbeECDHExChangeKeyFail];
        }else {
            // 当前无法连接网络，认为无法连接服务器
            [self finish:NO status:LingIMSDKManagerProbeECDHConnectServerFail];
        }
    } else {
        if (self.type == 0) {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 📴 服务器正常断开连接(主动触发), ip:%@, 端口号:%d", self.ip, self.port]];
        }else {
            [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 📴 服务器正常断开连接(主动触发), ip:%@, 端口号:%d", self.ip, self.port]];
        }
        // 如果还没有连接服务器，则标记为失败（无错误，自己主动断开，故认为是服务器链接失败）
        [self finish:NO status:LingIMSDKManagerProbeECDHConnectServerFail];
    }
}

- (void)startKeyExchangeProcess {
    if (self.finished) return;
    
    if (self.type == 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] ✅ 开始ECDH密钥交换流程..., ip:%@, 端口号:%d", self.ip, self.port]];
    }else {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] ✅  开始ECDH密钥交换流程..., ip:%@, 端口号:%d", self.ip, self.port]];
    }
    
    // 在串行队列中执行密钥交换，避免并发问题
    dispatch_async(self.queue, ^{
        if (self.finished) return;
        __weak typeof(self)weakSelf = self;
        [self.novDecryptorManager generateKeyPairWithComplete:^(SecKeyRef _Nonnull publicKey, SecKeyRef _Nonnull privateKey) {
            __strong typeof(weakSelf)self = weakSelf;
            if (!self) return;
            if (self.finished) return;
            
            if (!publicKey || !privateKey) {
                if (self.type == 0) {
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 生成密钥对失败, ip:%@, 端口号:%d", self.ip, self.port]];
                }else {
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 生成密钥对失败, ip:%@, 端口号:%d", self.ip, self.port]];
                }
                [self finish:NO status:LingIMSDKManagerProbeECDHExChangeKeyFail];
                return;
            }
            
            if (self.type == 0) {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] ✅ 生成密钥对成功, ip:%@, 端口号:%d", self.ip, self.port]];
            }else {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] ✅ 生成密钥对成功, ip:%@, 端口号:%d", self.ip, self.port]];
            }
            
            NSData *publicKeyBase64Data = [self.novDecryptorManager secKeyRefToData:publicKey];
            if (!publicKeyBase64Data) {
                if (self.type == 0) {
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 转换公钥为数据失败, ip:%@, 端口号:%d", self.ip, self.port]];
                }else {
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 转换公钥为数据失败, ip:%@, 端口号:%d", self.ip, self.port]];
                }
                [self finish:NO status:LingIMSDKManagerProbeECDHExChangeKeyFail];
                return;
            }
            
            NSData *sendData = [self.novDecryptorManager buildServerPublicKeyRequestMessage:publicKeyBase64Data];
            if (!sendData) {
                if (self.type == 0) {
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[TCP竞速] ❌ 构建公钥请求消息失败, ip:%@, 端口号:%d", self.ip, self.port]];
                }else {
                    [NoaLocalLogger error:[NSString stringWithFormat:@"[链路检查-日志] ❌ 构建公钥请求消息失败, ip:%@, 端口号:%d", self.ip, self.port]];
                }
                [self finish:NO status:LingIMSDKManagerProbeECDHExChangeKeyFail];
                return;
            }
            
            if (self.type == 0) {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP竞速] ✅ 📤 发送客户端公钥，数据长度: %lu字节, ip:%@, 端口号:%d", (unsigned long)sendData.length, self.ip, self.port]];
            }else {
                [NoaLocalLogger info:[NSString stringWithFormat:@"[链路检查-日志] ✅ 📤 发送客户端公钥，数据长度: %lu字节, ip:%@, 端口号:%d", (unsigned long)sendData.length, self.ip, self.port]];
            }
            
            // 发送客户端公钥
            [self.socket writeData:sendData withTimeout:self.timeout tag:1];
            
            // 开始读取服务器响应
            [self.socket readDataWithTimeout:self.timeout tag:0];
        }];
    });
}

@end

@implementation NoaIMSDKManager (Probe)

- (void)probeECDHConnectivityWithHost:(NSString *)host
                                  port:(uint16_t)port
                               timeout:(NSTimeInterval)timeout
                                 type:(NSInteger)type
                            completion:(void(^)(BOOL success, LingIMSDKManagerProbeECDHConnectStatus status))completion; {
    _LingIMEcdhProbeWrapper *probe = [_LingIMEcdhProbeWrapper new];
    // 使用关联对象，保证探测器在回调触发前不被释放
    NSMutableSet *active = [self _activeProbes];
    @synchronized (self) { [active addObject:probe]; }
    __weak typeof(self) weakSelf = self;
    [probe startWithHost:host port:port timeout:timeout type:type completion:^(BOOL success, LingIMSDKManagerProbeECDHConnectStatus status) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self) {
            @synchronized (self) { [[self _activeProbes] removeObject:probe]; }
        }
        if (completion) { completion(success, status); }
    }];
}

@end

@implementation NoaIMSDKManager (ProbeStorage)
- (NSMutableSet *)_activeProbes {
    NSMutableSet *set = objc_getAssociatedObject(self, kLingIMSDKManagerActiveProbesKey);
    if (!set) {
        set = [NSMutableSet set];
        objc_setAssociatedObject(self, kLingIMSDKManagerActiveProbesKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return set;
}
@end

