//
//  LingIMProtocol.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/8/18.
//

#import <Foundation/Foundation.h>

//消息model
#import "LingImmessage.pbobjc.h"


NS_ASSUME_NONNULL_BEGIN

/// 消息发送失败原因，仅用于客户端展示与重试提示，不承载底层日志或服务端敏感信息。
typedef NS_ENUM(NSInteger, CIMMessageSendFailureReason) {
    CIMMessageSendFailureReasonUnknown = 0,
    CIMMessageSendFailureReasonNetworkUnavailable,
    CIMMessageSendFailureReasonConnectionNotReady,
    CIMMessageSendFailureReasonTimeout,
    CIMMessageSendFailureReasonServerRejected,
    CIMMessageSendFailureReasonInvalidResponse,
    CIMMessageSendFailureReasonUpload,
    CIMMessageSendFailureReasonTranslation,
    // 已落库的 0...7 保持不变，新原因只追加。
    CIMMessageSendFailureReasonConnectionLost,
    CIMMessageSendFailureReasonFileMissing,
    CIMMessageSendFailureReasonFileTooLarge,
    CIMMessageSendFailureReasonRateLimited,
    CIMMessageSendFailureReasonEncryption,
    CIMMessageSendFailureReasonGroupMuted,
    CIMMessageSendFailureReasonGroupUnavailable,
    CIMMessageSendFailureReasonNotGroupMember,
};

#pragma mark - 服务器连接回调
@protocol NoaConnectDelegate <NSObject>
@optional

/// 正在连接服务器
- (void)noaConnecting;

/// 连接服务器成功
- (void)noaConnectSuccess;

/// 重连服务器成功
- (void)noaReConnectSuccess;

/// 连接服务器失败
/// @param error 错误信息
- (void)noaConnectFailWithError:(NSError * _Nullable)error;

/// 断开服务器连接(告知需要竞速)
- (void)noaDisconnect;

@end

#pragma mark - 消息回调
@protocol NoaMessageDelegate <NSObject>
@optional

/// 接收到聊天信息
/// @param message 聊天消息
- (void)noaMessageChatReceiveWith:(IMMessage * _Nullable)message;

/// 聊天消息发送成功
/// @param messageACK 回执消息信息
- (void)noaMessageSendSuccess:(IMChatMessageACK * _Nullable)messageACK;

/// 聊天消息发送失败
/// @param messageID 消息id
- (void)noaMessageSendFail:(NSString * _Nullable)messageID;

/// 聊天消息发送失败，并返回可供上层映射展示的结构化原因。
/// @param messageID 发送失败的本地消息 ID。
/// @param reason 失败原因分类；不包含底层日志或服务端敏感信息。
- (void)noaMessageSendFail:(NSString * _Nullable)messageID
                    reason:(CIMMessageSendFailureReason)reason;

/// 消息已读
/// @param message 已读消息信息通知
- (void)noaMessageHaveRead:(IMServerMessage * _Nullable)message;

/// 更新消息已读(我发起消息已读，后台推送一条该系统通知，然后进行红点-1)
/// @param message 消息已读的信息通知
- (void)noaMessageUpdateMessageRead:(IMServerMessage * _Nullable)message;

/// 接收到系统通知消息
/// @param message 系统通知消息
- (void)noaMessageSystemReceiveWith:(IMServerMessage * _Nullable)message;

/// 接收到系统消息 - 自定义事件
/// @param message 系统消息
- (void)noaMessageSystemCustomEventWith:(IMServerMessage * _Nullable)message;

/// 接收到系统消息 - 消息定时自动删除
/// @param message 系统消息
- (void)noaMessageSystemMessageTimeDeleteWith:(IMServerMessage * _Nullable)message;

// 接收到系统消息 - 更新敏感词
/// @param message 系统消息
- (void)noaMessageSystemMessageUpdateSensitiveWith:(IMServerMessage * _Nullable)message;

/// 接收到系统通知消息 - 签到提醒
/// @param message 系统通知消息
- (void)noaMessageSystemMessageSignInReminder:(IMServerMessage * _Nullable)message;

