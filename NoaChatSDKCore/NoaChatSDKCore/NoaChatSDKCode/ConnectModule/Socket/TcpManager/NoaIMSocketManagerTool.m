//
//  NoaIMSocketManagerTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/22.
//

#import "NoaIMSocketManagerTool.h"
#import "NoaLocalLogger.h"
#import "ThreadSafeMutableDictionary.h"//线程安全的字典
#import "NoaIMSocketManager.h"//长连接工具单例
#import "LingIMMacorHeader.h"//宏定义
#import "NoaIMManagerTool.h"//工具
#import "NoaIMSDKManager+ChatMessage.h"
#import "NoaIMLoganManager.h"//日志
#import "NoaIMSDKManager+Logan.h"
#import "NoaIMHttpManager.h"

// 短连接转长连接分类
#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"
#import "NoaIMSocketManagerTool+HandleReceiveTcpReplaceHttpMessage.h"
#import <NetworkStatus/NetworkStatus-Swift.h>

#define SLOWNETWORK @"网络慢"
#define SOCKETDISCONNECT @"socket断开"
#define TIMEDIFLARGE @"设备时间与服务器时间差值过大"

static void *NoaMessageSendQueueKey = &NoaMessageSendQueueKey;

//用户鉴权状态
typedef NS_ENUM(NSUInteger, LingIMUserAuthStatus) {
    LingIMUserAuthStatusSuccess          = 10000,      //用户鉴权成功
    LingIMUserAuthStatusTokenError       = 10002,      //token鉴权错误
    LingIMUserAuthStatusPlatformError    = 10003,      //设备平台鉴权错误
    LingIMUserAuthStatusError            = 10004,      //鉴权异常，鉴权出现系统异常
    LingIMUserAuthStatusNoAuth           = 10005,      //用户未鉴权，用户未发送鉴权信息
    LingIMUserAuthStatusPlatformNone     = 10006,      //设备平台不存在
    LingIMUserAuthStatusUserError        = 10007,      //身份信息验证失败
    LingIMUserAuthStatusUserInfoError    = 10008,      //用户ID为空或参数错误
    LingIMUserAuthStatusUserNone         = 40003,      //用户不存在
    LingIMUserAuthStatusAccountBanned    = 40015,      //账号被封禁
    LingIMUserAuthStatusDeviceBanned     = 40029,      //该设备已被禁止登录
    LingIMUserAuthStatusIPAddressBanned  = 40030,      //客户端IP已被禁止登录
    LingIMUserAuthStatusTokenTimeout     = 40035,      //token过期
    LingIMUserAuthStatusTokenInvalid     = 40038,      //token无效
    LingIMUserAuthStatusTokenDestroy     = 40061,      //token销毁(账号已经被封禁，直接退出登录，无任何提示)
    LingIMUserAuthStatusUserDestroy      = 900017,      //用户已经注销
    LingIMUserAuthStatusUsedIpDisabled   = 90018        //客户端当前IP不在白名单内，直接退出账号，无任何提示
};


@interface NoaIMSocketManagerTool ()

//消息发送超时监听字典
//@{messageId :@{message:消息对象
//               count:重发次数}
//}
@property (nonatomic, strong) ThreadSafeMutableDictionary * sendMessageDic;


//消息发送失败后的 pingmessageDic
@property (nonatomic, strong) ThreadSafeMutableDictionary * messageSendFaildPingMessageDic;

//是否正在重连Sckoet
@property (nonatomic, assign) BOOL isReconnectSocket;


@property (nonatomic, strong) dispatch_queue_t sendMessageQueue;

//是否已经知道被封禁
@property (nonatomic, assign) BOOL isBanded;



@end

@implementation NoaIMSocketManagerTool

#pragma mark - <<<<<<单例>>>>>>
+ (instancetype)sharedManager {
    
    static NoaIMSocketManagerTool *_manager = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        //不能再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        
    });
    
    return _manager;
}

-(dispatch_queue_t)sendMessageQueue{
    if (_sendMessageQueue == nil) {
        _sendMessageQueue = dispatch_queue_create("com.sendMessageQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_sendMessageQueue, NoaMessageSendQueueKey, (__bridge void *)self, NULL);
        
    }
    return _sendMessageQueue;
}


// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMSocketManagerTool sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMSocketManagerTool sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMSocketManagerTool sharedManager];
}


/// 正在连接服务器
- (void)cimConnecting{
    if ([SOCKETMANAGERTOOL.connectDelegate respondsToSelector:@selector(noaConnecting)]) {
        [SOCKETMANAGERTOOL.connectDelegate noaConnecting];
    }
}

/// 连接服务器成功
- (void)cimConnectSuccess{
    self.isReconnectSocket = NO;
    if ([SOCKETMANAGERTOOL.connectDelegate respondsToSelector:@selector(noaConnectSuccess)]) {
        [SOCKETMANAGERTOOL.connectDelegate noaConnectSuccess];
    }
}

/// 重连服务器成功
- (void)cimReConnectSuccess{
    self.isReconnectSocket = NO;
    if ([SOCKETMANAGERTOOL.connectDelegate respondsToSelector:@selector(noaReConnectSuccess)]) {
        [SOCKETMANAGERTOOL.connectDelegate noaReConnectSuccess];
    }
}

- (void)cimGetSessionIdSuccess {
  
}

/// 连接服务器失败
/// @param error 错误信息
- (void)cimConnectFailWithError:(NSError * _Nullable)error{
    self.isReconnectSocket = NO;
    if ([SOCKETMANAGERTOOL.connectDelegate respondsToSelector:@selector(noaConnectFailWithError:)]) {
        [SOCKETMANAGERTOOL.connectDelegate noaConnectFailWithError:error];
    }
    
    // 将缓存的消息全部清除(http转tcp)
    [self releaseAllCacheRequest];
}

/// 断开服务器连接(告知需要竞速)
- (void)cimDisconnect{
    if ([SOCKETMANAGERTOOL.connectDelegate respondsToSelector:@selector(noaDisconnect)]) {
        [SOCKETMANAGERTOOL.connectDelegate noaDisconnect];
    }
    
    // 将缓存的消息全部清除(http转tcp)
    [self releaseAllCacheRequest];
}

