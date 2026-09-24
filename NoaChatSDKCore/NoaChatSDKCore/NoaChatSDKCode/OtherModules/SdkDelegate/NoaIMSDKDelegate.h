//
//  NoaIMSDKDelegate.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import <Foundation/Foundation.h>
#import "NoaIMChatMessageModel.h"
#import "LingIMSessionModel.h"
#import "LingIMGroupModel.h"
#import "LingIMFriendModel.h"
#import "LIMMediaCallModel.h"
#import "LingIMTranslateConfigModel.h"
#import "LingIMProtocol.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 连接相关代理
@protocol NoaToolConnectDelegate <NSObject>
@optional
/// 正在连接
- (void)cimToolConnecting;

/// 连接成功
- (void)cimToolConnectSuccess;

/// 重连成功
- (void)cimToolReConnectSuccess;

/// 连接失败
- (void)cimToolConnectFailWith:(NSError *)error;

/// 断开连接
- (void)cimToolDisconnect;
@end

#pragma mark - 消息相关代理
@protocol NoaToolMessageDelegate <NSObject>
@optional

/// 接收到聊天消息
/// @param message 聊天消息model
- (void)cimToolChatMessageReceive:(NoaIMChatMessageModel *)message;

/// 消息发送成功
/// @param messageACK 回执消息
- (void)cimToolChatMessageSendSuccess:(IMChatMessageACK *)messageACK;

/// 消息发送失败
/// @param messageID 消息id
- (void)cimToolChatMessageSendFail:(NSString *)messageID;

/// 消息发送失败，并返回可供界面展示的结构化原因。
/// @param messageID 发送失败的本地消息 ID。
/// @param reason 失败原因分类；未知原因由界面回退为通用提示。
- (void)cimToolChatMessageSendFail:(NSString *)messageID
                            reason:(CIMMessageSendFailureReason)reason;

/// 消息清空
/// @param sessionID 会话ID
- (void)cimToolMessageDeleteAll:(NSString *)sessionID;

/// 已接收到聊天消息更新
/// @param message 聊天消息
- (void)cimToolChatMessageUpdate:(NoaIMChatMessageModel *)message;

/// 接收到消息编辑通知后更新原聊天消息。
/// @param message 已合并编辑内容的聊天消息。
- (void)cimToolEditChatMessageUpdate:(NoaIMChatMessageModel *)message;

/// 某个会话的最新消息同步成功
/// @param sessionID 会话ID
- (void)imSdkChatMessageForSessionSyncFinish:(NSString *)sessionID;

/// 敏感词本地数据库同步完成
- (void)imSdkChatMessageSensitiveSyncFinish;

/// 聊天 用户角色权限发生变化，需要更新用户角色权限
- (void)imSdkChatMessageUpdateUserRoleAuthority;

@end

#pragma mark - 用户/好友相关代理
@protocol NoaToolUserDelegate <NSObject>
@optional

/// 用户连接认证成功
- (void)cimToolUserConnectSuccess;

/// 用户发来好友申请
/// @param message 发起好友申请的用户信息
- (void)cimToolUserFriendInvite:(FriendInviteMessage *)message;

/// 用户好友申请消息未读数量发生变化
/// @param inviteUnReadCount 当前好友申请未读总数
- (void)cimToolUserFriendInviteTotalUnreadCount:(NSInteger)inviteUnReadCount;


/// 用户同意/拒绝你发起的好友申请
/// @param message 用户信息
- (void)cimToolUserFriendConfirm:(IMServerMessage *)message;

/// 某好友已将你删除
/// @param message 某好友信息
- (void)cimToolUserFriendDelete:(FriendDelMessage *)message;

/// 好友不存在
/// @param message 好友信息
- (void)cimToolUserFriendNoneExist:(IMServerMessage *)message;

/// 好友在线状态
/// @param message 状态信息
- (void)cimToolUserFriendLineStatus:(IMServerMessage *)message;

/// 好友信息发生更改
/// @param message 好友信息
- (void)cimToolUserFriendChange:(LingIMFriendModel *)message;

/// 好友备注/备注描述发生变化
/// @param message 好友信息
- (void)cimToolUserFriendRemarkChange:(SynchroMessage *)message;

/// 新增好友
/// @param friendAddModel 好友信息
- (void)imSdkUserFriendAdd:(LingIMFriendModel *)friendAddModel;

