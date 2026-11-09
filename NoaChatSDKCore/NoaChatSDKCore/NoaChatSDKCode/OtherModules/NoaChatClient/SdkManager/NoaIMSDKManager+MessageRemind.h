//
//  NoaIMSDKManager+MessageRemind.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/7.
//

// 消息提醒

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (MessageRemind)

/// 消息提醒 
/// @param message 接收到的消息
/// App统一负责普通消息提醒时关闭SDK自动声音，通话提醒保持独立。
- (void)setApplicationManagesMessageAlerts:(BOOL)managed;

- (void)toolMessageReceiveRemindWith:(IMMessage *)message;

/// 消息提醒
/// @param message 接收到的消息
- (void)toolMessageReceiveRemindWithChatMessage:(NoaIMChatMessageModel *)message;

/// 自定义消息提醒铃声
/// @param voiceSource 铃声资源
/// @param voiceExtension 铃声类型
- (void)toolMessageReceiveRemindVoiceConfigWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension;

/// 消息提醒配置
/// @param remindOpen 开启或关闭
- (void)toolMessageReceiveRemindOpen:(BOOL)remindOpen;

/// 消息声音提醒
/// @param remindVoiceOpen 开启或关闭
- (void)toolMessageReceiveRemindVoiceOpen:(BOOL)remindVoiceOpen;

/// 消息震动提醒
/// @param remindVibrationOpen 开启或关闭
- (void)toolMessageReceiveRemindVibrationOpen:(BOOL)remindVibrationOpen;

/// 消息提醒状态
- (BOOL)toolMessageReceiveRemindOpend;

/// 消息声音提醒状态
- (BOOL)toolMessageReceiveRemindVoiceOpend;

/// 消息震动提醒状态
- (BOOL)toolMessageReceiveRemindVibrationOpend;

// ******音视频通话提醒******
/// 音视频通话提醒铃声
- (void)toolMessageReceiveRemindForMediaCall;

/// 音视频通话自定义提醒铃声
/// @param voiceSource 铃声资源
/// @param voiceExtension 铃声类型
- (void)toolMessageReceiveRemindVoiceConfigForMediaCallWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension;

/// 音视频通话提醒铃声结束
- (void)toolMessageReceiveRemindEndForMediaCall;
@end

NS_ASSUME_NONNULL_END