/// ECDH 密钥交换完成
/// @param sessionKey 会话密钥
- (void)ecdhKeyExchangeCompleted:(NSData *)sessionKey {
    CIMLog(@"✅ [ECDH协商] SocketManagerTool: ECDH密钥交换完成，会话密钥长度: %lu字节", (unsigned long)sessionKey.length);
    
    // 这里可以通知上层应用 ECDH 完成
    // 如果有专门的 ECDH 代理，可以在这里调用
    // if ([self.connectDelegate respondsToSelector:@selector(ecdhKeyExchangeCompleted:)]) {
    //     [self.connectDelegate ecdhKeyExchangeCompleted:sessionKey];
    // }
}

/// ECDH 密钥交换失败
/// @param error 错误信息
- (void)ecdhKeyExchangeFailed:(NSError *)error {
    CIMLog(@"❌ [ECDH协商] SocketManagerTool: ECDH密钥交换失败: %@", error.localizedDescription);
    
    // 这里可以通知上层应用 ECDH 失败
    // 如果有专门的 ECDH 代理，可以在这里调用
    // if ([self.connectDelegate respondsToSelector:@selector(ecdhKeyExchangeFailed:)]) {
    //     [self.connectDelegate ecdhKeyExchangeFailed:error];
    // }
}


#pragma mark - <<<<<<发送消息处理>>>>>>
- (void)sendMessageDealWith:(IMMessage *)sendMessage {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sendMessageQueue, ^{
        NSString *msgID;
        if (sendMessage.dataType == IMMessage_DataType_ImchatMessage && sendMessage.chatMessage.mType != IMChatMessage_MessageType_HaveReadMessage) {
            //发送的是 IMChatMessage 聊天消息
            msgID = sendMessage.chatMessage.msgId;
        }
        if(msgID){
            if (![NetWorkStatusManager shared].getConnectStatus) {
                // 无外网
                [weakSelf messageSendFailLoganWith:@"timeout" messageId:msgID];
                [weakSelf notifyMessageSendFail:msgID reason:CIMMessageSendFailureReasonNetworkUnavailable];
                return;
            }
            
            if (!weakSelf.isAuth) {
                // 未认证成功，认为失败
                [weakSelf messageSendFailLoganWith:@"authNotSuccess" messageId:msgID];
                [weakSelf notifyMessageSendFail:msgID reason:CIMMessageSendFailureReasonConnectionNotReady];
                return;
            }
            
            NSMutableDictionary * dic = weakSelf.sendMessageDic[msgID];
            NSInteger reSendCount;
            if(dic == nil){
                dic = [NSMutableDictionary dictionary];
                reSendCount = 1;
                [dic setValue:@(reSendCount) forKey:@"count"];
                [dic setValue:sendMessage forKey:@"message"];
                [weakSelf.sendMessageDic setValue:dic forKey:msgID];
            }else{
                reSendCount = [dic[@"count"] integerValue];
                reSendCount += 1;
                [dic setValue:@(reSendCount) forKey:@"count"];
            }
            if(reSendCount <= 3){
                //三秒后检查是否已经 收到这个消息的ACK
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LingIMMessageTimeout * NSEC_PER_SEC)), weakSelf.sendMessageQueue, ^{
                    if (weakSelf.sendMessageDic[msgID] == dic) [weakSelf checkMessageSendAckStatus:msgID];
                });
            }else{
                [weakSelf messageSendFailLoganWith:@"timeout" messageId:msgID];
                [weakSelf sendPingMessageForChatMessageSendFail];
                // HTTP 节点切换/刷新也可能不返回；独立收尾，避免永久显示发送中。
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), weakSelf.sendMessageQueue, ^{
                    if (weakSelf.sendMessageDic[msgID] != dic) return;
                    CIMMessageSendFailureReason reason = [NetWorkStatusManager shared].getConnectStatus ?
                        CIMMessageSendFailureReasonTimeout : CIMMessageSendFailureReasonNetworkUnavailable;
                    [weakSelf notifyMessageSendFail:msgID reason:reason];
                });
                [IMSDKManager MessagePushMsg:[sendMessage data] onSuccess:^(id data, NSString *traceId) {
                    dispatch_async(weakSelf.sendMessageQueue, ^{
                        // ACK 或新一轮重发已经结束/替换该任务时，不再覆盖消息状态。
                        if (weakSelf.sendMessageDic[msgID] != dic) return;
                        IMMessage *imMessage = [data isKindOfClass:NSDictionary.class] ? [IMMessage mj_objectWithKeyValues:data] : nil;
                        IMChatMessageACK *ack = imMessage.chatMessageAck;
                        if (![weakSelf isValidMessageACK:ack forMessageID:msgID]) {
                            [weakSelf notifyMessageSendFail:msgID reason:CIMMessageSendFailureReasonInvalidResponse];
                            return;
                        }
                        [weakSelf.sendMessageDic removeObjectForKey:msgID];
                        if ([weakSelf.messageDelegate respondsToSelector:@selector(noaMessageSendSuccess:)]) {
                            [weakSelf.messageDelegate noaMessageSendSuccess:ack];
                        }
                    });
                } onFailure:^(NSInteger code, NSString *msg, NSString *traceId) {
                    dispatch_async(weakSelf.sendMessageQueue, ^{
                        if (weakSelf.sendMessageDic[msgID] != dic) return;
                        CIMMessageSendFailureReason reason = [weakSelf pushFailureReasonForCode:code networkAvailable:[NetWorkStatusManager shared].getConnectStatus];
                        [weakSelf notifyMessageSendFail:msgID reason:reason];
                    });
                }];
            }
        }
    });
}

