//
//  NoaIMSDKManager+Call.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/2.
//

//音视频通话

#import "NoaIMSDKManager.h"
#import "NoaIMCallManager.h"
#import "NoaIMZGCallManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Call)

#pragma mark - ******消息逻辑处理******

/// 处理接收到的 音视频通话 系统通知 (单人模式)
/// @param message 系统通知消息
- (void)imSdkDealReceiveServiceMessageForCall:(IMServerMessage *)message;

/// 处理接收到的 音视频通话 系统通知 (多人模式) 仅发给通话成员
/// @param message 系统通知消息
- (void)imSdkDealReceiveServiceMessageForGroupCall:(IMServerMessage *)message;

/// 处理接收到的 音视频通话 系统通知 (多人模式) 给群里所有人发(音视频房间信息，成员信息发生变化)
/// @param message 系统通知消息
- (void)imSdkDealReceiveServiceMessageForGroupCallInfoChange:(IMServerMessage *)message;

/// 处理接收到的 音视频通话 聊天类型消息
/// @param message 聊天消息
- (void)imSdkDealReceiveChatMessageForCall:(IMChatMessage *)message;

#pragma mark - ******接口逻辑处理******

// ******单人音视频通话接口******

/// 用户发起音视频请求(告知对方，用户想要和对方进行音视频通话)
/// @param params 操作参数 {userUid:对方用户UID mode:通话模式 0音视频 1音频}
- (void)imSdkCallRequestCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户响应对方发来的音视频请求(用户接收到对方发来的音视频通话的请求，进入音视频相关的UI，告知对方waiting等待用户接通音视频通话)
/// @param params 操作参数 {hash:本次通话标识}
- (void)imSdkCallReceiveCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户接受对方发来的音视频请求(告知对方accept用户接通了音视频通话)
/// @param params 操作参数 {hash:本次通话标识}
- (void)imSdkCallAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户确认音视频会话，创建房间(用户接收到对方已经接受了这次音视频通话，进行房间的创建)
/// @param params 操作参数 {hash:本次通话标识}
- (void)imSdkCallConfirmCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

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
- (void)imSdkCallDiscardCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

// ******多人音视频通话******

/// 用户发起多人音视频通话请求(告知对方，用户想要和对方进行音视频通话)
/// @param params 操作参数 {to_id:被邀请者用户ID数组(JSON字符串) mode:通话模式 0音视频 1音频 chat_id:群组id}
- (void)imSdkCallGroupRequestWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户接受对方发来的多人音视频请求
/// @param params 操作参数 {hash:本次通话标识}
- (void)imSdkCallGroupAcceptWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 邀请加入多人音视频通话
/// @param params 操作参数 {hash:本次通话标识 user_id:被邀请者用户ID数组(JSON字符串)}
- (void)imSdkCallGroupInviteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 主动加入多人音视频通话
/// @param params 操作参数 {hash:本次通话标识}
- (void)imSdkCallGroupJoinWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 结束通话
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
- (void)imSdkCallGroupDiscardWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 当前群是否有多人通话
/// @param params 操作参数{chat_id:群id}
- (void)imSdkCallGroupStateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


#pragma mark - ******房间逻辑处理******

/// 音视频通话房间信息
- (Room *)imSdkCallRoom;

/// 音视频通话房间断开连接
- (void)imSdkCallRoomDisconnect;

/// 音视频通话用户连接房间
- (void)imSdkCallRoomConnectWithOptions:(NoaIMCallOptions *)callOptions delegate:(id<RoomDelegateObjC>)roomDelegateObjc;

/// 服从房间代理
- (void)imSdkCallRoomDelegate:(id <RoomDelegateObjC>)roomDelegate;

/// 音频是否静默
/// @param isMuted YES静默开启 NO静默关闭
- (void)imSdkCallRoomAudioMuteWith:(BOOL)isMuted complete:(void (^) (BOOL isMuted))muteBlock;

/// 视频是否静默
/// @param isMuted YES静默开启 NO静默关闭
- (void)imSdkCallRoomVideoMuteWith:(BOOL)isMuted complete:(void (^) (BOOL isMuted))muteBlock;

/// 音频外放是否静默
/// @param isMute YES使用听筒NO使用扬声器
- (void)imSdkCallRoomAudioExternalMuteWith:(BOOL)isMute;

/// 视频切换摄像头方向
- (void)imSdkCallRoomVideoCameraSwitch:(void (^) (BOOL success))cameraSwitchResult;

/// 获取房间远端参与者
- (NSArray *)imSdkCallRoomGetRemoteParticipants;

#pragma mark - <<<<<<音视频通话通用接口-即构>>>>>>

