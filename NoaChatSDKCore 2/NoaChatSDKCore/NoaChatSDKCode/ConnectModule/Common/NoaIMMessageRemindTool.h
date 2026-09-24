//
//  NoaIMMessageRemindTool.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/7.
//

#import <Foundation/Foundation.h>
#import "LingImmessage.pbobjc.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMMessageRemindTool : NSObject
#pragma mark - 单例
+ (instancetype)sharedManager;
//单例一般不需要清空，但是在执行某些功能的时候，防止数据更换不及时，可以清空一下
- (void)clearManager;


/// 开启消息提醒
/// @param openRemind 开启或关闭
- (void)messageRemindOpen:(BOOL)openRemind;

/// 开启声音提醒
/// @param openVoice 开启或关闭
- (void)messageRemindVoiceOpen:(BOOL)openVoice;

/// 开启震动提示
/// @param openVibration 开启或关闭
- (void)messageRemindVibrationOpen:(BOOL)openVibration;

/// 接收消息提醒
- (void)messageRemindForReceiveMessage:(IMMessage *)message;

/// 接收消息提醒
- (void)messageRemindForMessage;

/// 自定义消息提醒铃声
/// @param voiceSource 铃声资源
/// @param voiceExtension 铃声类型
- (void)messageRemindVoiceConfigWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension;

/// 是否开启了消息提醒
- (BOOL)messageRemindOpend;

/// 是否开启了声音提醒
- (BOOL)messageRemindVoiceOpend;

/// 是否开启了震动提醒
- (BOOL)messageRemindVibrationOpend;

#pragma mark - 音视频通话提醒
/// 音视频通话提醒铃声
- (void)messageRemindForMediaCall;

/// 音视频通话自定义提醒铃声
/// @param voiceSource 铃声资源
/// @param voiceExtension 铃声类型
- (void)messageRemindVoiceConfigForMediaCallWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension;

/// 音视频通话提醒铃声结束
- (void)messageRemindEndForMediaCall;

@end

NS_ASSUME_NONNULL_END
