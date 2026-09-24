//
//  NoaIMSDKManager+ServiceMessage.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/26.
//

// 系统类型消息 处理

#import "NoaIMSDKManager.h"
#import "NoaIMLoganHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (ServiceMessage)
#pragma mark - 普通系统通知

/// 处理接收到的 系统消息
/// @param message 系统消息
- (void)toolDealReceiveServiceMessage:(IMServerMessage *)message;

#pragma mark - 聊天相关系统通知

/// 处理接收到的 消息已读 系统通知
/// @param message 已读消息信息
- (void)toolDealReceiveServiceForReadMessage:(IMServerMessage *)message;

/// 处理接收到的 我已读某消息 系统通知
/// @param message 我读的消息信息
- (void)toolDealReceiveServiceForUpdateMessageRead:(IMServerMessage *)message;

/// 处理接收到的 消息定时自动删除 系统通知
/// @param message 消息定时自动删除消息
- (void)imSdkDealReceiveServiceMessageForMessageTimeDelete:(IMServerMessage *)message;

#pragma mark - 好友相关系统通知

/// 处理接收到的 好友申请确认 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForUserFriendConfirm:(IMServerMessage *)message;

/// 处理接收到的 好友不存在 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForUserFriendNoneExist:(IMServerMessage *)message;

/// 处理接收到的 好友拉黑 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForUserFriendBlack:(IMServerMessage *)message;

/// 处理接收到的 好友账号注销 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForUserAccoutClose:(IMServerMessage *)message;

/// 处理接收到的 好友在线状态 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForUserFriendOnline:(IMServerMessage *)message;

/// 处理接收到的 好友分组 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForFriendGroup:(IMServerMessage *)message;

/// 处理接收到的 更新翻译配置信息 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForUpdateTranslateConfig:(IMServerMessage *)message;

/// 处理接收到的 单聊消息置顶 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForMessageTop:(IMServerMessage *)message;

/// 处理已发送消息的编辑通知并更新本地原消息。
/// @param message 编辑消息系统通知。
- (void)toolDealReceiveServiceMessageForMessageEdit:(IMServerMessage *)message;

#pragma mark - 群相关系统通知

/// 处理接收到的 群聊相关提示类型 系统通知消息
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForGroupTip:(IMServerMessage *)message;
/// 处理接收到的 支付通知 系统通知
/// @param message 系统通知消息
- (void)toolDealReceiveServiceMessageForPaymentAssistant:(IMServerMessage *)message;
#pragma mark - 自定义事件 系统通知

/// 处理接收到的 自定义事件 系统通知
/// @param message 自定义事件的系统通知消息
- (void)imSdkDealReceiveServiceMessageForCustomEvent:(IMServerMessage *)message;

@end

NS_ASSUME_NONNULL_END