/// 接收到系统通知消息 - 用户角色权限发生变化
/// @param message 系统通知消息
- (void)noaMessageSystemMessageUserRoleAuthority:(IMServerMessage * _Nullable)message;

/// 接收到系统通知消息 - 同步类消息
/// @param message 系统通知消息
- (void)noaMessageSystemMessageSynchroMessageWith:(IMServerMessage * _Nullable)message;

/// 接收到系统通知消息 - 会话 标记未读/标记已读
/// @param message 系统通知消息
- (void)noaDialogReadTagChangeEventWith:(IMServerMessage * _Nullable)message;

/// 接收到系统通知消息 - 会话 置顶消息变化
/// @param message 系统通知消息
- (void)noaDialogMessageTopChangeEventWith:(IMServerMessage * _Nullable)message;

/// 接收到已发送消息被编辑的系统通知。
/// @param message 包含原消息标识和编辑后正文的系统消息。
- (void)noaEditOneMessageWith:(IMServerMessage * _Nullable)message;

@end

#pragma mark - 用户回调
@protocol NoaUserDelegate <NSObject>
@optional

/// 用户连接认证成功
- (void)noaUserConnectSuccess;

/// 用户退出登录
- (void)noaUserConnectLogoutWithCode:(NSInteger)errorCode messsage:(NSString *)message;

/// 用户的token需要刷新
- (void)noaUserAuthTokenNeedRefresh;

/// 用户发来好友申请
/// @param message 发起好友申请的用户信息
- (void)noaUserFriendInvite:(FriendInviteMessage *)message;

/// 用户同意/拒绝你发起的好友申请
/// @param message 用户信息
- (void)noaUserFriendConfirm:(IMServerMessage *)message;

/// 某好友已将你删除
/// @param message 某好友信息
- (void)noaUserFriendDelete:(FriendDelMessage *)message;

/// 好友不存在
/// @param message 好友信息
- (void)noaUserFriendNoneExist:(IMServerMessage *)message;

/// 好友在线状态
/// @param message 状态信息
- (void)noaUserFriendLineStatus:(IMServerMessage *)message;

/// 好友拉黑处理
/// @param message 状态信息
- (void)noaUserFriendBlack:(IMServerMessage *)message;

/// 好友账号注销
/// @param message 状态信息
- (void)noaUserAccountClose:(IMServerMessage *)message;

/// 用户被强制下线(退出登录)
- (void)noaSdkUserForceLogout:(NSInteger)type message:(NSString *)message;

/// 用户token失效，触发刷新token接口获取最新token并更新给KIT层(HTTP触发token更新，告知业务层)
- (void)noaSdkRefreshUsetToken:(NSString *)userToken errorMsg:(NSString * _Nullable)errorMsg;

/// 账号封禁、设备封禁、IP封禁
- (void)noaSdkRefreshTokenAuthBanned:(NSInteger)errorCode;

/// 用户的 好友分组 相关的管理与处理
/// @param message 好友分组 相关信息
- (void)noaSdkFriendGroup:(IMServerMessage *)message;

/// 用户的 好友分组 好友管理 相关的处理
/// @param message 好友分组下的好友 相关信息
- (void)noaSdkFriendGroupForFriend:(IMServerMessage *)message;

/// 用户 在别的端修改了翻译配置信息，收到更新到本设备的通知
- (void)noaSdkReceiveTranslateConfigUplate:(IMServerMessage *)message;

/// 更新api的httpHost
- (void)noaSdkUpdateHttpNodeWith:(NSString *)httpNode;

/// 更新node的时候，如果没有可用的node需要给出提示
- (void)noaSdkUnableHttpNodeWith:(NSString *)tipContent;

@end

#pragma mark - 群组回调
@protocol NoaGroupDelegate <NSObject>
@optional

/// 群组相关的提示类消息处理(系统通知类型消息)
/// @param message 系统通知消息
- (void)noaGroupTipServerMessage:(IMServerMessage *)message;

@end




NS_ASSUME_NONNULL_END