/// 通知消息发送失败；新代理可接收结构化原因，旧代理继续获得原有消息 ID 回调。
/// @param messageID 发送失败的本地消息 ID。
/// @param reason 供上层展示的失败原因分类。
- (void)notifyMessageSendFail:(NSString *)messageID reason:(CIMMessageSendFailureReason)reason {
    if (messageID.length == 0) return;
    void (^finish)(void) = ^{
        CIMMessageSendFailureReason displayReason = reason;
        if ((reason == CIMMessageSendFailureReasonConnectionNotReady || reason == CIMMessageSendFailureReasonInvalidResponse || reason == CIMMessageSendFailureReasonUpload) &&
            ![NetWorkStatusManager shared].getConnectStatus) displayReason = CIMMessageSendFailureReasonNetworkUnavailable;
        [self.sendMessageDic removeObjectForKey:messageID];
        if ([self.messageDelegate respondsToSelector:@selector(noaMessageSendFail:reason:)]) {
            [self.messageDelegate noaMessageSendFail:messageID reason:displayReason];
        } else if ([self.messageDelegate respondsToSelector:@selector(noaMessageSendFail:)]) {
            [self.messageDelegate noaMessageSendFail:messageID];
        }
    };
    if (dispatch_get_specific(NoaMessageSendQueueKey) == (__bridge void *)self) finish();
    else dispatch_async(self.sendMessageQueue, finish);
}

- (BOOL)isValidMessageACK:(IMChatMessageACK *)ack forMessageID:(NSString *)messageID {
    return ack && messageID.length > 0 && [ack.ackMsgId isEqualToString:messageID] && ack.sMsgId.length > 0;
}

/// 仅根据明确状态分类，不能把所有 HTTP/网络失败都标为服务端拒绝。
- (CIMMessageSendFailureReason)pushFailureReasonForCode:(NSInteger)code networkAvailable:(BOOL)networkAvailable {
    if (!networkAvailable || code == NSURLErrorNotConnectedToInternet) return CIMMessageSendFailureReasonNetworkUnavailable;
    if (code == 413) return CIMMessageSendFailureReasonFileTooLarge;
    if (code == 429) return CIMMessageSendFailureReasonRateLimited;
    if (code == NSURLErrorNetworkConnectionLost) return CIMMessageSendFailureReasonConnectionLost;
    if (code == 0) return CIMMessageSendFailureReasonInvalidResponse;
    if (code == 10005 || code == 40035 || code == 40038 || code == 10002) return CIMMessageSendFailureReasonConnectionNotReady;
    if ((code >= 400 && code < 500) || code >= 10000) return CIMMessageSendFailureReasonServerRejected;
    return CIMMessageSendFailureReasonTimeout;
}

- (void)sendMessageFailLoganWriteWithMessageId:(NSString *)msgID reason:(NSString *)reason {
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:reason forKey:@"reason"];
    [loganDict setValue:msgID forKey:@"msgId"];
    [IMSDKManager imSdkWriteLoganWith:LingIMLoganTypeApi loganContent:[[NoaIMLoganManager sharedManager] configLoganContent:loganDict]];

}

//检查发送消息的ACK状态
//若已经接受到消息ACK 则字典中相应 Messageid 将会删除。
//消息发送超时监听处理：如 messageid 对应的消息还存在 则说明 还没收到ACK 将重新发送 并再次再三秒后检查；
-(void)checkMessageSendAckStatus:(NSString *)messageId{
    
    NSMutableDictionary * dic = self.sendMessageDic[messageId];
    if(dic){
        IMMessage * message = dic[@"message"];
        if(message){
            if (![NetWorkStatusManager shared].getConnectStatus) {
                [self notifyMessageSendFail:messageId reason:CIMMessageSendFailureReasonNetworkUnavailable];
            } else if (!SOCKETMANAGER.currentSocketConnectStatus) {
                [self notifyMessageSendFail:messageId reason:CIMMessageSendFailureReasonConnectionLost];
            } else {
                [SOCKETMANAGER sendSocketMessage:message tag:LingIMMessageTag];
            }
        }
    }else{
        NSLog(@"已经收到 消息 ACK, messageId -- %@",messageId);
    }
}

#pragma mark - 消息发送失败时，立刻发送一个Ping消息，在3秒内验证是否需要重连
- (void)sendPingMessageForChatMessageSendFail {
    
    IMPingMessage *pingMessage = [[IMPingMessage alloc] init];
    pingMessage.userId = [SOCKETMANAGER socketUserID];
    pingMessage.msgId = [[NoaIMManagerTool sharedManager] getMessageID];
    
    IMMessage *sendMessage = [[IMMessage alloc] init];
    sendMessage.dataType = IMMessage_DataType_ImpingMessage;
    sendMessage.pingMessage = pingMessage;
    
    
    [self.messageSendFaildPingMessageDic setValue:sendMessage forKey:pingMessage.msgId];
    int randomNumber = 10 + arc4random_uniform(991);
    [SOCKETMANAGER sendSocketMessage:sendMessage tag:randomNumber];
    
    //3秒后，验证该Ping消息是否有Pong响应
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),  self.sendMessageQueue, ^{
        [weakSelf delayCheckPingWithMessageId:pingMessage.msgId];
    });
}
#pragma mark - 验证Ping消息是否有Pong响应，来确定是否需要执行重连
- (void)delayCheckPingWithMessageId:(NSString *)messageId {
    
    IMMessage * message = [self.messageSendFaildPingMessageDic valueForKey:messageId];
    if(message && self.isReconnectSocket == NO){
        IMPingMessage *pingMessage = message.pingMessage;
        [self messageSendFailLoganWith:@"timeout" messageId:pingMessage.msgId];
        self.isReconnectSocket = YES;
        //该Ping消息ID存在，说明没有Pong消息响应，需要执行重连
        [SOCKETMANAGER disconnectSocket];
        
        //执行socket断开连接的代理回调，进行竞速后，重连
        [SOCKETMANAGER startingSocketReconnect];
        
        [self messageSendFailLoganWith:@"reconnectSocket" messageId:@""];
    }
}
#pragma mark - 接收到 单聊的 IMChatMessage消息后，客户端发送 IMChatMessageToACK 告知服务端我已接受到了该消息
- (void)sendChatMessageToAckForReceiveChatMessage:(IMChatMessage *)chatMessage {
    //不是自己发送的消息
    if (![chatMessage.from isEqualToString:SOCKETMANAGER.socketUserID]) {
        //配置IMChatMessageToACK
        IMChatMessageToACK *chatMessageToAck = [[IMChatMessageToACK alloc] init];
        chatMessageToAck.msgId = [[NoaIMManagerTool sharedManager] getMessageID];
        chatMessageToAck.ackMsgId = chatMessage.msgId;
        chatMessageToAck.sMsgId = chatMessage.sMsgId;
        chatMessageToAck.from = chatMessage.toUid;
        chatMessageToAck.to = chatMessage.from;
        chatMessageToAck.cType = chatMessage.cType;
        chatMessageToAck.toSource = [NSString stringWithFormat:@"IOS_%@", [FCUUID uuidForDevice]];
        //配置IMMessage
        IMMessage *messageToAck = [[IMMessage alloc] init];
        messageToAck.dataType = IMMessage_DataType_ImchatMessageToAck;
        messageToAck.chatMessageToAck = chatMessageToAck;
        //发送消息
        [SOCKETMANAGER sendSocketMessage:messageToAck tag:LingIMMessageTag];
    }
}

