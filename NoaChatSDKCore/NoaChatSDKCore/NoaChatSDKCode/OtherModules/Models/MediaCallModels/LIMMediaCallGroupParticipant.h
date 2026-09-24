//
//  LIMMediaCallGroupParticipant.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/8.
//

// 多人音视频 房间成员 信息 model

#import <Foundation/Foundation.h>
#import "LIMMediaCallGroupParticipant.h"

NS_ASSUME_NONNULL_BEGIN

@interface LIMMediaCallGroupParticipant : NSObject
@property (nonatomic, assign) NSInteger status;//状态(0呼叫中 1已加入)
@property (nonatomic, copy) NSString *userUid;//用户ID

@end

NS_ASSUME_NONNULL_END
