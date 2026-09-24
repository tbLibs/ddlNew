//
//  LingIMTcpRequestModel.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/6/25.
//

#import "LingIMTcpRequestModel.h"

// 发送协议需要引用的类
#import "FCUUID.h"
#import "NoaIMManagerTool.h"
#import "NoaIMDeviceTool.h"
#import "NoaIMSDKManager.h"
#import "NSDate+SyncServer.h"
#import "LXChatEncrypt.h"

// tcp发送类
#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"

// code码判断
#import "NoaIMHttpResponse.h"

#import "LingIMTcpRequestModel+HandleReceiveMessage.h"

// 数据处理
#import "LingIMTcpCommonTool.h"

// 使用里面的宏定义
#import "NoaIMHttpManager.h"

#import <NetworkStatus/NetworkStatus-Swift.h>

#import "NoaLocalLogger.h"

/// 定义消息接收的通知名称
NSNotificationName const kLingIMTcpReceiveMessageNotification = @"LingIMTcpReceiveMessageNotification";

/// 定义协议超时时间
#define kLingTcpMessageTimeout 15.0

/// 短连接转长连接测试，暂时不启用重试机制(增加重试时间短，体验差)
#define kLingTcpMessageMaxRetryCount 0

@interface LingIMTcpRequestModel ()

// 消息id
@property (nonatomic, copy, readwrite) NSString *msgId;

// 成功回调
@property (nonatomic, copy, readwrite) LingTcpRequestSuccessCallback successCallBack;

/// 失败回调
@property (nonatomic, copy, readwrite) LingIMTcpRequestFailureCallback failureCallBack;

/// 带有时间的成功回调
@property (nonatomic, copy, readwrite) LingTimeRequestSuccessCallback successTimeCallBack;

/// 超时机制
@property (nonatomic, strong) dispatch_source_t gcdTimer;

/// 消息重发尝试次数
@property (nonatomic, assign) NSInteger retryCount;

/// MARK: 记录的参数，用于消息重发
/// 记录当前请求的参数
@property (nonatomic, strong, readwrite) id param;

/// 记录当前请求的url地址
@property (nonatomic, copy, readwrite) NSString *url;

/// 记录当前初试的url
@property (nonatomic, copy, readwrite) NSString *originUrl;

/// 记录当前请求的类型
@property (nonatomic, copy, readwrite) NSString *methodString;

/// 记录当前请求的message对象
@property (nonatomic, strong, readwrite) IMMessage *sendMessage;

/// 能否联网
@property (nonatomic, assign) BOOL isReachable;

/// 发送请求的时间
@property (nonatomic, strong, readwrite) NSDate *sendDate;

@end

@implementation LingIMTcpRequestModel

- (void)dealloc {
    // 移除计时器
    [NoaLocalLogger info:@"[短连接转长连接] 销毁LingIMTcpRequestModel"];
    if (_gcdTimer) {
        [self cancelTimer];
    }
    
    // 移除监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.retryCount = 0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMessage:) name:kLingIMTcpReceiveMessageNotification object:nil];
        
        // 读取当前网络状态
        self.isReachable = [[NetWorkStatusManager shared] getConnectStatus];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange:) name:NetWorkStatusManager.NetworkStatusChangedNotification object:nil];
    }
    return self;
}

/// 收到通知，收到消息进行相关处理
/// - Parameter notification: 通知
- (void)receiveMessage:(NSNotification *)notification {
    IMMessage *message = notification.object;
    
    if ([message.responseMessage.requestId isEqualToString:self.msgId]) {
        // 收到当前请求消息回应 - 只有匹配时才打印详细日志
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] ✅ 收到匹配响应，消息ID:%@, 请求url:%@, status:%d，响应内容:%@",
                      self.msgId, self.url, message.responseMessage.status, message.responseMessage]];
        [self cancelTimer];
        [self receiveMessageDealWith:message];
    }
    // 不匹配的情况不打印日志，避免日志混乱
    // 但我们会在全局ResponseMessage接收处记录所有响应，便于排查ID不匹配问题
}

#pragma mark - 监听网络状态是否可用
- (void)networkChange:(NSNotification *)notification {
    self.isReachable = [[NetWorkStatusManager shared] getConnectStatus];
}

/// MARK: - 外部发送TCP协议方法

/// 发送tcp消息请求
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
+ (LingIMTcpRequestModel *)sendTcpRequestWithParam:(id)param
                                               Url:(NSString *)url
                                            Method:(LingRequestMethod)method
                                       SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                                       FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc {
    LingIMTcpRequestModel *model = [[LingIMTcpRequestModel alloc] init];
    [model sendTcpRequestWithParam:param Url:url Method:method SuccessFunc:successFunc FailureFunc:failureFunc];
    return model;
}

