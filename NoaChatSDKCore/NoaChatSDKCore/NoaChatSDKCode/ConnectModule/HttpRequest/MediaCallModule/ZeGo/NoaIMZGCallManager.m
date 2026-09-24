//
//  NoaIMZGCallManager.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/18.
//

#import "NoaIMZGCallManager.h"
#import "LingIMMacorHeader.h"

@interface NoaIMZGCallManager ()
//SDK基本信息和配置信息
@property (nonatomic, assign) unsigned int configAppId;//app唯一标识
@property (nonatomic, copy) NSString *configAppSign;//app的鉴权秘钥
@property (nonatomic, copy) NSString *configServerSecret;//后台服务请求接口的鉴权校验
@property (nonatomic, copy) NSString *configCallbackSecret;//后台服务回调接口的鉴权校验
@property (nonatomic, copy) NSString *configServerAddress;//服务器的 WebSocket 通信地址
@property (nonatomic, copy) NSString *configServerAddressBackup;//服务器的 WebSocket 通信地址 备用

@property (nonatomic, copy) NSString *callRoomID;//音视频房间ID
@property (nonatomic, copy) NSString *callRoomToken;//音视频房间令牌token
@property (nonatomic, copy) NSString *callRoomUserID;//音视频房间用户ID
@property (nonatomic, copy) NSString *callRoomUserNickname;//音视频房间用户昵称
@property (nonatomic, copy) NSString *callRoomStreamID;//音视频房间轨道流ID
@property (nonatomic, assign) LingIMCallType callType;//音视频类型
@property (nonatomic, assign) LingIMCallMicrophoneMuteState callMicState;//麦克风状态
@property (nonatomic, assign) LingIMCallCameraMuteState callCameraState;//摄像头状态
@property (nonatomic, assign) LingIMCallCameraDirection callCameraDirection;//摄像头方向
@property (nonatomic, assign) LingIMCallSpeakerMuteState callSpeakerState;//扬声器状态
@end

@implementation NoaIMZGCallManager
#pragma mark - 单例>>>>>>
+ (instancetype)sharedManager {
    static NoaIMZGCallManager *_manager = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        
        //默认使用内置
        [_manager callRoomMicrophoneMute:YES];
    });
    
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMZGCallManager sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMZGCallManager sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMZGCallManager sharedManager];
}

#pragma mark - <<<<<<方法与属性>>>>>>
#pragma mark - SDK基础配置
- (void)configSDKWith:(NoaIMZGCallConfig *)config {
    if (config) {
        _configAppId = config.configAppId;
        _configAppSign = config.configAppSign;
        _configServerSecret = config.configServerSecret;
        _configCallbackSecret = config.configCallbackSecret;
        _configServerAddress = config.configServerAddress;
        _configServerAddressBackup = config.configServerAddressBackup;
    }
}

#pragma mark - 方法与属性创建 ZegoExpressEngine 单例对象并初始化 SDK(第一步)
- (void)callRoomCreateEngineWithOptions:(NoaIMZGCallOptions *)callOptions delegate:(id <ZegoEventHandler>)roomDelegate {
    if (callOptions) {
        
        _callRoomID = callOptions.callRoomID;
        _callRoomToken = callOptions.callRoomToken;
        _callRoomUserID = callOptions.callRoomUserID;
        _callRoomUserNickname = callOptions.callRoomUserNickname;
        _callRoomStreamID = callOptions.callRoomUserStreamID;
        _callType = callOptions.callType;
        _callMicState = callOptions.callMicState;
        _callCameraState = callOptions.callCameraState;
        _callCameraDirection = callOptions.callCameraDirection;
        _callSpeakerState = callOptions.callSpeakerState;
        
        ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
        //appID (范围 0 到 4294967295，如果以后这个地方出问题，可以看看SDK是否修改了appID的数据类型)
        profile.appID = _configAppId;//无符号类型 int
        //场景
        profile.scenario = ZegoScenarioDefault;
        //创建引擎
        [ZegoExpressEngine createEngineWithProfile:profile eventHandler:roomDelegate];
        
    }else {
        CIMLog(@"LIMZGCALL:参数错误");
    }
}

