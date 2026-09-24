//
//  LIMMediaCallGroupModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/8.
//

// 音视频通话 - 多人模式

#import <Foundation/Foundation.h>
#import "LIMMediaCallRoomInfoModel.h"
#import "LIMMediaCallGroupParticipant.h"

NS_ASSUME_NONNULL_BEGIN

@interface LIMMediaCallGroupModel : NSObject
@property (nonatomic, copy) NSString *hashKey;//唯一标识id
@property (nonatomic, copy) NSString *chat_id;//所属群id
@property (nonatomic, strong) NSArray <LIMMediaCallGroupParticipant *> *participants;//所有参与者ID, 包括房主和呼叫中的
@property (nonatomic, assign) NSInteger mode;//类型 0音视频 1音频
@property (nonatomic, assign) NSInteger stage;//当前处于什么阶段(0呼叫中 1通话已建立)
@property (nonatomic, strong) LIMMediaCallRoomInfoModel *connection;//房间地址和token
@property (nonatomic, assign) NSInteger duration;//通话时长(秒)
@property (nonatomic, strong) NSArray *args;//本次 动作 的参数, 邀请，加入，离开通话 [user_id]
@property (nonatomic, copy) NSString *action;//多人音视频通话 动作
/*
 request: 您有新的通话 args[0] = 邀请者ID(发起邀请的人)
 invite: 邀请多人 args[] = [被邀请者IDS]
 join: 接听或加入 args[0] = 新成员ID
 leave: 成员离开通话 args[0] = 离开者ID
 discard: 通话结束
 */
@property (nonatomic, copy) NSString *reason;//挂断或离开原因
/*
 discard挂断原因
 "": 空字符串, 通话建立之后正常挂断
 accept: 已在其他设备接听
 */
/*
 leave离开原因
 "": 空字符串，通话建立之后正常挂断，离开房间
 refused: 拒绝接听
 timeout: 呼叫超时
 */


@end

NS_ASSUME_NONNULL_END
