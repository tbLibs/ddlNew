//
//  NoaIMFunction.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import <Foundation/Foundation.h>
#import "LingIMProtocol.h"
#import "NoaIMMessageRemindTool.h"
#import "NoaIMSocketHostOptions.h"//网关配置信息
#import "NoaIMSocketUserOptions.h"//用户配置信息

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMFunction : NSObject

@end

/// 配置socket用户信息
/// - Parameter userOptions: 用户信息
FOUNDATION_EXPORT void cim_function_configUser (NoaIMSocketUserOptions *userOptions);

/// 配置socket连接信息
/// - Parameter hostOptions: 连接信息
FOUNDATION_EXPORT void cim_function_configSocketHost (NoaIMSocketHostOptions *hostOptions);

/// SDK登录成功?
FOUNDATION_EXPORT BOOL cim_function_connected (void);

/// SDK断开连接
FOUNDATION_EXPORT void cim_function_disconnected (void);

/// 断开连接并且不会主动重新连接
FOUNDATION_EXPORT void cim_function_disconnectWithOutReconnect (void);

// 清除用户信息
FOUNDATION_EXPORT void cim_function_clearUserInfo (void);

// 将连接状态修改为未重新连接
FOUNDATION_EXPORT void cim_function_resetReconnectStatus (void);

/// SDK重连机制
FOUNDATION_EXPORT void cim_function_reconnected (void);

/// 连接代理
/// @param delegate 服从代理对象
FOUNDATION_EXPORT void cim_function_setConnectDelegate (id <NoaConnectDelegate> _Nullable delegate);

/// 消息代理
/// @param delegate 服从代理对象
FOUNDATION_EXPORT void cim_function_setMessageDelegate (id <NoaMessageDelegate> _Nullable delegate);

/// 用户代理
/// @param delegate 服从代理对象
FOUNDATION_EXPORT void cim_function_setUserDelegate (id <NoaUserDelegate> _Nullable delegate);

/// 群组代理
/// @param delegate 服从代理对象
FOUNDATION_EXPORT void cim_function_setGroupDelegate (id <NoaGroupDelegate> _Nullable delegate);

/// Http代理
/// @param delegate 服从代理对象
FOUNDATION_EXPORT void cim_function_setHttpDelegate (id <NoaUserDelegate> _Nullable delegate);

/// 发送聊天消息
/// @param message 发送的聊天消息
FOUNDATION_EXPORT void cim_function_sendChatMessage (IMMessage *message);


/// 消息提醒
/// @param message 需要提醒的消息
FOUNDATION_EXPORT void cim_function_messageRemindForReceiveMessage (IMMessage *message);

/// 消息提醒(不含参数)
FOUNDATION_EXPORT void cim_function_messageRemind (void);

/// 自定义消息提醒铃声
/// @param voiceSource 声音资源
/// @param voiceExtension 资源类型
FOUNDATION_EXPORT void cim_function_messageRemindVoiceConfig (NSString * _Nullable voiceSource, NSString * _Nullable voiceExtension);

/// 消息提醒开启
/// @param remindOpen 开启或关闭
FOUNDATION_EXPORT void cim_function_messageRemindOpen (BOOL remindOpen);

/// 消息提醒声音开启
/// @param remindVoiceOpen 开启或关闭
FOUNDATION_EXPORT void cim_function_messageRemindVoiceOpen (BOOL remindVoiceOpen);

/// 消息提醒震动开启
/// @param remindVibrationOpen 开启或关闭
FOUNDATION_EXPORT void cim_function_messageRemindVibrationOpen (BOOL remindVibrationOpen);

/// 消息提醒状态
FOUNDATION_EXPORT BOOL cim_function_messageRemindOpend (void);

/// 消息声音提醒状态
FOUNDATION_EXPORT BOOL cim_function_messageRemindVoiceOpend (void);

/// 消息震动提醒状态
FOUNDATION_EXPORT BOOL cim_function_messageRemindVibrationOpend (void);

/// 音视频通话提醒铃声
FOUNDATION_EXPORT void cim_function_messageRemindForMediaCall (void);

/// 音视频通话自定义提醒铃声
/// @param voiceSource 铃声资源
/// @param voiceExtension 铃声类型
FOUNDATION_EXPORT void cim_function_messageRemindVoiceConfigForMediaCall (NSString * _Nullable voiceSource, NSString * _Nullable voiceExtension);

/// 音视频通话提醒铃声结束
FOUNDATION_EXPORT void cim_function_messageRemindEndForMediaCall (void);

NS_ASSUME_NONNULL_END
