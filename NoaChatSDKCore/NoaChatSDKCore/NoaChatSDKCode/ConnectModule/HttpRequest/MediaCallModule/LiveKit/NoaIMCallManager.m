//
//  NoaIMCallManager.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/5.
//

#import "NoaIMCallManager.h"
#import "LingIMMacorHeader.h"

@interface NoaIMCallManager ()
@property (nonatomic, copy) NSString *callRoomUrl;//音视频房间地址
@property (nonatomic, copy) NSString *callRoomToken;//音视频房间令牌token
@property (nonatomic, assign) LingIMCallType callType;//房间类型
@property (nonatomic, assign) LingIMCallRoleType callRoleType;//房间角色类型
@property (nonatomic, assign) LingIMCallMicrophoneMuteState callMicState;//音频状态
@property (nonatomic, assign) LingIMCallCameraMuteState callCameraState;//视频状态
@property (nonatomic, assign) BOOL isSpeaker;
@end

@implementation NoaIMCallManager
#pragma mark - 单例>>>>>>
+ (instancetype)sharedManager {
    static NoaIMCallManager *_manager = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        //默认听筒模式
        [_manager callRoomAudioExternalOff];
    });
    
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMCallManager sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMCallManager sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMCallManager sharedManager];
}

#pragma mark - 方法与属性>>>>>>

#pragma mark - 用户连接房间
- (void)callRoomConnectWithOptions:(NoaIMCallOptions *)callOptions delegate:(id<RoomDelegateObjC>)roomDelegateObjc {
    if (callOptions && roomDelegateObjc) {
        __weak typeof(self) weakSelf = self;
        
        
        //发起音视频聊天房间信息
        _callRoomUrl = callOptions.callRoomUrl;
        _callRoomToken = callOptions.callRoomToken;
        _callType = callOptions.callType;
        _callRoleType = callOptions.callRoleType;
        _callMicState = callOptions.callMicState;
        _callCameraState = callOptions.callCameraState;
        CIMLog(@"LIMCALL:连接房间信息-地址：%@",_callRoomUrl);
        CIMLog(@"LIMCALL:连接房间信息-token：%@",_callRoomToken);
        
        if (!(_callRoomUrl.length > 0 && _callRoomToken.length > 0)) {
            CIMLog(@"LIMCALL:请配置正确的房间信息");
            return;
        }
        
        //房间代理
        [self.callRoom addDelegate:roomDelegateObjc];
        
        //房间配置参数
        ConnectOptions *roomConnectOptions = [[LingIMCallOptionsManager sharedManager] configConnectOptions];
        RoomOptions *roomOptions = [[LingIMCallOptionsManager sharedManager] configRoomOptions];
        
        //连接房间
        FBLPromise <Room *> *roomConnectPromise = [self.callRoom connectWithURL:_callRoomUrl token:_callRoomToken connectOptions:roomConnectOptions  roomOptions:roomOptions];
        
        FBLPromise *promise = [roomConnectPromise then:^id _Nullable(Room * _Nullable callRoom) {
            CIMLog(@"LIMCALL:连接房间成功，开启本地视频、音频");
            [weakSelf callRoomConnectSuccessDefaultConfigWith:callRoom];
            return nil;
        }];
        
        [promise catch:^(NSError * _Nonnull error) {
            CIMLog(@"LIMCALL:连接房间失败，失败信息：%@",error);
        }];
        
    }else {
        CIMLog(@"LIMCALL:参数错误");
    }
}
//房间连接成功后默认配置
- (void)callRoomConnectSuccessDefaultConfigWith:(Room *)callRoom {
    if (_callType == LingIMCallTypeAudio) {
        //音频
        [callRoom.localParticipant setMicrophoneEnabled:_callMicState == LingIMCallMicrophoneMuteStateOn ? NO : YES];
    }else {
        //视频
        [callRoom.localParticipant setMicrophoneEnabled:_callMicState == LingIMCallMicrophoneMuteStateOn ? NO : YES];
        [callRoom.localParticipant setCameraEnabled:_callCameraState == LingIMCallCameraMuteStateOn ? NO : YES];
    }
    
}
#pragma mark - 服从代理
- (void)callRoomDelegate:(id<RoomDelegateObjC>)roomDelegateObjc {
    if (roomDelegateObjc) {
        //房间代理
        [self.callRoom addDelegate:roomDelegateObjc];
    }
}
#pragma mark - 用户房间连接状态
- (ConnectionState)callRoomConnectState {
    return self.callRoom.connectionState;
}