/// 删除好友
/// @param friendDeleteModel 被删除的好友信息
- (void)imSdkUserFriendDelete:(LingIMFriendModel *)friendDeleteModel;

/// 用户通讯录同步服务器完成
- (void)imSdkUserContactsSyncFinish;

/// 用户通讯录同步服务器失败
/// @param errorMsg 错误信息
- (void)imSdkUserContactsSyncFailed:(NSString *)errorMsg;

/// 用户被强制下线(强制退出登录)
- (void)imSdkUserForceLogout:(NSInteger)type message:(NSString *)message;

/// 用户token失效，触发刷新token接口获取最新token并更新给KIT层
- (void)imSdkRefreshUsetToken:(NSString *)userToken errorMsg:(NSString *)msg;

/// 账号封禁、设备封禁、IP封禁
- (void)imSdkRefreshTokenAuthBanned:(NSInteger)errorCode;

/// 用户 通讯录 好友分组 数据更新
- (void)imSdkUserFriendGroupChange;

/// 用户 同步翻译失败后关闭内容管理里的自动返回开关
- (void)imSdkUserCloseAutoTranslateAndErrorCode:(NSInteger)errorCode errorMsg:(NSString *)errorMsg sessionModel:(LingIMSessionModel *)sessionModel;

/// 用户 同步个人和会话的翻译配置信息后更新到Kit层，防止此时用户正好在聊天页面
- (void)imsdkSynUserAllTranslateConfig:(NSArray <LingIMTranslateConfigModel *> *)configInfoArr;

/// 用户 在其他端更新了 翻译配置想信息
- (void)imsdkUserUpdateTranslateConfigInfo:(UserTranslateConfigUploadMessage *)translateConfig;

/// 用户头像更新
/// @param avatar 新头像uri
- (void)cimUserUpdateAvatar:(NSString *)avatar;

/// 用户昵称更新
/// @param nickName 新昵称
- (void)cimUserUpdateNickName:(NSString *)nickName;

/// 更新httpNode
- (void)cimUserUpdateHttpNode:(NSString *)httpNode;

/// 更新httpNode
- (void)cimUserUnableHttpNode:(NSString *)tipsContent;

@end

#pragma mark - 会话相关代理
@protocol NoaToolSessionDelegate <NSObject>
@optional

/// 接收到新的会话
/// @param model 会话信息
- (void)cimToolSessionReceiveWith:(LingIMSessionModel *)model;

/// 已有的会话发生更新
/// @param model 会话信息
- (void)cimToolSessionUpdateWith:(LingIMSessionModel *)model;

/// 已有的会话list发生更新
/// @param modelList 会话列表
- (void)cimToolSessionListUpdateWith:(NSArray <LingIMSessionModel *> *)modelList topSessionList:(NSArray <LingIMSessionModel *> *)topSessionList isFirstPage:(BOOL)isFirstPage;

/// 删除某个会话
/// @param model 会话信息
- (void)cimToolSessionDeleteWith:(LingIMSessionModel *)model;

/// 会话总未读消息数发生变化
/// @param totalUnreadCount 总未读消息数
- (void)cimToolSessionTotalUnreadCountChange:(NSInteger)totalUnreadCount;

/// 会话列表 同步服务器开始
- (void)imSdkSessionSyncStart;

/// 会话列表 同步服务器完成
- (void)imSdkSessionSyncFinish;

/// 会话列表 同步服务器失败
/// @param errorMsg 错误信息
- (void)imSdkSessionSyncFailed:(NSString *)errorMsg;

/// 会话列表 用户角色权限发生变化，需要更新用户角色权限
- (void)imSdkSessionUpdateUserRoleAuthority;

/// 会话列表全部已读
- (void)imSdkSessionListAllRead:(NSString *)lastServerMsgId;

@end

#pragma mark - 群聊相关代理
@protocol CIMToolGroupDelegate <NSObject>
@optional

/// 接收到新的群组
/// @param model 会话信息
- (void)cimToolGroupReceiveWith:(LingIMGroupModel *)model;

/// 已有的群组发生更新
/// @param model 会话信息
- (void)cimToolGroupUpdateWith:(LingIMGroupModel *)model;

/// 删除某个群组
/// @param model 会话信息
- (void)cimToolGroupDeleteWith:(LingIMGroupModel *)model;

/// 群组 同步服务器完成
- (void)imSdkGroupSyncFinish;

/// 群组 同步服务器失败
/// @param errorMsg 错误信息
- (void)imSdkGroupSyncFailed:(NSString *)errorMsg;