#pragma mark - 登录房间(第二步)
- (void)callRoomLoginRoom:(LingIMZGLoginRoomBlock)block {
    if (_callRoomID.length > 0 && _callRoomUserID.length > 0 && _callRoomToken.length > 0 && _callRoomUserNickname.length > 0) {
        //创建用户对象(此构造方法将userID和userName赋值一样)
        ZegoUser *user = [ZegoUser userWithUserID:_callRoomUserID userName:_callRoomUserNickname];
        //房间参数
        ZegoRoomConfig *roomConfig = [[ZegoRoomConfig alloc] init];
        roomConfig.isUserStatusNotify = YES;
        roomConfig.token = _callRoomToken;
        //登录房间
        [[ZegoExpressEngine sharedEngine] loginRoom:_callRoomID user:user config:roomConfig callback:^(int errorCode, NSDictionary * _Nonnull extendedData) {
            
           //可选回调，登录房间结果，如果仅关注登录结果，关注此回调即可
            if (errorCode == 0) {
                CIMLog(@"LIMZGCALL:房间登录成功");
            }else {
                CIMLog(@"LIMZGCALL:房间登录失败");
            }
            
            if (block) {
                block(errorCode, extendedData);
            }
            
        }];
        
    }else {
        CIMLog(@"LIMZGCALL:缺少房间相关参数");
    }
}

#pragma mark - 开始推流(第三步)
- (void)callRoomStartPublish {
    if (_callRoomStreamID.length > 0) {
        //用户调用 loginRoom 之后再调用此接口进行推流
        //在同一个 AppID 下，开发者需要保证 “streamID” 全局唯一，如果不同用户各推了一条 “streamID” 相同的流，后推流的用户会推流失败
        //[[ZegoExpressEngine sharedEngine] startPublishingStream:_callRoomStreamID];
        ZegoPublisherConfig *publisherConfig = [ZegoPublisherConfig new];
        if (_callType == LingIMCallTypeAudio) {
            publisherConfig.streamCensorshipMode = ZegoStreamCensorshipModeAudio;//音频通话
        }else if (_callType == LingIMCallTypeVideo) {
            publisherConfig.streamCensorshipMode = ZegoStreamCensorshipModeAudioAndVideo;//音视频通话
        }else {
            publisherConfig.streamCensorshipMode = ZegoStreamCensorshipModeNone;//无音频 无视频
        }
        [[ZegoExpressEngine sharedEngine] startPublishingStream:_callRoomStreamID config:publisherConfig channel:ZegoPublishChannelMain];
        
        //默认状态
        //麦克风
        BOOL muteMic = _callMicState == LingIMCallMicrophoneMuteStateOn ? YES : NO;
        [self callRoomMicrophoneMute:muteMic];
        
        //扬声器
        BOOL muteSpeaker = _callSpeakerState == LingIMCallSpeakerMuteStateOn ? YES : NO;
        [self callRoomSpeakerMute:muteSpeaker];
        
        if (_callType == LingIMCallTypeVideo) {
            //相机
            BOOL muteCamera = _callCameraState == LingIMCallCameraMuteStateOn ? YES : NO;
            [self callRoomCameraMute:muteCamera];
            //摄像头方向
            BOOL frontCamera = _callCameraDirection == LingIMCallCameraDirectionFront ? YES : NO;
            [self callRoomCameraUseFront:frontCamera];
        }
        
    }else {
        CIMLog(@"LIMZGCALL:缺少房间推流参数");
    }
}

#pragma mark - 停止推流
- (void)callRoomStopPublish {
    [[ZegoExpressEngine sharedEngine] stopPublishingStream];
    
}

#pragma mark - 退出房间
- (void)callRoomLogout {
    //退出房间
    [[ZegoExpressEngine sharedEngine] logoutRoom];
    //销毁 ZegoExpressEngine 单例对象并反初始化 SDK
    [ZegoExpressEngine destroyEngine:^{
    }];
}