/// 发送tcp消息请求
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 带有服务器时间的成功回调
///   - failureFunc: 失败的回调
+ (LingIMTcpRequestModel *)sendTimeRequestWithParam:(id)param
                                                Url:(NSString *)url
                                             Method:(LingRequestMethod)method
                                        SuccessFunc:(nullable LingTimeRequestSuccessCallback)successFunc
                                        FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc {
    LingIMTcpRequestModel *model = [[LingIMTcpRequestModel alloc] init];
    [model sendTimeRequestWithParam:param Url:url Method:method SuccessFunc:successFunc FailureFunc:failureFunc];
    return model;
}

/// 发送tcp消息请求
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
- (void)sendTcpRequestWithParam:(id)param
                            Url:(NSString *)url
                         Method:(LingRequestMethod)method
                    SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                    FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc {
    self.successCallBack = successFunc;
    self.failureCallBack = failureFunc;
    // 发送消息
    NSString *methodString = @"";
    switch (method) {
        case LingRequestPost:
            methodString = @"POST";
            break;
        case LingRequestGet:
            methodString = @"GET";
            break;
        default:
            break;
    }
    
    /// 记录参数
    self.param = param;
    self.methodString = methodString;
    self.originUrl = url;
    self.url = [self getUrlPathWithParam:param url:url];
    CIMLog(@"[短连接转长连接测试] url = %@", self.url);
    // 配置参数，并调用tcp发送参数
    [self sendMessageWithParam:param method:methodString url:self.url originUrl:self.originUrl];
}

/// 发送tcp消息请求
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 带有服务器时间的成功回调
///   - failureFunc: 失败的回调
- (void)sendTimeRequestWithParam:(id)param
                             Url:(NSString *)url
                          Method:(LingRequestMethod)method
                     SuccessFunc:(nullable LingTimeRequestSuccessCallback)successFunc
                     FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc {
    self.successTimeCallBack = successFunc;
    self.failureCallBack = failureFunc;
    
    // 发送消息
    NSString *methodString = @"";
    switch (method) {
        case LingRequestPost:
            methodString = @"POST";
            break;
        case LingRequestGet:
            methodString = @"GET";
            break;
        default:
            break;
    }
    
    /// 记录参数
    self.param = param;
    self.methodString = methodString;
    self.originUrl = url;
    self.url = [self getUrlPathWithParam:param url:url];
    CIMLog(@"[短连接转长连接测试] url = %@", self.url);
    // 配置参数，并调用tcp发送参数
    [self sendMessageWithParam:param method:methodString url:self.url originUrl:self.originUrl];
}

/// 发送tcp消息请求(根据外部已经组装好的IMMessage,发送协议)
/// - Parameters:
///   - message: 已经组装好的IMMessage
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
+ (LingIMTcpRequestModel *)sendTcpRequestWithIMMessage:(IMMessage *)message
                                           SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                                           FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc {
    LingIMTcpRequestModel *model = [[LingIMTcpRequestModel alloc] init];
    [model sendTcpRequestWithIMMessage:message SuccessFunc:successFunc FailureFunc:failureFunc];
    return model;
}

/// 发送tcp消息请求(根据外部已经组装好的IMMessage,发送协议，配合alloc init使用)
/// - Parameters:
///   - message: 已经组装好的IMMessage
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
- (void)sendTcpRequestWithIMMessage:(IMMessage *)message
                        SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                        FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc {
    self.successCallBack = successFunc;
    self.failureCallBack = failureFunc;
    // 发送协议
    [self sendSocketMessage:message];
}

/// MARK: 计时器相关
/// 开始计时器处理超时相关问题
- (void)beginTimer {
    if (_gcdTimer) {
        return;
    }
    [NoaLocalLogger info:@"[短连接转长连接] 创建计时器"];
    self.gcdTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
    // 消息默认超时时间是3秒
    uint64_t interval = kLingTcpMessageTimeout * NSEC_PER_SEC;
    uint64_t leeway = 1ull * NSEC_PER_MSEC; // 允许有1毫秒的误差
    uint64_t start = dispatch_time(DISPATCH_TIME_NOW, kLingTcpMessageTimeout * NSEC_PER_SEC); // 15秒后开始触发
    
    //设置计时器(定时器，触发时刻，时间间隔，精度)
    dispatch_source_set_timer(self.gcdTimer, start, interval, leeway);
    
    // 设置定时器触发时的超时
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.gcdTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        NSInteger maxRetryCount = kLingTcpMessageMaxRetryCount;
        if ([strongSelf.url isEqualToString:Auth_Refresh_Token_Url]) {
            // 请求token只需要一次
            maxRetryCount = 0;
        }
        
        // 消息超时执行
        if (strongSelf.retryCount < maxRetryCount) {
            // 重发消息,重发次数+1
            strongSelf.retryCount++;
            [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 消息超时了,重发次数+1,当前重发次数为%ld", strongSelf.retryCount]];
            [self sendMessageWithParam:strongSelf.param method:strongSelf.methodString url:strongSelf.url originUrl:strongSelf.originUrl];
        }else {
            // 不再重试，已达最大数量限制,直接调用失败回调
            if (strongSelf.failureCallBack != nil) {
                strongSelf.failureCallBack(0, @"", strongSelf.msgId);
            }
            [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] 消息超时了,重发次数达到上限，取消计时器，超时url = %@, 超时消息id = %@", self.url, self.msgId]];
            // 取消计时器
            [strongSelf cancelTimer];
            // 从缓存队列中移除
            [SOCKETMANAGERTOOL messageTimeOutWithRequestModel:strongSelf];
        }
    });
    
    // 启动定时器
    dispatch_resume(self.gcdTimer);
}

