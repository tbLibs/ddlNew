//
//  LingIMCallHeader.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/18.
//

#ifndef LingIMCallHeader_h
#define LingIMCallHeader_h

//SDK类型
typedef NS_ENUM(NSUInteger, LingIMCallSDKType) {
    LingIMCallSDKTypeDefault = 0,          //占位，未知SDK
    LingIMCallSDKTypeLiveKit = 1,          //LiveKit 实现音视频
    LingIMCallSDKTypeZego = 2,             //ZEGO 实现音视频
};

//多媒体会话房间类型
typedef NS_ENUM(NSUInteger, LingIMCallRoomType) {
    LingIMCallRoomTypeSingle = 1,        //单人房间
    LingIMCallRoomTypeGroup = 2,         //多人房间
    LingIMCallRoomTypeMeeting = 3,       //会议房间
};

//多媒体会话类型
typedef NS_ENUM(NSUInteger, LingIMCallType) {
    LingIMCallTypeAudio = 1,        //音频通话(音频)
    LingIMCallTypeVideo = 2,        //视频通话(视频+音频)
};

//多媒体会话角色
typedef NS_ENUM(NSUInteger, LingIMCallRoleType) {
    LingIMCallRoleTypeRequest = 1,      //发起音视频方
    LingIMCallRoleTypeResponse = 2,     //响应音视频方
};

//麦克风静默状态
typedef NS_ENUM(NSUInteger, LingIMCallMicrophoneMuteState) {
    LingIMCallMicrophoneMuteStateOn = 1,   //麦克风关闭(静默打开)
    LingIMCallMicrophoneMuteStateOff = 2,  //麦克风打开(静默关闭)
};

//摄像头静默状态
typedef NS_ENUM(NSUInteger, LingIMCallCameraMuteState) {
    LingIMCallCameraMuteStateOn = 1,      //摄像头关闭(静默打开)
    LingIMCallCameraMuteStateOff = 2,     //摄像头打开(静默关闭)
};

//摄像头方向
typedef NS_ENUM(NSUInteger, LingIMCallCameraDirection) {
    LingIMCallCameraDirectionFront = 1,   //前置摄像头
    LingIMCallCameraDirectionBack = 2,    //后置摄像头
};

//扬声器静默状态(外放声音)
typedef NS_ENUM(NSUInteger, LingIMCallSpeakerMuteState) {
    LingIMCallSpeakerMuteStateOn = 1,    //扬声器关闭(静默打开)
    LingIMCallSpeakerMuteStateOff = 2,   //扬声器打开(静默关闭)
};

#endif /* LingIMCallHeader_h */