#pragma mark - <<<<<<接收消息处理>>>>>>
- (void)receiveMessageDealWith:(IMMessage *)receiveMessage {
    CIMLog(@"socketManager:接收到消息类型为:%d", receiveMessage.dataType);
    CIMLog(@"socketManager:接收到消息类消息内容:%@", receiveMessage);
    
    switch (receiveMessage.dataType) {
        case IMMessage_DataType_ImauthMessageAck://1 接收到 认证回执 消息
        {
            [self receiveMessageDealForAuthMessageAckWith:receiveMessage];
        }
            break;
        case IMMessage_DataType_ImpongMessage://6 接收到 Pong 消息
        {
            [self receiveMessageDealForPongMessageWith:receiveMessage];
        }
            break;
        case IMMessage_DataType_ImserverMessage://8 接收到 系统通知 消息
        {
            [self receiveMessageDealForServerMessageWith:receiveMessage];
        }
            break;
        case IMMessage_DataType_ImchatMessage://2 接收到 聊天 消息
        {
            [self receiveMessageDealForChatMessageWith:receiveMessage];
        }
            break;
        case IMMessage_DataType_ImchatMessageAck://3 接收到 聊天消息的 服务器回执 消息 说明我发送的消息成功了
        {
            [self receiveMessageDealForChatMessageAckWith:receiveMessage];
        }
            break;
        case IMMessage_DataType_ImchatMessageToAck://4 接收到 聊天客户端回执 消息 (A->B消息，B客户端收到消息后发给A的回执，A收到此消息)
        {
            [self receiveMessageDealForChatMessageToAckWith:receiveMessage];
        }
            break;
        case IMMessage_DataType_ResponseMessage:
        {
            // 9: 短连接转长连接相关逻辑
            [self receiveTcpReplaceHttpMessageDealWith:receiveMessage];
        }
            break;
        default:
        {
            CIMLog(@"socketManager:接收到未处理的消息类型:%d", receiveMessage.dataType);
        }
            break;
    }
}

#pragma mark - 处理接收到的用户鉴权回执消息
/// 处理服务端鉴权回执，并按回执码更新认证、Token 或退出登录状态。
/// @param receiveMessage 包含 IMAuthMessageACK 的服务端消息。
- (void)receiveMessageDealForAuthMessageAckWith:(IMMessage *)receiveMessage {
    
    /*
     Tips:
     用户下线的消息 IMServerMessage_ServerMsgType_UserForcedOffline
     配合重连后认证消息回执，来实现各种退出登录的情况
    */
    
    //鉴权回执消息
    IMAuthMessageACK *authMessageAck = receiveMessage.authMessageAck;
    CIMLog(@"[AUTH链路] stage=AUTH_ACK code=%lld sessionIdEmpty=%@ isAuthBefore=%@ isTokenExpiredBefore=%@",
           authMessageAck.code,
           authMessageAck.sessionId.length == 0 ? @"YES" : @"NO",
           self.isAuth ? @"YES" : @"NO",
           self.isTokenExpired ? @"YES" : @"NO");

    // 已经成功或失败结束的连接忽略迟到回执，避免旧 AUTH 改写新状态或重复触发退出。
    if (!SOCKETMANAGER.isAuthPhaseActive) {
        CIMLog(@"[AUTH链路] stage=AUTH_ACK_IGNORED code=%lld reason=auth_phase_inactive", authMessageAck.code);
        return;
    }
    [SOCKETMANAGER completePendingAuthRequest];
    
    switch (authMessageAck.code) {
        case LingIMUserAuthStatusSuccess://用户鉴权成功，开始心跳机制
        {
            //更新本次鉴权的socket连接唯一标识
            self.socketUUID = authMessageAck.sessionId;

            // 标记认证通过
            self.isAuth = YES;
            self.isTokenExpired = NO;
            self.isTokenRefreshing = NO;

            [SOCKETMANAGER finishAuthPhaseSuccessfully];

            CIMLog(@"[AUTH链路] stage=AUTH_SUCCESS code=%lld isAuthAfter=YES heartbeat=start",
                   authMessageAck.code);

            //开始心跳机制
            [SOCKETMANAGER startSocketHeartbeat];
            
            // 将之前缓存的请求发送
            [SOCKETMANAGERTOOL cimGetSessionIdSuccess];
            
            //执行用户鉴权成功的代理回调
            if ([self.userDelegate respondsToSelector:@selector(noaUserConnectSuccess)]) {
                [self.userDelegate noaUserConnectSuccess];
            }
        }
            break;
        case LingIMUserAuthStatusTokenTimeout://token过期
        case LingIMUserAuthStatusTokenInvalid://token无效
        case LingIMUserAuthStatusTokenError://token鉴权错误
        {
            if (self.hasRetriedAuthAfterTokenRefresh) {
                CIMLog(@"[AUTH链路] stage=AUTH_RETRY_REJECTED code=%lld action=reconnect", authMessageAck.code);
                [self finishAuthWithLogoutCode:(NSInteger)authMessageAck.code message:authMessageAck.message ?: @"身份认证失败，请重新登录"];
                break;
            }
            self.hasRetriedAuthAfterTokenRefresh = YES;
            self.isTokenExpired = YES;
            CIMLog(@"[AUTH链路] stage=AUTH_TOKEN_REJECTED code=%lld action=start_single_refresh",
                   authMessageAck.code);
            [self handleTokenExpiration];
        }
            break;
        case LingIMUserAuthStatusNoAuth://用户未鉴权，用户未发送鉴权信息
        {
            [self finishAuthWithLogoutCode:(NSInteger)authMessageAck.code message:authMessageAck.message ?: @"身份认证失败，请重新登录"];
        }
            break;
        case LingIMUserAuthStatusAccountBanned://用户被封禁
        case LingIMUserAuthStatusDeviceBanned://设备被封禁
        case LingIMUserAuthStatusIPAddressBanned://IP被封禁
        case LingIMUserAuthStatusUserNone://用户不存在
        case LingIMUserAuthStatusTokenDestroy://Token已销毁，不能刷新，直接退出登录
        case LingIMUserAuthStatusUserDestroy://用户已经注销
        {
            [self finishAuthWithLogoutCode:(NSInteger)authMessageAck.code message:authMessageAck.message ?: @"账号状态异常，请重新登录"];
        }
            break;
        case LingIMUserAuthStatusUsedIpDisabled://客户端当前IP不在白名单内
        {
            [self finishAuthWithLogoutCode:90018 message:authMessageAck.message ?: @"当前网络地址不可用，请重新登录"];
        }
            break;
        default:
        {
            CIMLog(@"socketManager:用户鉴权错误信息:%lld-%@", authMessageAck.code, authMessageAck.message);
            [self finishAuthWithLogoutCode:(NSInteger)authMessageAck.code message:authMessageAck.message ?: @"身份认证失败，请重新登录"];
        }
            break;
    }
    
    //日志模块
    [self socketConfigLoganWith:[NSString stringWithFormat:@"用户认证消息回执码:%lld", authMessageAck.code]];
    
}

