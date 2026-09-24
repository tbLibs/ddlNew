//
//  LIMMediaCallGroupParticipantAction.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/9.
//

#import <Foundation/Foundation.h>
#import "LIMMediaCallGroupParticipant.h"

NS_ASSUME_NONNULL_BEGIN

@interface LIMMediaCallGroupParticipantAction : NSObject
//房间成员有动作参数(103自定义事件)
@property (nonatomic, assign) NSInteger mode;//音视频通话类型 0音视频 1音频
@property (nonatomic, copy) NSString *hashKey;//唯一标识id
@property (nonatomic, copy) NSString *chat_id;//所属群id
@property (nonatomic, strong) NSArray <NSString *> *participants;//所有参与者ID, 包括房主和呼叫中的(action = ""的时候有值)
@property (nonatomic, copy) NSString *action;//多人音视频通话动作
/*
 new: 发起通话 user_id:发起者
 join: 新成员加入 user_id:加入通话的成员
 leave: 成员离开 user_id:离开通话的成员
 discard: 通话结束,隐藏通话信息条 user_id:结束通话的成员
 */
@property (nonatomic, copy) NSString *user_id;//本次动作的主角
@end

NS_ASSUME_NONNULL_END
