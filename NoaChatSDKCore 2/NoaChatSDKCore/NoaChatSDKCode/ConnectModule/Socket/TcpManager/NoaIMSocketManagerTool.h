//
//  NoaIMSocketManagerTool.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/22.
//

// Socket消息业务管理类

#define SOCKETMANAGERTOOL [NoaIMSocketManagerTool sharedManager]

#import <Foundation/Foundation.h>

#import "LingIMProtocol.h"//代理

NS_ASSUME_NONNULL_BEGIN


@interface NoaIMSocketManagerTool : NSObject

/// 结束单条消息的发送等待并通知可展示的失败原因。
- (void)notifyMessageSendFail:(NSString *)messageID reason:(CIMMessageSendFailureReason)reason;

//连接代理
@property (nonatomic, weak) id <NoaConnectDelegate> connectDelegate;
//消息代理
@property (nonatomic, weak) id <NoaMessageDelegate> messageDelegate;
//用户代理
@property (nonatomic, weak) id <NoaUserDelegate> userDelegate;
//群组代理
@property (nonatomic, weak) id <NoaGroupDelegate> groupDelegate;
//本次长连接，用户鉴权成功后，socket的唯一标识
@property (nonatomic, copy) NSString *socketUUID;
//app的Build ID
@property (nonatomic, copy) NSString *appBuildIdStr;

/// 是否认证通过，未认证通过，不发送消息
@property (nonatomic, assign) BOOL isAuth;

/// 新连接进入 AUTH 阶段前重置一次性退出通知和认证状态。
- (void)prepareForAuthPhase;

/// AUTH 临时故障保留登录态持续重连；账号明确失效时才通知业务层退出。
/// @param code AUTH 错误码；客户端超时或断链使用内部兜底码。
/// @param message 提供给业务层的错误说明，不允许为空。
- (void)finishAuthWithLogoutCode:(NSInteger)code message:(NSString *)message;

#pragma mark - <<<<<<单例>>>>>>
+ (instancetype)sharedManager;


/// 正在连接服务器
- (void)cimConnecting;

/// 连接服务器成功
- (void)cimConnectSuccess;

/// 重连服务器成功
- (void)cimReConnectSuccess;

/// 连接成功后，拿到了session_id，认为才是真正的成功
- (void)cimGetSessionIdSuccess;

/// 连接服务器失败
/// @param error 错误信息
- (void)cimConnectFailWithError:(NSError * _Nullable)error;

/// 断开服务器连接(告知需要竞速)
- (void)cimDisconnect;

/// ECDH 密钥交换完成
/// @param sessionKey 会话密钥
- (void)ecdhKeyExchangeCompleted:(NSData *)sessionKey;

/// ECDH 密钥交换失败
/// @param error 错误信息
- (void)ecdhKeyExchangeFailed:(NSError *)error;


#pragma mark - <<<<<<业务>>>>>>
/// 发送消息处理
/// - Parameter sendMessage: 发送的消息
- (void)sendMessageDealWith:(IMMessage *)sendMessage;

/// 接收消息处理
/// - Parameter receiveMessage: 接收的消息
- (void)receiveMessageDealWith:(IMMessage *)receiveMessage;

@end

NS_ASSUME_NONNULL_END
