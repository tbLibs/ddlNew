//
//  LIMMediaCallModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/9.
//

#import <Foundation/Foundation.h>
#import "LIMMediaCallSingleModel.h"//单人音视频
#import "LIMMediaCallGroupModel.h"//多人音视频
#import "LIMMediaCallMeetingModel.h"//会议音视频

#import "LIMMediaCallGroupParticipantAction.h"//多人音视频参与者改变

NS_ASSUME_NONNULL_BEGIN

@interface LIMMediaCallModel : NSObject

//单人音视频通话101类型消息
@property (nonatomic, strong) LIMMediaCallSingleModel * _Nullable callSingleModel;

//多人音视频通话102类型消息
@property (nonatomic, strong) LIMMediaCallGroupModel * _Nullable callGroupModel;

//多人音视频通话103类型消息
@property (nonatomic, strong) LIMMediaCallGroupParticipantAction *callGroupParticipantActionModel;

//会议音视频通话(以后拓展)
@property (nonatomic, strong) LIMMediaCallMeetingModel * _Nullable callMeetingModel;

@end

NS_ASSUME_NONNULL_END