/// 取消计时器
- (void)cancelTimer {
    if (_gcdTimer) {
        dispatch_source_cancel(_gcdTimer);
        _gcdTimer = nil;
        CIMLog(@"[短连接转长连接测试] 计时器取消");
    }else {
        CIMLog(@"[短连接转长连接测试] 计时器不存在，无需取消");
    }
    
}

// MARK: - 接口参数

/// 将参数等信息通过tcp发送
/// - Parameters:
///   - param: 参数
///   - method: 请求方法，例如：POST, GET等
///   - url: 请求地址
- (void)sendMessageWithParam:(id)param
                      method:(NSString *)method
                         url:(NSString *)url
                   originUrl:(NSString *)originUrl {
    if (!self.msgId || self.msgId.length == 0) {
        NSString *msgId = [[NoaIMManagerTool sharedManager] getMessageID];
        self.msgId = msgId;
    }
    
    NSMutableDictionary<NSString *, NSString *> *headerDic = [self configHttpHeaderWithFullUrl:url OriginUrl:originUrl msgId:self.msgId];
    
    NSString *path = url;
    
    // body:param转换为json字符串
    NSString *body = @"{}";
    if (param) {
        body = [LingIMTcpCommonTool jsonEncode:param];
        if (body.length == 0) {
            body = @"{}";
        }
    }
    // 配置RequestMessage对象
    RequestMessage *requestMessage = [[RequestMessage alloc] init];
    requestMessage.path = path;
    requestMessage.method = method;
    if (![method isEqualToString:@"GET"]) {
        requestMessage.body = body;
    }
    
    if ([param isKindOfClass:[NSData class]]) {
        requestMessage.bytesBody = param;
    }
    
    requestMessage.headers = headerDic;
    requestMessage.requestId = self.msgId;
    
    // 配置IMMessage对象
    IMMessage *imMessage = [IMMessage new];
    imMessage.dataType = IMMessage_DataType_RequestMessage;
    imMessage.requestMessage = requestMessage;
    
    [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 📤 发送请求 - url:%@, requestId:%@, path:%@, method:%@, param:%@, body:%@, headers:%@", url, self.msgId, path, method, param, body, headerDic]];
    
    // 发送协议
    [self sendSocketMessage:imMessage];
}

- (NSString *)getUrlPathWithParam:(id)param
                              url:(NSString *)url {
    //GET请求
    if ([self.methodString isEqualToString: @"GET"]) {
        NSString *paramStr = @"?";
        //Param 重新组装请求参数，将参数缀到url后面
        if (![param isKindOfClass:[NSDictionary class]]) {
            return url;
        }
        NSString *getPath = @"";
        NSDictionary *paramDic = param;
        if (paramDic != nil && paramDic.allKeys.count > 0) {
            // 快速遍历参数数组
            for(id key in param) {
                NSString *resultValue;
                id value = [paramDic objectForKey:key];
                if ([value isKindOfClass:[NSNumber class]]) {
                    resultValue = [value stringValue];
                } else {
                    resultValue = value;
                }
                paramStr = [paramStr stringByAppendingString:key];
                paramStr = [paramStr stringByAppendingString:@"="];
                paramStr = [paramStr stringByAppendingString:resultValue];
                paramStr = [paramStr stringByAppendingString:@"&"];
            }
            // 处理多余的&以及返回含参url
            if (paramStr.length > 1) {
                // 去掉末尾的&
                paramStr = [paramStr substringToIndex:paramStr.length - 1];
                getPath = [getPath stringByAppendingString:paramStr];
            }
        }
        getPath = [getPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        if (getPath.length > 0) {
            NSString *newUrl = [NSString stringWithFormat:@"%@%@", url, getPath];
            return newUrl;
        }
        return url;
    } else {
        //POST请求
        return url;
    }
}

/// MARK: 发送socket消息
/// 发送消息
/// - Parameter message: IMMessage对象
- (void)sendSocketMessage:(IMMessage *)message {
    //消息转换二进制流
    self.sendMessage = message;
    
    if (!self.isReachable) {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] 无网，不发送了，消息id = %@", self.msgId]];
        if (self.failureCallBack != nil) {
            self.failureCallBack(-999999, @"", self.msgId);
        }
        
        return;
    }
    
    // 开启超时
    [self beginTimer];
    
    // 记录请求时间
    self.sendDate = [NSDate date];
    
    [SOCKETMANAGERTOOL sendSocketMessageWithRequestModel:self];
}

/// MARK: 接口参数处理
/// 配置RequestMessage对象中的headers参数
/// - Parameter url: 对应Http请求的url
- (NSMutableDictionary<NSString *, NSString *> *)configHttpHeaderWithFullUrl:(NSString *)fullUrl
                                                                   OriginUrl:(NSString *)originUrl
                                                                       msgId:(NSString *)msgId {
    NSMutableDictionary *headerDic = [NSMutableDictionary dictionary];
    //设备类型 ANDROID，IOS，WEB，IOT，PC，WINDOWS，MAC
    [headerDic setObject:@"IOS" forKey:@"deviceType"];
    //deviceUuid多租户
    [headerDic setObject:[FCUUID uuidForDevice] forKey:@"deviceUuid"];
    //日志跟踪
    [headerDic setObject:self.msgId forKey:@"ZTID"];
    //版本号
    [headerDic setObject:[NoaIMDeviceTool appVersion] forKey:@"version"];
    //租户信息
    [headerDic setObject:[IMSDKManager orgName] forKey:@"orgName"];
    //token信息
    if ([IMSDKManager myUserToken].length > 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] myUserToken获取到了，消息id = %@, url = %@", self.msgId, self.url]];
        [headerDic setObject:[IMSDKManager myUserToken] forKey:@"token"];
    }else {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] myUserToken没有获取到，消息id = %@, url = %@", self.msgId, self.url]];
    }
    //loginuseruid
    if ([IMSDKManager myUserID].length > 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] myUserID获取到了，消息id = %@, url = %@", self.msgId, self.url]];
        [headerDic setObject:[IMSDKManager myUserID] forKey:@"loginuseruid"];
    }else {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] myUserID没有获取到，消息id = %@, url = %@", self.msgId, self.url]];
    }
    //设备凭证为空时不发送，兼容首次登录和旧缓存用户
    NSString *deviceSecret = [IMSDKManager myDeviceSecret];
    if (deviceSecret.length > 0) {
        [headerDic setObject:deviceSecret forKey:@"deviceSecret"];
    }
    //liceseId
    if ([IMSDKManager currentLiceseId].length > 0) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] currentLiceseId获取到了，消息id = %@, url = %@", self.msgId, self.url]];
        [headerDic setObject:[IMSDKManager currentLiceseId] forKey:@"conid"];
    }else {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] currentLiceseId没有获取到，消息id = %@, url = %@", self.msgId, self.url]];
    }
    /** 接口验签 */
    //timestamp
    long long timeStamp = [NSDate getCurrentTimeIntervalWithSecond];
    [headerDic setObject:[NSString stringWithFormat:@"%lld", timeStamp] forKey:@"timestamp"];
    //signature
    NSString *signature = [self getUrlSignature:timeStamp url:originUrl];
    [headerDic setObject:signature forKey:@"signature"];
    
    return [headerDic copy];
}

