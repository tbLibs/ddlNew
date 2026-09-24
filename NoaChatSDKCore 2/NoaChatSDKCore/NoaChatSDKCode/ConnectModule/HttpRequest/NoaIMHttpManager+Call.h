//
//  NoaIMHttpManager+Call.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/5.
//

// 音视频通话相关接口

#pragma mark - 单人音视频通话
/*
 A用户、B用户：A用户向B用户发起音视频通话
 
 1.A用户调用requestCall接口，成功后；
 B用户(多端)会收到一条消息：A用户想要和你进行音视频通话。
 
 2.B用户(某一端)处理这条消息，进入相关的UI界面：调用receiveCall接口，成功后；
 A用户会收到一条消息：B用户接收到了你的请求，请等待A用户的处理(拒绝/接受)
 
 3.1.B用户拒绝音视频通话：调用discardCall接口，成功后；
 A用户会收到一条消息：B用户拒绝了你的音视频通话请求。
 B用户其他端会接收到消息：你拒绝了A用户发来的音视频通话请求。
 AB用户分别处理自己的UI逻辑
 
 3.2.B用户接受了音视频通话：调用acceptCall接口，成功后；
 A用户会接收到一条消息：B用户接受了你的音视频通话请求。
 B用户其他端会收到消息：你已接受了A用户的音视频通话请求。
 A用户调用：confirmCall接口，成功后；
 AB用户会获得到房间的信息，进入房间进行音视频的通话
 AB用户分别处理自己的UI逻辑
 */

//发起音视频请求
#define Call_Phone_Request_Call_Url          @"/phone/requestCall"
//接收到音视频请求
#define Call_Phone_Receive_Call_Url          @"/phone/receiveCall"
//同意音视频请求
#define Call_Phone_Accept_Call_Url           @"/phone/acceptCall"
//拒绝音视频请求/结束音视频通话
#define Call_Phone_Discard_Call_Url          @"/phone/discardCall"
//确认音视频通话，创建房间
#define Call_Phone_Confirm_Call_Url          @"/phone/confirmCall"

#pragma mark - 多人音视频通话
/*
 A用户、B用户、C用户、D用户：A用户向BC用户发起多人音视频通话
 A用户调用group/request接口成功后，会创建音视频房间，同时BC用户会收到邀请消息
 BC用户分别调用group/accept或group/discard来加入或拒绝加入该音视频房间
 如果当前音视频房间有效，D用户可以通过调用group/join来加入房间；也可以通过ABC某用户来group/invite邀请加入房间
 */
//发起多人音视频通话
#define Call_Phone_Group_Request_Url          @"/phone/group/request"
//同意多人音视频通话
#define Call_Phone_Group_Accept_Url           @"/phone/group/accept"
//邀请加入多人音视频通话
#define Call_Phone_Group_Invite_Url           @"/phone/group/invite"
//主动加入多人音视频通话
#define Call_Phone_Group_Join_Url             @"/phone/group/join"
//主动结束通话/拒绝接听/离开房间
#define Call_Phone_Group_Discard_Url          @"/phone/group/discard"
//获取音视频通话信息
#define Call_Phone_Group_GetChatCall_Url      @"/phone/group/getChatCall"


#pragma mark - 即构SDK
//发起者创建通话
#define Call_Create_Url          @"/biz/call/create"
//发起者取消通话(通话未接听)
#define Call_Cancel_Url          @"/biz/call/cancel"
//被邀请者接听通话
#define Call_Accept_Url          @"/biz/call/accept"
//被邀请者拒绝通话(通话未接听)
#define Call_Reject_Url          @"/biz/call/reject"
//挂断通话
#define Call_Hang_Up_Url         @"/biz/call/hangUp"
//群聊 主动加入音视频通话
#define Call_Join_Url            @"/biz/call/join"
//群聊 邀请加入音视频通话
#define Call_Invite_Url          @"/biz/call/invite"
//群聊 查询某群是否有正在进行的群聊音视频通话
#define Call_GroupCallInfo_Url   @"/biz/call/getGroupNetCallInfo"
//根据callId获取某个用户的token鉴权信息
#define Call_CallInfoToken_Url   @"/biz/call/callInfo"
//SDK加入房间成功后，告知后端，我已成功完成了加入音视频聊天的整体流程
#define Call_ConfirmJoin_Url     @"/biz/call/confirmJoin"
//音视频通话心跳接口
#define Call_HheartBeat_Url      @"/biz/call/heartbeat"


#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (Call)