/// 新连接进入认证阶段前恢复一次性状态，确保重新登录后的失败仍能正确通知业务层。
- (void)prepareForAuthPhase {
    _isBanded = NO;
    self.isAuth = NO;
}

/// 只有服务端明确声明账号失效才退出；网络和可恢复认证异常持续重连。
- (void)finishAuthWithLogoutCode:(NSInteger)code message:(NSString *)message {
    if (_isBanded) return;
    BOOL terminal = code == LingIMUserAuthStatusAccountBanned ||
                    code == LingIMUserAuthStatusDeviceBanned ||
                    code == LingIMUserAuthStatusIPAddressBanned ||
                    code == LingIMUserAuthStatusUserNone ||
                    code == LingIMUserAuthStatusTokenDestroy ||
                    code == LingIMUserAuthStatusUserDestroy ||
                    code == LingIMUserAuthStatusUsedIpDisabled;
    [NoaLocalLogger info:[NSString stringWithFormat:@"[TCP重连链路] stage=AUTH_FAILURE code=%ld terminal=%d", (long)code, terminal]];
    if (terminal) {
        [self doFinishAuthLogoutWithCode:code message:message];
        return;
    }
    self.isAuth = NO;
    self.isTokenExpired = NO;
    self.isTokenRefreshing = NO;
    [SOCKETMANAGER retryConnectionAfterAuthFailure:code];
}

- (void)doFinishAuthLogoutWithCode:(NSInteger)code message:(NSString *)message {
    if (_isBanded) {
        return;
    }
    _isBanded = YES;
    self.isAuth = NO;
    self.isTokenExpired = NO;
    self.isTokenRefreshing = NO;
    [self releaseAllCacheRequest];
    SOCKETMANAGER.isCanReconnect = NO;
    [SOCKETMANAGER cancelAuthPhase];
    [SOCKETMANAGER clearUserInfo];
    [SOCKETMANAGER disconnectSocket];
    CIMLog(@"[AUTH链路] stage=AUTH_TERMINAL_FAILURE code=%ld action=logout_no_reconnect", (long)code);
    if ([self.userDelegate respondsToSelector:@selector(noaUserConnectLogoutWithCode:messsage:)]) {
        [self.userDelegate noaUserConnectLogoutWithCode:code messsage:message ?: @"身份认证失败，请重新登录"];
    }
}

#pragma mark - 处理接收到的Pong消息
- (void)receiveMessageDealForPongMessageWith:(IMMessage *)receiveMessage {
    IMPongMessage *pongMessage = receiveMessage.pongMessage;
    [SOCKETMANAGER completeForegroundConnectionProbeWithMessageID:pongMessage.msgId];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sendMessageQueue, ^{
        [weakSelf.messageSendFaildPingMessageDic removeObjectForKey:pongMessage.msgId];
    });
    //刷新未响应Ping消息个数
    [SOCKETMANAGER resetSocketHeartNoPongCount];
    
}

