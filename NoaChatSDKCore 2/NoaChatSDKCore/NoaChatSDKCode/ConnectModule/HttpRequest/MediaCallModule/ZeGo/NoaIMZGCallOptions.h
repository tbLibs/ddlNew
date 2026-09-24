//
//  NoaIMZGCallOptions.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/18.
//

#import <Foundation/Foundation.h>
#import "LingIMCallHeader.h"



NS_ASSUME_NONNULL_BEGIN

@interface NoaIMZGCallOptions : NSObject

//房间信息
@property (nonatomic, assign) LingIMCallRoomType callRoomType;//当前通话 房间类型
@property (nonatomic, assign) LingIMCallType callType;//当前通话 音视频类型
@property (nonatomic, copy) NSString *callRoomCreateUserID;//当前通话 房间创建者ID
@property (nonatomic, copy) NSString *callID;//当前通话 ID
@property (nonatomic, copy) NSString *callRoomID;//当前通话 房间ID
@property (nonatomic, copy) NSString *callRoomToken;//当前通话 房间令牌token
@property (nonatomic, assign) NSInteger callStatus;//当前通话 通话状态 1:待接通，2:取消，3:超时未应答，4:拒绝，5:挂断，6:接受，7:通话中断,8:其他设备已接听
@property (nonatomic, assign) NSInteger callTimeout;//当前通话 呼叫超时时间
@property (nonatomic, assign) NSInteger callDuration;//当前通话 通话时长

//用户信息
@property (nonatomic, copy) NSString *callRoomUserID;//音视频房间 用户 ID
@property (nonatomic, copy) NSString *callRoomUserNickname;//音视频房间 用户 昵称
@property (nonatomic, copy) NSString *callRoomUserStreamID;//音视频房间 用户 轨道流ID

//用户推流 硬件状态 
@property (nonatomic, assign) LingIMCallMicrophoneMuteState callMicState;//麦克风状态
@property (nonatomic, assign) LingIMCallCameraMuteState callCameraState;//摄像头状态
@property (nonatomic, assign) LingIMCallCameraDirection callCameraDirection;//摄像头方向
@property (nonatomic, assign) LingIMCallSpeakerMuteState callSpeakerState;//扬声器状态

@end

NS_ASSUME_NONNULL_END
