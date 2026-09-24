//
//  NoaIMZGCallManager.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/18.
//

#define ZGCALL [NoaIMZGCallManager sharedManager]

#import <Foundation/Foundation.h>
#import "NoaIMZGCallConfig.h"
#import "NoaIMZGCallOptions.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>

typedef void (^LingIMZGLoginRoomBlock)(int errorCode, NSDictionary * _Nullable extendedData);

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMZGCallManager : NSObject

#pragma mark - 单例
+ (instancetype)sharedManager;

#pragma mark - 方法与属性

/// SDK基础配置
/// - Parameter config: 配置信息
- (void)configSDKWith:(NoaIMZGCallConfig *)config;

/// 创建 ZegoExpressEngine 单例对象并初始化 SDK(第一步)
/// - Parameters:
///   - callOptions: 房间相关参数
///   - roomDelegate: 服从代理者
- (void)callRoomCreateEngineWithOptions:(NoaIMZGCallOptions *)callOptions delegate:(id <ZegoEventHandler> _Nullable)roomDelegate;

/// 登录房间(第二步)
- (void)callRoomLoginRoom:(LingIMZGLoginRoomBlock)block;

/// 开始推流(第三步)
- (void)callRoomStartPublish;

/// 停止推流
- (void)callRoomStopPublish;

/// 退出房间
- (void)callRoomLogout;

/// 开始拉流
/// - Parameter streamID: 流ID
/// - Parameter viewPreview: 预览流控件
- (void)callRoomStartPlayingStream:(NSString *)streamID with:(UIView *)viewPreview;

/// 停止拉流
- (void)callRoomStopPlayingStram:(NSString *)streamID;

/// 服从代理
/// - Parameter roomDelegate: 服从代理者
- (void)callRoomDelegate:(id <ZegoEventHandler>)roomDelegate;

/// 开始视频预览
/// - Parameter viewPreview: 展示预览view
- (void)callRoomStartPreviewWith:(UIView *)viewPreview;

/// 停止视频预览
- (void)callRoomStopPreview;

/// 用户房间类型
- (LingIMCallType)callRoomType;

/// 用户麦克风静默 开启/关闭
- (void)callRoomMicrophoneMute:(BOOL)mute;

/// 用户麦克风状态
- (LingIMCallMicrophoneMuteState)callRoomMicrophoneState;

/// 用户摄像头静默 开启/关闭
- (void)callRoomCameraMute:(BOOL)mute;

/// 用户摄像头状态
- (LingIMCallCameraMuteState)callRoomCameraState;

/// 用户使用前置摄像头
- (void)callRoomCameraUseFront:(BOOL)frontEnable;

/// 摄像头方向
- (LingIMCallCameraDirection)callRoomCameraDirection;


/// 用户扬声器静默 开启/关闭
- (void)callRoomSpeakerMute:(BOOL)mute;

/// 用户扬声器状态
- (LingIMCallSpeakerMuteState)callRoomSpeakerState;
@end

NS_ASSUME_NONNULL_END