/// 用户发起音视频请求(告知对方，用户想要和对方进行音视频通话)
/// @param params 操作参数 {userUid:对方用户UID mode:通话模式 0音视频 1音频}
- (void)callRequestCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户响应对方发来的音视频请求(用户接收到对方发来的音视频通话的请求，进入音视频相关的UI，告知对方waiting等待用户接通音视频通话)
/// @param params 操作参数 {hash:本次通话标识}
- (void)callReceiveCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户接受对方发来的音视频请求(告知对方accept用户接通了音视频通话)
/// @param params 操作参数 {hash:本次通话标识}
- (void)callAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户确认音视频会话，创建房间(用户接收到对方已经接受了这次音视频通话，进行房间的创建)
/// @param params 操作参数 {hash:本次通话标识}
- (void)callConfirmCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户结束/音视频会话(告知对方，用户结束或拒绝与对方的音视频通话)
/// @param params 操作参数
/// {
/// hash:本次通话标识
/// reason:原因
/// 1."": 空字符串, 通话建立之后正常挂断
/// 2.disconnect: 通话中断, 服务器强制挂断
/// 3.missed: 对方无应答, 客户端主叫方呼叫超时挂断
/// 4.cancel: 通话已取消, 主叫方取消通话
/// 5.refused: 对方已拒绝
/// }
- (void)callDiscardCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

#pragma mark - 多人音视频接口名称

/// 用户发起多人音视频通话请求(告知对方，用户想要和对方进行音视频通话)
/// @param params 操作参数 {to_id:被邀请者用户ID数组(JSON字符串) mode:通话模式 0音视频 1音频 chat_id:群组id}
/// 返回GroupCall{hash, stage:0, connection, participants}
/// 成功: 给被邀请者发送 GroupCall{hash, action:request, participants}
- (void)callGroupRequestCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户接受对方发来的多人音视频请求
/// @param params 操作参数 {hash:本次通话标识}
/// 成功返回房间信息和RtcToken: GroupCall{hash, participants, connection}
/// 成功:给当前所有成员发送加入房间消息 GroupCall{hash, accept, user_id}
/// 成功:给自己的其他设备发送挂断消息 GroupCall{hash, discard}
- (void)callGroupAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 邀请加入多人音视频通话
/// @param params 操作参数 {hash:本次通话标识 user_id:被邀请者用户ID数组(JSON字符串)}
/// 成功: 给当前所有成员发送邀请某人进房间消息 GroupCall{hash, invite, user_id}
/// 成功: 给被邀请者发送发起通话消息 GroupCall{hash, action:request, participants}
- (void)callGroupInviteCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 主动加入多人音视频通话
/// @param params 操作参数 {hash:本次通话标识}
/// 成功返回: 房间信息和rtc-token: GroupCall{hash, participants, connection}
/// 成功: 给当前所有成员发送邀请某人进房间消息 GroupCall{hash, invite, user_id}
/// 成功: 给被邀请者发送发起通话消息 GroupCall{hash, action:request, participants}
- (void)callGroupJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 结束通话
/// @param params 操作参数 {hash:本次通话标识 reason:结束原因}
/// 主叫方成功: 关闭房间, 给所有人发挂断消息 GroupCall{hash, discard, reason}
/// 被叫方成功: 给所有人发离开消息 GroupCall{hash, leave, user_id}
/// 如果少于2人, 关闭房间, 再给所有人发挂断消息 GroupCall{hash, discard, reason}
- (void)callGroupDiscardCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获得当前群通话信息(多人通话状态)
/// @param params 操作参数 {chat_id:群id}
- (void)callGroupStateCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

#pragma mark - <<<<<<音视频通话通用接口-即构>>>>>>

/// 发起者创建音视频通话
/// params: 操作参数{callType:Voice语音通话，Video视频通话；chatType:SINGLE_CHAT单聊，GROUP_CHAT群聊；friendIds:好友/用户ID(数组)；groupId:群聊时必填}
- (void)userCreateCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 发起者取消通话(通话未接听)
/// params: 操作参数{callId:通话ID}
- (void)userCancelCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 被邀请者接听通话
/// params: 操作参数{callId:通话ID}
- (void)userAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 被邀请者拒绝通话(通话未接听)
/// params: 操作参数{callId:通话ID}
- (void)userRejectCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 挂断通话
/// params: 操作参数{callId:通话ID}
- (void)userHangUpCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群聊 主动加入某个音视频通话
/// - Parameters:
///   - params: 操作参数{callId:通话ID}
- (void)userJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群聊 邀请加入某个音视频通话
/// - Parameters:
///   - params: 操作参数{callId:通话ID；friendIds:好友/用户ID(数组)}
- (void)userInviteToCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群聊 获取某个群 当前正在进行的音视频通话信息(判断是否有正在进行的音视频通话)
/// - Parameters:
///   - params: 操作参数{groupId:群ID}
- (void)userGetGroupCallInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 根据callId获取某个用户的token鉴权信息
/// - Parameters:
///   - params: 操作参数{callId:通话唯一标识}
- (void)userGetCallInfoTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 音视频通话确认完成了整个加入流程
/// - Parameters:
///   - params: 操作参数{callId:通话唯一标识}
- (void)userConfirmJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 音视频通话心跳接口
/// - Parameters:
///   - params: 操作参数{callId:通话唯一标识}
- (void)userHeartbeatCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