#pragma mark - 开始拉流
- (void)callRoomStartPlayingStream:(NSString *)streamID with:(UIView *)viewPreview{
    if (self.callType == LingIMCallTypeAudio) {
        //音频通话
        [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID];
    }else {
        //视频通话
        ZegoCanvas *previewCanvas = [ZegoCanvas canvasWithView:viewPreview];
        previewCanvas.viewMode = ZegoViewModeAspectFill;//等比缩放填充整个 View，可能有部分被裁减
        [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:previewCanvas];
    }
    
    //ZegoPlayerConfig *config = [[ZegoPlayerConfig alloc] init];
    //config.resourceMode = ZegoStreamResourceModeOnlyRTC;
    //config.roomID = roomID;
    //[[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:previewCanvas config:config];
    
}

#pragma mark - 停止拉流
- (void)callRoomStopPlayingStram:(NSString *)streamID {
    [[ZegoExpressEngine sharedEngine] stopPlayingStream:streamID];
}
#pragma mark - 服从代理
- (void)callRoomDelegate:(id <ZegoEventHandler>)roomDelegate {
    if (roomDelegate) {
        [[ZegoExpressEngine sharedEngine] setEventHandler:roomDelegate];
    }
}

#pragma mark - 开始视频预览
- (void)callRoomStartPreviewWith:(UIView *)viewPreview {
    if (self.callType == LingIMCallTypeAudio) {
        //音频通话
        [[ZegoExpressEngine sharedEngine] startPreview];
    }else {
        //视频通话
        // 设置本地预览视图并启动预览，视图模式采用 SDK 默认的模式，等比缩放填充整个 View
        ZegoCanvas *previewCanvas = [ZegoCanvas canvasWithView:viewPreview];
        previewCanvas.viewMode = ZegoViewModeAspectFill;//等比缩放填充整个 View，可能有部分被裁减
        //可进行参数配置
        [[ZegoExpressEngine sharedEngine] startPreview:previewCanvas];
    }
}

#pragma mark - 停止视频预览
- (void)callRoomStopPreview {
    [[ZegoExpressEngine sharedEngine] stopPreview];
}

#pragma mark - 用户房间类型
- (LingIMCallType)callRoomType {
    return _callType;
}

#pragma mark - 用户麦克风静默 开启/关闭
- (void)callRoomMicrophoneMute:(BOOL)mute {
    [[ZegoExpressEngine sharedEngine] muteMicrophone:mute];
    //mute YES 静默开启
    _callMicState = mute ? LingIMCallMicrophoneMuteStateOn : LingIMCallMicrophoneMuteStateOff;
}

#pragma mark - 用户麦克风状态
- (LingIMCallMicrophoneMuteState)callRoomMicrophoneState {
    return _callMicState;
}

#pragma mark - 用户摄像头静默 开启/关闭
- (void)callRoomCameraMute:(BOOL)mute {
    //使用该方法会保持摄像头的状态，且不影响操作摄像头方向的改变
    [[ZegoExpressEngine sharedEngine] mutePublishStreamVideo:mute];
    //mute YES 静默开启
    _callCameraState = mute ? LingIMCallCameraMuteStateOn : LingIMCallCameraMuteStateOff;
    
    //[[ZegoExpressEngine sharedEngine] enableCamera:!mute];
}

#pragma mark - 用户摄像头状态
- (LingIMCallCameraMuteState)callRoomCameraState {
    return _callCameraState;
}

#pragma mark - 用户使用前置摄像头
- (void)callRoomCameraUseFront:(BOOL)frontEnable {
    [[ZegoExpressEngine sharedEngine] useFrontCamera:frontEnable];
    //frontEnable YES 前置摄像头
    _callCameraDirection = frontEnable ? LingIMCallCameraDirectionFront : LingIMCallCameraDirectionBack;
}

#pragma mark - 摄像头方向
- (LingIMCallCameraDirection)callRoomCameraDirection {
    return _callCameraDirection;
}

#pragma mark - 用户扬声器静默 开启/关闭
- (void)callRoomSpeakerMute:(BOOL)mute {
    [[ZegoExpressEngine sharedEngine] setAudioRouteToSpeaker:!mute];
    //mute YES 静默开启
    _callSpeakerState = mute ? LingIMCallSpeakerMuteStateOn : LingIMCallSpeakerMuteStateOff;
}

#pragma mark - 用户扬声器状态
- (LingIMCallSpeakerMuteState)callRoomSpeakerState {
    return _callSpeakerState;
}

@end