#pragma mark - 处理接收到的IMServerMessage
- (void)receiveMessageDealForServerMessageWith:(IMMessage *)receiveMessage {
    IMServerMessage *serverMessage = receiveMessage.serverMessage;
    
    switch (serverMessage.sMsgType) {
        case IMServerMessage_ServerMsgType_UserForcedOffline://系统单人命令消息 强制下线
        {
            //用户修改密码后，其他端登录同一账号自动退出登录
            [self dealServerMessageOfUserForcedOffline:serverMessage];
        }
            break;
            
        case IMServerMessage_ServerMsgType_FriendInviteMessage://好友邀请  该消息只转发给被邀请的用户
        case IMServerMessage_ServerMsgType_FriendConfirmMessage://好友确认  该消息只转发给发起申请的用户
        case IMServerMessage_ServerMsgType_FriendDelMessage://删除好友，后台审核通过  该消息只转发给删除操作的用户
        case IMServerMessage_ServerMsgType_NullFriendMessage://好友不存在 该消息转发给发送消息的用户
        case IMServerMessage_ServerMsgType_BlackFriendMessage://好友黑名单 该消息转发给发送消息的用户
        case IMServerMessage_ServerMsgType_FriendLineStatus://好友上线/下线消息 该消息发送给所有在线的好友
        case IMServerMessage_ServerMsgType_UserAccountClose://好友已注销  该消息转发给发送消息的用户
        {
            //好友相关
            [self dealServerMessageOfFriend:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_CreateGroupMessage://创建群聊
        case IMServerMessage_ServerMsgType_JoinConfirmGroupMessage://进群确认/进群通知  该消息体如果拒绝状态只转发给发送申请加入群聊的用户，如果同意该消息会转发给所有在线的群成员
        case IMServerMessage_ServerMsgType_GroupNoChatMessage://群内以开启禁言 该消息转发给发送消息的用户
        case IMServerMessage_ServerMsgType_JoinReqGroupMessage://进群申请  该消息体只转发给群主及群管理员
        case IMServerMessage_ServerMsgType_OutGroupMessage://退群消息  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_KickGroupMessage://踢人消息  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_DelGroupMessage://解散群组  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_TransferOwnerMessage://转让群主  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_EstoppelGroupMessage://群组禁言/解除禁言  该消息只转发给在线的所有群成员,该消息在群组禁言如果发送此消息会转发给某一个人
        case IMServerMessage_ServerMsgType_NoticeGroupMessage://变更群组公告  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_LockAndNoGroupMessage://锁定/解锁群组  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_NameGroupMessage://变更群名称  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_AdminGroupMessage://变更管理员 该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_NoChatGroupMessage://是否禁止私聊  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_JoinVerifyGroupMessage://是否进群验证  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_InviteJoinRepGroupMessage://邀请进群申请  该消息发送给群管理员
        case IMServerMessage_ServerMsgType_InviteConfirmGroupMessage://邀请进群确认/邀请进群通知  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_MemberNoGroupMessage://用户不在群内 该消息转发给发送消息的用户
        case IMServerMessage_ServerMsgType_NullGroupMessage://群组不存在 该消息转发给发送消息的用户
        case IMServerMessage_ServerMsgType_DelGroupNotice://删除群公告 该消息转发给在线所有成员
        case IMServerMessage_ServerMsgType_GroupSingleForbidMessage://群组单个成员禁言 该消息转发给禁言的用户、管理员以及群主
        case IMServerMessage_ServerMsgType_GroupAllForbidMessage://群组单个成员禁言 该消息转发给除了非被禁言的用户、非管理员、非群主的人
        case IMServerMessage_ServerMsgType_MemberGroupForbidMessage://该成员在群内已被禁言 该消息转发给发送消息用户
        case IMServerMessage_ServerMsgType_InviteJoinGroupNoFriendMessage://邀请好友进群，但是好友不存在，该消息只转发给邀请加入的用户
        case IMServerMessage_ServerMsgType_InviteJoinGroupBlackFriendMessage://邀请好友进群, 但是好友关系已被拉黑
        case IMServerMessage_ServerMsgType_IsShowHistoryMessage://是否开启群聊天历史记录
        case IMServerMessage_ServerMsgType_AvatarGroupMessage://变更群头像  该消息只转发给在线的所有群成员
        case IMServerMessage_ServerMsgType_GroupIsAllowNetCallMessage://是否开启全员禁止拨打音视频
        case IMServerMessage_ServerMsgType_GroupMessageInform://是否开启群提示
        case IMServerMessage_ServerMsgType_GroupCloseSearchUserMessage://关闭搜索用户消息通知
        case IMServerMessage_ServerMsgType_UpdateGroupInformStatusForAdminSystem://关闭群通知 开关状态变化
        case IMServerMessage_ServerMsgType_GroupMessageTop://群聊置顶消息变化
        {
            //群组相关
            [self dealServerMessageOfGroup:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_DialogUserMessageTop://单聊置顶消息变化
        {
            [self dealServerMessageOfMessageTop:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_EditedOneMsg://编辑已发送消息
        {
            // 编辑通知单独分发，避免作为普通系统消息插入聊天列表。
            [self dealServerMessageOfEditMessage:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_MsgHaveReadMessage://消息已读 系统通知
        {
            [self dealServerMessageOfReadMessage:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_UpdateMsgReads://更新消息的已读数，该消息转发给消息的阅读者 用于消息的阅读者更新多设备的已读数
        {
            [self dealServerMessageOfUpdateMessageRead:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_CustomEvent://自定义系统通知事件消息
        {
            [self dealServerMessageOfCustomEvent:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_ScheduleDeleteMessage://定时删除消息推送 该消息转发给对方 或者是 群内成员
        {
            [self dealServerMessageOfMessageTimeDelete:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_DelMsgMessage://删除消息记录，会话的聊天消息清空
        {
            [self dealServerMessageOfMessageSessionClear:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_UserGroupsEventMessage://好友分组 管理 509
        {
            [self dealServerMessageOfFriendGroup:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_UserGroupUserEventMessage://好友分组 好友管理 510
        {
            [self dealServerMessageOfFriendGroupForFriend:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_UpdateSensitiveWordMessage://跟新敏感词
        {
            [self dealServerMessageOfUpdateSensitive:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_SignInReminderMessage://每日签到提醒通知
        {
            [self dealServerMessageOfSignInReminder:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_RoleChangeMessage://用户角色权限发生变化
        {
            [self dealServerMessageOfUserRoleAuthority:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_UserTranslateConfigUploadMessage://用户翻译配置信息发生变化
        {
            [self dealServerMessageUserTranslateConfigChange:serverMessage];
        }
            break;
            
        case IMServerMessage_ServerMsgType_ChatMessageError://聊天消息状态异常(当前设备时间与服务器时间差值过大)
        {
            [self messageSendFailLoganWith:TIMEDIFLARGE messageId:serverMessage.sMsgId];
        }
            break;
        case IMServerMessage_ServerMsgType_SynchroMessage://同步类消息
        {
            [self dealServerMessage_SynchroMessage:serverMessage];
        }
            break;
        case IMServerMessage_ServerMsgType_DialogReadTagChangeEventMessage://512 会话 标记未读 / 标记已读 该消息发送给操作人当前登录的所有设备
        {
            [self dealServerMessageDialogReadTagChangeEventMessage:serverMessage];
        }
            break;
        default:
        {
            //其他类型的系统通知消息
            if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemReceiveWith:)]) {
                [_messageDelegate noaMessageSystemReceiveWith:serverMessage];
            }
        }
            break;
    }
    
}

//处理系统消息中 修改完密码后，其他登录端自动退出账号(强制下线)
- (void)dealServerMessageOfUserForcedOffline:(IMServerMessage *)serverMessage {
    UserForcedOffline *forcedOffLine = serverMessage.userForcedOffline;
    //执行用户 强制下线 代理回调
    if ([_userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
        [_userDelegate noaSdkUserForceLogout:forcedOffLine.type message:forcedOffLine.message];
    }
    
}

//处理系统类型消息中的 好友相关 消息
- (void)dealServerMessageOfFriend:(IMServerMessage *)serverMessage {
    
    //对方用户 向 我 发起好友申请
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_FriendInviteMessage) {
        if ([_userDelegate respondsToSelector:@selector(noaUserFriendInvite:)]) {
            [_userDelegate noaUserFriendInvite:serverMessage.friendInviteMessage];
        }
    }
    
    //对方用户 同意了 我 发起的好友申请
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_FriendConfirmMessage) {
        if ([_userDelegate respondsToSelector:@selector(noaUserFriendConfirm:)]) {
            [_userDelegate noaUserFriendConfirm:serverMessage];
        }
    }
    
    //删除好友，后台审核通过  该消息只转发给删除操作的用户
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_FriendDelMessage) {
        if ([_userDelegate respondsToSelector:@selector(noaUserFriendDelete:)]) {
            [_userDelegate noaUserFriendDelete:serverMessage.friendDelMessage];
        }
    }
    
    //好友不存在
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_NullFriendMessage) {
        if ([_userDelegate respondsToSelector:@selector(noaUserFriendNoneExist:)]) {
            [_userDelegate noaUserFriendNoneExist:serverMessage];
        }
    }
    
    //好友在线状态，(发送给所有在线好友)
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_FriendLineStatus) {
        if ([_userDelegate respondsToSelector:@selector(noaUserFriendLineStatus:)]) {
            [_userDelegate noaUserFriendLineStatus:serverMessage];
        }
    }
    
    //好友黑名单 该消息转发给发送消息的用户
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_BlackFriendMessage) {
        if ([_userDelegate respondsToSelector:@selector(noaUserFriendBlack:)]) {
            [_userDelegate noaUserFriendBlack:serverMessage];
        }
    }
    
    //好友已注销 该消息转发给发送消息的用户
    if (serverMessage.sMsgType == IMServerMessage_ServerMsgType_UserAccountClose) {
        if ([_userDelegate respondsToSelector:@selector(noaUserAccountClose:)]) {
            [_userDelegate noaUserAccountClose:serverMessage];
        }
    }
    
}
//处理系统类型消息中的 群组相关 消息
- (void)dealServerMessageOfGroup:(IMServerMessage *)serverMessage {
    
    //群相关提示代理回调
    if ([_groupDelegate respondsToSelector:@selector(noaGroupTipServerMessage:)]) {
        [_groupDelegate noaGroupTipServerMessage:serverMessage];
    }
    
}

//处理系统类型消息中的 会话消息置顶变化
- (void)dealServerMessageOfMessageTop:(IMServerMessage *)serverMessage {
    //通用的系统通知消息处理
    if ([_messageDelegate respondsToSelector:@selector(noaDialogMessageTopChangeEventWith:)]) {
        [_messageDelegate noaDialogMessageTopChangeEventWith:serverMessage];
    }
}

// 将编辑通知交给 SDK 层更新原消息。
- (void)dealServerMessageOfEditMessage:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaEditOneMessageWith:)]) {
        [_messageDelegate noaEditOneMessageWith:serverMessage];
    }
}

//处理系统类型消息中的 消息已读相关 消息
- (void)dealServerMessageOfReadMessage:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaMessageHaveRead:)]) {
        [_messageDelegate noaMessageHaveRead:serverMessage];
    }
    
}

//处理系统类型消息中的 更新消息的已读数 消息
- (void)dealServerMessageOfUpdateMessageRead:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaMessageUpdateMessageRead:)]) {
        [_messageDelegate noaMessageUpdateMessageRead:serverMessage];
    }
}

//处理系统类型消息中的 自定义事件 消息
- (void)dealServerMessageOfCustomEvent:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemCustomEventWith:)]) {
        [_messageDelegate noaMessageSystemCustomEventWith:serverMessage];
    }
}

//处理系统类型消息中的 消息定时自动删除 消息
- (void)dealServerMessageOfMessageTimeDelete:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemMessageTimeDeleteWith:)]) {
        [_messageDelegate noaMessageSystemMessageTimeDeleteWith:serverMessage];
    }
}

