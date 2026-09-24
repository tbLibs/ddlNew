//
//  NoaIMCallOptions.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/5.
//

#import <Foundation/Foundation.h>
#import "LingIMCallHeader.h"


NS_ASSUME_NONNULL_BEGIN

@interface NoaIMCallOptions : NSObject

@property (nonatomic, copy) NSString *callRoomUrl;//音视频房间地址
@property (nonatomic, copy) NSString *callRoomToken;//音视频房间令牌token
@property (nonatomic, assign) LingIMCallType callType;//音视频类型
@property (nonatomic, assign) LingIMCallRoleType callRoleType;//音视频角色类型
@property (nonatomic, assign) LingIMCallMicrophoneMuteState callMicState;//音频状态
@property (nonatomic, assign) LingIMCallCameraMuteState callCameraState;//视频状态

@end

NS_ASSUME_NONNULL_END
