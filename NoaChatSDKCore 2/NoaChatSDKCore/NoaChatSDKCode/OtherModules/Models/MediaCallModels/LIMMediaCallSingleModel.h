//
//  LIMMediaCallSingleModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/3.
//

// 音视频通话 - 单人模式

#import <Foundation/Foundation.h>
#import "LIMMediaCallRoomInfoModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface LIMMediaCallSingleModel : NSObject

@property (nonatomic, assign) NSInteger mode;//音视频通话类型 0音视频 1音频
@property (nonatomic, copy) NSString *state;//音视频通话状态 request请求、waiting等待、accept接受、confirm确认、discard断开连接
@property (nonatomic, copy) NSString *hashKey;//音视频通话唯一标识id
@property (nonatomic, copy) NSString *from_id;//音视频通话发起者(邀请者)
@property (nonatomic, copy) NSString *to_id;//音视频通话对方接收者(被邀请者)
@property (nonatomic, strong) LIMMediaCallRoomInfoModel *connection;//音视频通房间地址和token
@property (nonatomic, copy) NSString *discard_reason;//音视频通结束原因
/*
 "": 空字符串, 通话建立之后正常挂断
 //告知 邀请者 展示 如：10:00通话
 //告知 被邀请者 展示 如：10:00通话
 
 disconnect: 通话中断, 服务器强制挂断
 //告知 邀请者 展示 如：通话中断
 //告知 被邀请者 展示 如：通话中断
 
 missed: 对方无应答, 客户端主叫方呼叫超时挂断
 //告知 邀请者 展示 如：对方无应答
 //告知 被邀请者 展示 如：超时未应答
 
 cancel: 通话已取消, 主叫方取消通话
 //告知 邀请者 展示 如：通话已取消
 //告知 被邀请者 展示 如：对方已取消
 
 refused: 对方已拒绝
 //告知 邀请者 展示 如：对方已拒绝
 //告知 被邀请者 展示 如：已拒绝
 
 accept: 已在其他设备接听
 //告知 被邀请者 展示 如：已在其他设备接听
*/
@property (nonatomic, assign) NSInteger duration;//通话时长(秒)

@end


NS_ASSUME_NONNULL_END