//处理系统类型消息中的 清空会话聊天记录 消息
- (void)dealServerMessageOfMessageSessionClear:(IMServerMessage *)serverMessage {
    //通用的系统通知消息处理
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemReceiveWith:)]) {
        [_messageDelegate noaMessageSystemReceiveWith:serverMessage];
    }
}

//处理系统消息中的 好友分组 相关消息
- (void)dealServerMessageOfFriendGroup:(IMServerMessage *)serverMessage {
    if ([_userDelegate respondsToSelector:@selector(noaSdkFriendGroup:)]) {
        [_userDelegate noaSdkFriendGroup:serverMessage];
    }
}

//处理系统消息中的 好友分组 好友管理 相关消息
- (void)dealServerMessageOfFriendGroupForFriend:(IMServerMessage *)serverMessage {
    if ([_userDelegate respondsToSelector:@selector(noaSdkFriendGroupForFriend:)]) {
        [_userDelegate noaSdkFriendGroupForFriend:serverMessage];
    }
}

//处理系统类型消息中的 更新敏感词 消息
- (void)dealServerMessageOfUpdateSensitive:(IMServerMessage *)serverMessage {
    //通用的系统通知消息处理
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemMessageUpdateSensitiveWith:)]) {
        [_messageDelegate noaMessageSystemMessageUpdateSensitiveWith:serverMessage];
    }
}

