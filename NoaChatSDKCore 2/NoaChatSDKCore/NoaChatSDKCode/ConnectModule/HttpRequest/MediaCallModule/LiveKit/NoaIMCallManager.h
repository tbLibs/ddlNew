//
//  NoaIMCallManager.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/5.
//

#import <Foundation/Foundation.h>
//OC调用Swift，引用系统隐式创建的文件
#import <NoaChatCore/NoaChatSDKCore-Swift.h>
//音视频SDK
#import <LiveKitClient-Swift.h>
#import <WebRTC/WebRTC.h>
#import "NoaIMCallOptions.h"

//房间成功回调
typedef void (^LingIMCallSuccessBack)(void);

//房间连接失败回调
typedef void (^LingIMCallFailureBack)(NSError  * _Nonnull error);


NS_ASSUME_NONNULL_BEGIN

@interface NoaIMCallManager : NSObject

#pragma mark - 单例
+ (instancetype)sharedManager;

#pragma mark - 方法与属性

/// 音视频聊天 房间 概念
@property (nonatomic, strong) Room *callRoom;

/// 用户连接音视频房间
/// @param callOptions 呼叫配置
/// @param roomDelegateObjc 服从代理者
- (void)callRoomConnectWithOptions:(NoaIMCallOptions *)callOptions delegate:(id <RoomDelegateObjC>)roomDelegateObjc;

/// 服从代理
/// @param roomDelegateObjc 服从代理者
- (void)callRoomDelegate:(id <RoomDelegateObjC>)roomDelegateObjc;

/// 用户房间状态
- (ConnectionState)callRoomConnectState;

/// 用户房间类型
- (LingIMCallType)callRoomType;

/// 用户房间角色类型
- (LingIMCallRoleType)callRoomRoleType;

/// 用户断开房间的连接
- (void)callRoomDisconnect;

/// 用户音频静默打开
- (void)callRoomAudioMuteOn:(void (^) (BOOL muteOn))muteBlock;

/// 用户音频静默关闭
- (void)callRoomAudioMuteOff:(void (^) (BOOL muteOff))muteBlock;

/// 用户音频状态
- (LingIMCallMicrophoneMuteState)callRoomAudioState;

/// 用户视频静默打开
- (void)callRoomVideoMuteOn:(void (^) (BOOL muteOn))muteBlock;

/// 用户视频静默关闭
- (void)callRoomVideoMuteOff:(void (^) (BOOL muteOff))muteBlock;

/// 用户视频状态
- (LingIMCallCameraMuteState)callRoomVideoState;

/// 用户改变视频摄像头方向
- (void)callRoomVideoCameraSwitch:(void (^) (BOOL success))switchResultBlock;

/// 用户使用听筒模式(外放关闭)
- (void)callRoomAudioExternalOff;

/// 用户使用扬声器模式(外放打开)
- (void)callRoomAudioExternalOn;

/// 获取房间的远端流数组
- (NSArray *)callRoomGetRemoteParticipants;

@end

NS_ASSUME_NONNULL_END