/// 发起者创建音视频通话
/// params: 操作参数{callType:Voice语音通话，Video视频通话；chatType:SINGLE_CHAT单聊，GROUP_CHAT群聊；friendIds:好友/用户ID(数组)；groupId:群聊时必填}
- (void)imSdkUserCreateCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 发起者取消通话(通话未接听)
/// params: 操作参数{callId:通话ID}
- (void)imSdkUserCancelCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 被邀请者接听通话
/// params: 操作参数{callId:通话ID}
- (void)imSdkUserAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 被邀请者拒绝通话(通话未接听)
/// params: 操作参数{callId:通话ID}
- (void)imSdkUserRejectCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 挂断通话
/// params: 操作参数{callId:通话ID}
- (void)imSdkUserHangUpCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群聊 主动加入某个音视频通话
/// - Parameters:
///   - params: 操作参数{callId:通话ID}
- (void)imSdkUserJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群聊 邀请加入某个音视频通话
/// - Parameters:
///   - params: 操作参数{callId:通话ID；friendIds:好友/用户ID(数组)}
- (void)imSdkUserInviteToCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群聊 获取某个群 当前正在进行的音视频通话信息(判断是否有正在进行的音视频通话)
/// - Parameters:
///   - params: 操作参数{groupId:群组ID}
- (void)imSdkUserGetGroupCallInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 根据callId获取某个用户的token鉴权信息
/// - Parameters:
///   - params: 操作参数{callId:通话唯一标识}
- (void)imSdkUserGetCallInfoTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 音视频通话确认完成了整个加入流程
/// - Parameters:
///   - params: 操作参数{callId:通话唯一标识}
- (void)imSdkUserConfirmJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 音视频通话心跳接口
/// - Parameters:
///   - params: 操作参数{callId:通话唯一标识}
- (void)userHeartbeatCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

#pragma mark - <<<<<<即构SDK方法封装>>>>>>

/// 即构SDK基本信息配置
/// - Parameter config: 配置信息
- (void)imSdkZGConfigWith:(NoaIMZGCallConfig *)config;

/// 创建 ZegoExpressEngine 单例对象并初始化 SDK(第一步)
/// - Parameters:
///   - callOptions: 房间相关参数
///   - roomDelegate: 服从代理者
- (void)imSdkZGCallRoomCreateEngineWithOptions:(NoaIMZGCallOptions *)callOptions delegate:(id <ZegoEventHandler> _Nullable)roomDelegate;

/// 登录房间(第二步)
- (void)imSdkZGCallRoomLoginRoom:(LingIMZGLoginRoomBlock)block;

/// 开始推流(第三步)
- (void)imSdkZGCallRoomStartPublish;

/// 停止推流
- (void)imSdkZGCallRoomStopPublish;

/// 退出房间
- (void)imSdkZGCallRoomLogout;

/// 开始拉流
/// - Parameter streamID: 流ID
- (void)imSdkZGCallRoomStartPlayingStream:(NSString *)streamID with:(UIView *)viewPreview;;

/// 停止拉流
- (void)imSdkZGCallRoomStopPlayingStram:(NSString *)streamID;

/// 服从代理
/// - Parameter roomDelegate: 服从代理者
- (void)imSdkZGCallRoomDelegate:(id <ZegoEventHandler>)roomDelegate;

/// 开始视频预览
/// - Parameter viewPreview: 展示预览view
- (void)imSdkZGCallRoomStartPreviewWith:(UIView *)viewPreview;

/// 停止视频预览
- (void)imSdkZGCallRoomStopPreview;

/// 用户房间类型
- (LingIMCallType)imSdkZGCallRoomType;

/// 即构 音视频麦克风静默
/// - Parameter mute: 是否静默
- (void)imSdkZGCallRoomMicrophoneMute:(BOOL)mute;

/// 即构 音视频麦克风静默状态
- (LingIMCallMicrophoneMuteState)imSdkZGCallRoomMicrophoneState;

/// 即构 音视频摄像头静默
/// - Parameter mute: 是否静默
- (void)imSdkZGCallRoomCameraMute:(BOOL)mute;

/// 即构 音视频摄像头静默状态
- (LingIMCallCameraMuteState)imSdkZGCallRoomCameraState;

/// 即构 音视频摄像头方向切换
/// - Parameter frontEnable: 使用前置摄像头
- (void)imSdkZGCallRoomCameraUseFront:(BOOL)frontEnable;

/// 即构 音视频摄像头方向状态
- (LingIMCallCameraDirection)imSdkZGCallRoomCameraDirection;

/// 即构 音视频扬声器静默
/// - Parameter mute: 是否静默
- (void)imSdkZGCallRoomSpeakerMute:(BOOL)mute;

/// 即构 音视频扬声器静默状态
- (LingIMCallSpeakerMuteState)imSdkZGCallRoomSpeakderState;
@end

NS_ASSUME_NONNULL_END