//处理系统类型消息中的 签到提醒 消息
- (void)dealServerMessageOfSignInReminder:(IMServerMessage *)serverMessage {
    //通用的系统通知消息处理
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemMessageSignInReminder:)]) {
        [_messageDelegate noaMessageSystemMessageSignInReminder:serverMessage];
    }
}

//处理系统类型消息中的 用户角色权限发生变化 消息
- (void)dealServerMessageOfUserRoleAuthority:(IMServerMessage *)serverMessage {
    //通用的系统通知消息处理
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemMessageUserRoleAuthority:)]) {
        [_messageDelegate noaMessageSystemMessageUserRoleAuthority:serverMessage];
    }
}

//处理系统类型消息中的 用户翻译配置信息发生变化 消息
- (void)dealServerMessageUserTranslateConfigChange:(IMServerMessage *)serverMessage {
    //通用的系统通知消息处理
    if ([_userDelegate respondsToSelector:@selector(noaSdkReceiveTranslateConfigUplate:)]) {
        [_userDelegate noaSdkReceiveTranslateConfigUplate:serverMessage];
    }
}

//收到同步类消息
- (void)dealServerMessage_SynchroMessage:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaMessageSystemMessageSynchroMessageWith:)]) {
        [_messageDelegate noaMessageSystemMessageSynchroMessageWith:serverMessage];
    }
}

//会话 标记已读 / 标记未读
- (void)dealServerMessageDialogReadTagChangeEventMessage:(IMServerMessage *)serverMessage {
    if ([_messageDelegate respondsToSelector:@selector(noaDialogReadTagChangeEventWith:)]) {
        [_messageDelegate noaDialogReadTagChangeEventWith:serverMessage];
    }
}


#pragma mark - 处理接收到的IMChatMessage
- (void)receiveMessageDealForChatMessageWith:(IMMessage *)receiveMessage {
    
    //执行接收到聊天消息的代理回调
    if ([_messageDelegate respondsToSelector:@selector(noaMessageChatReceiveWith:)]) {
        [_messageDelegate noaMessageChatReceiveWith:receiveMessage];
    }
    
    //发送 聊天消息 客户端已接收的回执消息
    [self sendChatMessageToAckForReceiveChatMessage:receiveMessage.chatMessage];
    
}

#pragma mark - 处理接收到的IMChatMessageACK 说明 我 发送的消息 成功了
- (void)receiveMessageDealForChatMessageAckWith:(IMMessage *)receiveMessage {
    IMChatMessageACK *ack = receiveMessage.chatMessageAck;
    dispatch_async(self.sendMessageQueue, ^{
        if (![self isValidMessageACK:ack forMessageID:ack.ackMsgId]) {
            if (ack.ackMsgId.length > 0 && self.sendMessageDic[ack.ackMsgId]) {
                [self notifyMessageSendFail:ack.ackMsgId reason:CIMMessageSendFailureReasonInvalidResponse];
            }
            return;
        }
        // 先结束超时监听，再通知成功，防止成功 ACK 被晚到失败回调覆盖。
        [self.sendMessageDic removeObjectForKey:ack.ackMsgId];
        if ([self.messageDelegate respondsToSelector:@selector(noaMessageSendSuccess:)]) {
            [self.messageDelegate noaMessageSendSuccess:ack];
        }
    });
}

#pragma mark - 处理接收到的IMChatMessageToACK
- (void)receiveMessageDealForChatMessageToAckWith:(IMMessage *)receiveMessage {
    IMChatMessageToACK *chatMessageToAck = receiveMessage.chatMessageToAck;
    //移除 我 发送的消息 超时监听
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.sendMessageQueue, ^{
        [weakSelf.sendMessageDic removeObjectForKey:chatMessageToAck.ackMsgId];
    });
}

#pragma mark - 日志模块
- (void)socketConfigLoganWith:(NSString *)errorReason {
    
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:errorReason forKey:@"failReason"];//失败原因
    [loganDict setValue:SOCKETMANAGER.socketHostValue forKey:@"socketHost"];//host地址
    [loganDict setValue:@(SOCKETMANAGER.socketPortValue) forKey:@"socketPort"];//port端口
    //写入日志
    NoaIMLoganManager *loganManager = [NoaIMLoganManager sharedManager];
    [loganManager writeLoganWith:LingIMLoganTypeHost loganContent:[loganManager configLoganContent:loganDict]];

}

#pragma mark - 消息发送失败上报日志
- (void)messageSendFailLoganWith:(NSString *)errorReason messageId:(NSString *)msgId {
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:errorReason forKey:@"failReason"];//失败原因
    [loganDict setValue:msgId forKey:@"messageId"];//失败原因
    //写入日志
    NoaIMLoganManager *loganManager = [NoaIMLoganManager sharedManager];
    [loganManager writeLoganWith:LingIMLoganTypeCommon loganContent:[loganManager configLoganContent:loganDict]];
    
    [self sentryUploadWithDictionary:loganDict transaction:@"event_message"];

}

- (void)sentryUploadWithDictionary:(NSDictionary *)dictionary transaction:(NSString *)transaction{
    if (!transaction || transaction.length == 0) return;
    if (!dictionary || dictionary.count == 0) return;
    // 交由 App 侧 ZTSentryManager 监听后上报，避免 SDK 依赖 Sentry pod / App 类
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ZTSentryEventUploadNotification"
                                                        object:nil
                                                      userInfo:@{@"transaction": transaction,
                                                                 @"data": dictionary}];
}


- (ThreadSafeMutableDictionary *)sendMessageDic{
    if (_sendMessageDic == nil) {
        _sendMessageDic = [ThreadSafeMutableDictionary dictionaryWithCapacity:1];
    }
    return _sendMessageDic;
}

- (ThreadSafeMutableDictionary *)messageSendFaildPingMessageDic{
    if (_messageSendFaildPingMessageDic == nil) {
        _messageSendFaildPingMessageDic = [ThreadSafeMutableDictionary dictionaryWithCapacity:1];
    }
    return _messageSendFaildPingMessageDic;
    
}

@end