@end

#pragma mark - 音视频相关代理
@protocol NoaIMMediaCallDelegate <NSObject>
@optional

#pragma mark - 单人音视频回调
/// 单人音视频 被邀请者 接收到 邀请者 发来的音视频通话请求
- (void)imSdkMediaCallSingleInviteeReceiveRequestWith:(LIMMediaCallModel *)mediaCallModel;

/// 单人音视频 邀请者 等待 被邀请者 处理 发来的音视频通话请求
/// 告知 邀请者 请等待 被邀请者 处理 音视频通话的请求
- (void)imSdkMediaCallSingleInviterWaitingInviteeDealWith:(LIMMediaCallModel *)mediaCallModel;

/// 单人音视频 被邀请者 同意 邀请者 发来的音视频通话请求
/// 告知 邀请者 被邀请者 同意 音视频通话的请求，邀请者此时可以去确认音视频通话房间了
- (void)imSdkMediaCallSingleInviteeAcceptRequestWith:(LIMMediaCallModel *)mediaCallModel;

/// 单人音视频 邀请者 确认了 音视频通话的房间
/// 告知 被邀请者 邀请者 确认了音视频通话房间信息，被邀请者可以加入房间了
- (void)imSdkMediaCallSingleInviterConfirmRoomWith:(LIMMediaCallModel *)mediaCallModel;

/// 单人音视频 断开通话房间连接
/// 告知 邀请者 和 被邀请者 通话断开连接
/// 需根据 discard_reason 来处理逻辑
/*
"": 空字符串, 通话建立之后正常挂断
//告知 邀请者 展示 如：10:00通话
//告知 被邀请者 展示 如：10:00通话

disconnect: 通话中断, 服务器强制挂断
//告知 邀请者 展示 如：通话中断
//告知 被邀请者 展示 如：通话中断

missed: 对方无应答, 客户端主叫方呼叫超时挂断
//告知 邀请者 展示 如：对方无应答
//告知 被邀请者 展示 如：超时未应答

cancel: 通话已取消, 主叫方取消通话
//告知 邀请者 展示 如：通话已取消
//告知 被邀请者 展示 如：对方已取消

refused: 对方已拒绝
//告知 邀请者 展示 如：对方已拒绝
//告知 被邀请者 展示 如：已拒绝

accept: 已在其他设备接听
//告知 被邀请者 展示 如：已在其他设备接听
*/
- (void)imSdkMediaCallSingleDiscardWith:(LIMMediaCallModel *)mediaCallModel;

#pragma mark - 多人音视频回调
/// 多人音视频 发起申请音视频通话(被邀请者响应)
- (void)imSdkMediaCallGroupRequestWith:(LIMMediaCallModel *)mediaCallModel;

/// 多人音视频 邀请成员加入音视频通话
- (void)imSdkMediaCallGroupInviteWith:(LIMMediaCallModel *)mediaCallModel;

/// 多人音视频 某成员加入音视频通话
- (void)imSdkMediaCallGroupJoinWith:(LIMMediaCallModel *)mediaCallModel;

/// 多人音视频 某成员离开音视频通话
- (void)imSdkMediaCallGroupLeaveWith:(LIMMediaCallModel *)mediaCallModel;

/// 多人音视频 挂断音视频通话(根据挂断原因处理)
- (void)imSdkMediaCallGroupDiscardWith:(LIMMediaCallModel *)mediaCallModel;

/// 多人音视频 参与者发生变化
- (void)imSdkMediaCallGroupParticipantActionWith:(LIMMediaCallModel *)mediaCallModel;

#pragma mark - <<<<<<音视频代理回调>>>>>>
/// 被邀请者 接收到 邀请者 发来的音视频通话请求(单聊触发 群聊触发)
- (void)imSdkCallInviteeReceiveRequestWith:(IMChatMessage *)chatMessageCall;

/// 通话结束，需要判断通话结束的具体状态原因(单聊触发 群聊触发)
- (void)imSdkCallDiscardWith:(IMChatMessage *)chatMessageCall;

/// 被邀请者 同意了 邀请者 发来的音视频通话请求(单聊触发)
- (void)imSdkCallInviteeAcceptRequestWith:(IMChatMessage *)chatMessageCall;

/// 群聊 房间内 成员状态变化
- (void)imSdkCallGroupMemberStateChangeWith:(IMChatMessage *)chatMessageCall;

@end

NS_ASSUME_NONNULL_END