#pragma mark - 用户房间类型
- (LingIMCallType)callRoomType {
    return _callType;
}

#pragma mark - 用户房间角色类型
- (LingIMCallRoleType)callRoomRoleType {
    return _callRoleType;
}

#pragma mark - 用户断开房间的连接
- (void)callRoomDisconnect {
    [self.callRoom disconnect];
}


#pragma mark - 用户音频关闭
- (void)callRoomAudioMuteOn:(void (^)(BOOL))muteBlock {
    
    __weak typeof(self) weakSelf = self;
    
    LocalParticipant *localParticipant = self.callRoom.localParticipant;
    if (localParticipant) {
        FBLPromise <LocalTrackPublication *> *roomMicrophonePromise = [localParticipant setMicrophoneEnabled:NO];
        FBLPromise *promise = [roomMicrophonePromise then:^id _Nullable(LocalTrackPublication * _Nullable value) {
            CIMLog(@"LIMCALL:音频关闭成功");
            weakSelf.callMicState = LingIMCallMicrophoneMuteStateOn;
            if (muteBlock) {
                muteBlock(YES);
            }
            return nil;
        }];
        
        [promise catch:^(NSError * _Nonnull error) {
            CIMLog(@"LIMCALL:音频关闭失败，失败信息：%@",error);
            if (muteBlock) {
                muteBlock(NO);
            }
        }];
    }else {
        CIMLog(@"LIMCALL:本地参与者不存在");
        if (muteBlock) {
            muteBlock(NO);
        }
    }
    
}

#pragma mark - 用户音频打开
- (void)callRoomAudioMuteOff:(void (^)(BOOL))muteBlock {
    
    __weak typeof(self) weakSelf = self;
    
    LocalParticipant *localParticipant = self.callRoom.localParticipant;
    if (localParticipant) {
        FBLPromise <LocalTrackPublication *> *roomMicrophonePromise = [localParticipant setMicrophoneEnabled:YES];
        FBLPromise *promise = [roomMicrophonePromise then:^id _Nullable(LocalTrackPublication * _Nullable value) {
            CIMLog(@"LIMCALL:音频打开成功");
            weakSelf.callMicState = LingIMCallMicrophoneMuteStateOff;
            if (muteBlock) {
                muteBlock(YES);
            }
            return nil;
        }];
        
        [promise catch:^(NSError * _Nonnull error) {
            CIMLog(@"LIMCALL:音频打开失败，失败信息：%@",error);
            if (muteBlock) {
                muteBlock(NO);
            }
        }];
    }else {
        CIMLog(@"LIMCALL:本地参与者不存在");
        if (muteBlock) {
            muteBlock(NO);
        }
    }
    
}

#pragma mark - 用户音频状态
- (LingIMCallMicrophoneMuteState)callRoomAudioState {
    return _callMicState;
}

