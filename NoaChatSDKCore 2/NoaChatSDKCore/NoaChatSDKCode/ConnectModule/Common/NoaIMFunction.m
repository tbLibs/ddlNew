//
//  NoaIMFunction.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "NoaIMFunction.h"
#import "NoaIMSocketManager.h"
#import "NoaIMSocketManagerTool.h"
#import "NoaIMHttpManager.h"

@implementation NoaIMFunction

/// 配置socket用户信息
/// - Parameter userOptions: 用户信息
void cim_function_configUser (NoaIMSocketUserOptions *userOptions) {
    @try {
        [SOCKETMANAGER configureSocketUser:userOptions];
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
    }
}

/// 配置socket连接信息
/// - Parameter hostOptions: 连接信息
void cim_function_configSocketHost (NoaIMSocketHostOptions *hostOptions) {
    @try {
        [SOCKETMANAGER configureSocketHost:hostOptions];
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
    }
}

#pragma mark - SDK连接成功
BOOL cim_function_connected (void) {
    return SOCKETMANAGER.currentSocketConnectStatus;
}

#pragma mark - SDK断开连接
/// 断开当前 Socket 并保留重连能力；当前已无活动连接时主动补发重连，
/// 避免退到登录页后因没有断开回调而无法发送登录请求。
void cim_function_disconnected (void) {
    BOOL shouldStartReconnectWithoutDisconnectCallback = !SOCKETMANAGER.gcdSocket.isConnected;

    // 标记能够重新连接
    SOCKETMANAGER.isCanReconnect = YES;
    //断开连接
    [SOCKETMANAGER disconnectSocket];
    //清除用户信息
    [SOCKETMANAGER clearUserInfo];

    if (shouldStartReconnectWithoutDisconnectCallback) {
        [SOCKETMANAGER startingSocketReconnect];
    }
}

/// 断开连接并且不会主动重新连接
void cim_function_disconnectWithOutReconnect (void) {
    // 标记无法重新连接
    SOCKETMANAGER.isCanReconnect = NO;
    //断开连接
    [SOCKETMANAGER disconnectSocket];
    //清除用户信息
    [SOCKETMANAGER clearUserInfo];
}

#pragma mark - 清除用户信息
void cim_function_clearUserInfo (void) {
    //清除用户信息
    [SOCKETMANAGER clearUserInfo];
}

#pragma mark - 将连接状态修改为未重新连接
void cim_function_resetReconnectStatus (void) {
    [SOCKETMANAGER configSetIsReconenctStatus];
}

#pragma mark - SDK重连机制
void cim_function_reconnected (void) {
    [SOCKETMANAGER startingSocketReconnect];
}

#pragma mark - socket连接代理回调
void cim_function_setConnectDelegate (id <NoaConnectDelegate> _Nullable delegate) {
    SOCKETMANAGERTOOL.connectDelegate = delegate;
}

#pragma mark - socket消息代理回调
void cim_function_setMessageDelegate (id <NoaMessageDelegate> _Nullable delegate) {
    SOCKETMANAGERTOOL.messageDelegate = delegate;
}

#pragma mark - socket用户代理回调
void cim_function_setUserDelegate (id <NoaUserDelegate> _Nullable delegate) {
    SOCKETMANAGERTOOL.userDelegate = delegate;
}

#pragma mark - socket群聊代理回调
void cim_function_setGroupDelegate (id <NoaGroupDelegate> _Nullable delegate) {
    SOCKETMANAGERTOOL.groupDelegate = delegate;
}

#pragma mark - Http代理
FOUNDATION_EXPORT void cim_function_setHttpDelegate (id <NoaUserDelegate> _Nullable delegate) {
    [NoaIMHttpManager sharedManager].userDelegate = delegate;
}

#pragma mark - 发送聊天消息
void cim_function_sendChatMessage (IMMessage *message) {
    [SOCKETMANAGER sendSocketMessage:message tag:LingIMMessageTag];
}

#pragma mark - 消息提醒
void cim_function_messageRemindForReceiveMessage (IMMessage *message) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindForReceiveMessage:message];
}
//不含参数的消息提醒
void cim_function_messageRemind (void) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindForMessage];
}

#pragma mark - 自定义消息提醒铃声
void cim_function_messageRemindVoiceConfig (NSString * _Nullable voiceSource, NSString * _Nullable voiceExtension) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindVoiceConfigWith:voiceSource extension:voiceExtension];
}
#pragma mark - 消息提醒开启
void cim_function_messageRemindOpen (BOOL remindOpen) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindOpen:remindOpen];
}
#pragma mark - 消息提醒声音开启
void cim_function_messageRemindVoiceOpen (BOOL remindVoiceOpen) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindVoiceOpen:remindVoiceOpen];
}
#pragma mark - 消息提醒震动开启
void cim_function_messageRemindVibrationOpen (BOOL remindVibrationOpen) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindVibrationOpen:remindVibrationOpen];
}

#pragma mark - 消息提醒状态
BOOL cim_function_messageRemindOpend (void) {
    return [[NoaIMMessageRemindTool sharedManager] messageRemindOpend];
}

#pragma mark - 消息声音提醒状态
BOOL cim_function_messageRemindVoiceOpend (void) {
    return [[NoaIMMessageRemindTool sharedManager] messageRemindVoiceOpend];
}

#pragma mark - 消息震动提醒状态
BOOL cim_function_messageRemindVibrationOpend (void) {
    return [[NoaIMMessageRemindTool sharedManager] messageRemindVibrationOpend];
}

#pragma mark - 音视频通话提醒铃声
void cim_function_messageRemindForMediaCall (void) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindForMediaCall];
}

#pragma mark - 音视频通话自定义提醒铃声
void cim_function_messageRemindVoiceConfigForMediaCall (NSString * _Nullable voiceSource, NSString * _Nullable voiceExtension) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindVoiceConfigForMediaCallWith:voiceSource extension:voiceExtension];
}

#pragma mark - 音视频通话提醒铃声结束
void cim_function_messageRemindEndForMediaCall (void) {
    [[NoaIMMessageRemindTool sharedManager] messageRemindEndForMediaCall];
}

@end