/// 生成url签名
/// - Parameters:
///   - timestamp: 时间戳-毫秒
///   - url: url地址
- (NSString *)getUrlSignature:(long long)timestamp url:(NSString *)url {
    //接口名
    NSString *uri = @"";
    NSString *method = @"";
    if ([url containsString:@"system/v2/getSystemConfig"]) {
        uri = @"system/v2/getSystemConfig";
        method = @"getSystemConfig";
    } else {
        if ([url hasPrefix:@"http"]) {
            url = [url stringByReplacingOccurrencesOfString:IMSDKManager.apiHost withString:@""];
        }
        uri = [url stringByReplacingOccurrencesOfString:@"/biz/" withString:@""];
        uri = [uri stringByReplacingOccurrencesOfString:@"/auth/" withString:@""];
        uri = [uri stringByReplacingOccurrencesOfString:@"/zim-file/" withString:@""];
        uri = [uri stringByReplacingOccurrencesOfString:@"/file/" withString:@""];
        method = [IMSDKManager tenantCode];
    }
    
    NSString *signature = [LXChatEncrypt method5:method uri:uri timestamp:timestamp];
    return signature;
}


- (void)refreshToken {
    //token信息
    NSMutableDictionary<NSString *, NSString *> *headerDic = [self configHttpHeaderWithFullUrl:self.url OriginUrl:self.originUrl msgId:self.msgId];
    self.sendMessage.requestMessage.headers = headerDic;
}

@end