#pragma mark - 用户视频关闭
- (void)callRoomVideoMuteOn:(void (^)(BOOL))muteBlock {
    
    __weak typeof(self) weakSelf = self;
    
    LocalParticipant *localParticipant = self.callRoom.localParticipant;
    if (localParticipant) {
        FBLPromise <LocalTrackPublication *> *roomCameraPromise = [localParticipant setCameraEnabled:NO];
        FBLPromise *promise = [roomCameraPromise then:^id _Nullable(LocalTrackPublication * _Nullable value) {
            CIMLog(@"LIMCALL:视频关闭成功");
            weakSelf.callCameraState = LingIMCallCameraMuteStateOn;
            if (muteBlock) {
                muteBlock(YES);
            }
            return nil;
        }];
        
        [promise catch:^(NSError * _Nonnull error) {
            CIMLog(@"LIMCALL:视频关闭失败，失败信息：%@",error);
            if (muteBlock) {
                muteBlock(NO);
            }
        }];
    }else {
        CIMLog(@"LIMCALL:本地参与者不存在");
        if (muteBlock) {
            muteBlock(NO);
        }
    }
    
}

#pragma mark - 用户视频打开
- (void)callRoomVideoMuteOff:(void (^)(BOOL))muteBlock {
    
    __weak typeof(self) weakSelf = self;
    
    LocalParticipant *localParticipant = self.callRoom.localParticipant;
    if (localParticipant) {
        FBLPromise <LocalTrackPublication *> *roomCameraPromise = [localParticipant setCameraEnabled:YES];
        FBLPromise *promise = [roomCameraPromise then:^id _Nullable(LocalTrackPublication * _Nullable value) {
            CIMLog(@"LIMCALL:视频打开成功");
            weakSelf.callCameraState = LingIMCallCameraMuteStateOff;
            if (muteBlock) {
                muteBlock(YES);
            }
            return nil;
        }];
        
        [promise catch:^(NSError * _Nonnull error) {
            CIMLog(@"LIMCALL:视频打开失败，失败信息：%@",error);
            if (muteBlock) {
                muteBlock(NO);
            }
        }];
    }else {
        CIMLog(@"LIMCALL:本地参与者不存在");
        if (muteBlock) {
            muteBlock(NO);
        }
    }
    
}
#pragma mark - 用户视频状态
- (LingIMCallCameraMuteState)callRoomVideoState {
    return _callCameraState;
}

#pragma mark - 用户改变视频摄像头方向
- (void)callRoomVideoCameraSwitch:(void (^)(BOOL))switchResultBlock {
    
    LocalTrackPublication *localTrack = self.callRoom.localParticipant.localVideoTracks.firstObject;
    
    LocalVideoTrack *videoTrack = (LocalVideoTrack *)localTrack.track;
    CameraCapturer *capture = (CameraCapturer *)videoTrack.capturer;
    
    if (capture && [CameraCapturer canSwitchPosition]) {
        FBLPromise <NSNumber *> *roomCameraPromise = [capture switchCameraPosition];
        FBLPromise *promise = [roomCameraPromise then:^id _Nullable(NSNumber * _Nullable value) {
            CIMLog(@"LIMCALL:切换摄像头成功");
            if (switchResultBlock) {
                switchResultBlock(YES);
            }
            
            return nil;
        }];
        
        [promise catch:^(NSError * _Nonnull error) {
            CIMLog(@"LIMCALL:切换摄像头失败，失败信息：%@",error);
            if (switchResultBlock) {
                switchResultBlock(NO);
            }
        }];
    }
    
    
}

#pragma mark - 用户使用听筒模式(外放关闭)
- (void)callRoomAudioExternalOff {
    [[LingIMCallOptionsManager sharedManager] configAudioOutSpeakerWithSpeaker:NO];
}

#pragma mark - 用户使用扬声器模式(外放打开)
- (void)callRoomAudioExternalOn {
    [[LingIMCallOptionsManager sharedManager] configAudioOutSpeakerWithSpeaker:YES];
}

#pragma mark - 获取房间远端流数组
- (NSArray *)callRoomGetRemoteParticipants {
    return [[LingIMCallOptionsManager sharedManager] getRoomRemoteParticipantsWithRoom:self.callRoom];
}

#pragma mark - 懒加载
-  (Room *)callRoom {
    
    if (!_callRoom) {
        _callRoom = [[Room alloc] init];
    }
    return _callRoom;
    
}
@end
