//
//  NoaIMSDKManager+Call.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/2.
//

#import "NoaIMSDKManager+Call.h"
#import "NoaIMSDKManager+User.h"
#import "NoaIMSDKManager+Friend.h"
#import "NoaIMSDKManager+Session.h"
#import "NoaIMSDKManager+GroupMember.h"

#import "NoaIMHttpManager+Call.h"//语音通话相关接口
#import "NoaIMSDKManager+MessageRemind.h"//消息提醒

#import "LIMMediaCallModel.h"//LiveKit

@implementation NoaIMSDKManager (Call)

#pragma mark - ******消息逻辑处理******

#pragma mark - 处理接收到的 音视频通话 系统通知 (101单人模式)
- (void)imSdkDealReceiveServiceMessageForCall:(IMServerMessage *)message {
    
    //自定义事件model
    CustomEvent *Call = message.customEvent;
    
    NSString *jsonContent = Call.content;
    LIMMediaCallSingleModel *singleModel = [LIMMediaCallSingleModel mj_objectWithKeyValues:jsonContent];
    CIMLog(@"101类型消息内容：%@===我的id:%@",singleModel,[self myUserID]);
    
    LIMMediaCallModel *mediaCallModel = [LIMMediaCallModel new];
    mediaCallModel.callSingleModel = singleModel;
    
    //state：request请求、waiting等待、accept接受、confirm确认、discard断开连接
    
    //******
    //单人音视频通话的singleModel.from_id永远都是邀请者，可用来区分哪方是邀请者和被邀请者
    
    if ([singleModel.state isEqualToString:@"request"]) {
        
        //我 被邀请者：收到对方发起的音视频通话的邀请(只有 被邀请者 可收到此消息)
        [self.mediaCallDelegate imSdkMediaCallSingleInviteeReceiveRequestWith:mediaCallModel];//告知 被邀请者 收到 邀请者 发来 音视频通话的请求
        
    }else if ([singleModel.state isEqualToString:@"waiting"]) {
        
        //我 邀请者：被邀请者已经收到我发起的邀请，等待被邀请者处理我的申请(拒绝/接受)(只有 邀请者 可收到此消息)
        [self.mediaCallDelegate imSdkMediaCallSingleInviterWaitingInviteeDealWith:mediaCallModel];//告知 邀请者 请等待 被邀请者 处理 音视频通话的请求
        
    }else if ([singleModel.state isEqualToString:@"accept"]) {
        
        //我 邀请者：被邀请者同意了我的音视频通话邀请，我需要去确认邀请然后创建房间(只有 邀请者 可收到此消息)
        [self.mediaCallDelegate imSdkMediaCallSingleInviteeAcceptRequestWith:mediaCallModel];//告知 邀请者 被邀请者 同意 音视频通话的请求
        
    }else if ([singleModel.state isEqualToString:@"confirm"]) {
        //我 被邀请者：收到 邀请者已确认了我的接听 创建音视频房间成功(只有 被邀请者 可收到此消息)
        //我可以加入房间进行通话了
        [self.mediaCallDelegate imSdkMediaCallSingleInviterConfirmRoomWith:mediaCallModel];//告知 被邀请者 邀请者 确认了音视频通话房间信息
        
    }else if ([singleModel.state isEqualToString:@"discard"]) {
        //断开连接，断开连接原因如下(邀请者和被邀请者都会收到此消息)
        //UI上只需显示discard类型的消息即可
        //存储discard消息到数据库，UI展示
        [self.mediaCallDelegate imSdkMediaCallSingleDiscardWith:mediaCallModel];//告知 邀请者 和 被邀请者 通话断开连接
        
        if ([singleModel.discard_reason isEqualToString:@"disconnect"]) {
            //通话中断、服务器强制挂断
            //告知 邀请者 展示 如：通话中断
            //告知 被邀请者 展示 如：通话中断
            
        }else if ([singleModel.discard_reason isEqualToString:@"missed"]) {
            //呼叫超时(被邀请者 长时间未响应 邀请)
            //告知 邀请者 展示 如：对方无应答
            //告知 被邀请者 展示 如：超时未应答
            
        }else if ([singleModel.discard_reason isEqualToString:@"cancel"]) {
            //呼叫取消(邀请者 在 被邀请者 接受之前 取消邀请)
            //告知 邀请者 展示 如：通话已取消
            //告知 被邀请者 展示 如：对方已取消
        }else if ([singleModel.discard_reason isEqualToString:@"refused"]) {
            //呼叫拒绝(被邀请者 拒绝 邀请)
            //告知 邀请者 展示 如：对方已拒绝
            //告知 被邀请者 展示 如：已拒绝；告知 被邀请者 其他平台设备
        }else if ([singleModel.discard_reason isEqualToString:@"accept"]) {
            //呼叫已接听(被邀请者 已接受 邀请，被邀请者的其他设备会收到此消息)
            //告知 被邀请者 展示 如：已在其他设备接听
        }else {
            //通话正常挂断
            //告知 邀请者 展示 如：10:00通话
            //告知 被邀请者 展示 如：10:00通话
        }
        
    }
    
    //******
    
    //单人音视频通话结束
    if ([singleModel.state isEqualToString:@"discard"]) {
        //1.系统通知消息转换为数据库类型消息
        NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
        model.serverMessageProtobuf = message.delimitedData;//protobuf
        model.messageType = CIMChatMessageType_ServerMessage;//群聊里的系统通知消息 提示
        model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
        model.chatType = CIMChatType_SingleChat;//单聊类型
        model.sendTime = message.sendTime;//发送时间
        model.toSource = message.toSource;//发送的设备
        model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
        model.serviceMsgID = message.sMsgId;//服务端返回消息ID
        model.chatMessageReaded = YES;//系统通知消息，默认已读
        model.currentVersionMessageOK = YES;//当前版本支持音视频通话消息
        model.messageStatus = 1;//接收到的消息，默认是正常消息
        
        
        //消息的发送方和接收方
        model.toID = singleModel.to_id;
        model.fromID = singleModel.from_id;
        if ([singleModel.from_id isEqualToString: [self myUserID]]) {
            //我是发起者
            model.fromNickname = [self myUserNickname];
            model.fromIcon = [self myUserAvatar];
        }else {
            //好友是发起者
            LingIMFriendModel *friendModel = [self toolCheckMyFriendWith:singleModel.from_id];
            if (friendModel) {
                model.fromNickname = friendModel.showName;//备注或昵称
                model.fromIcon = friendModel.avatar;//头像
            }
        }
        
        //更新会话列表+存储到数据库+进行UI上的展示
        BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        
        if (resultSession) {
            //本地存储成功后，将消息传递到UI层
            //数据传递到UI层
            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
            [self.messageDelegate cimToolChatMessageReceive:model];
        }
        
    }
    
}

#pragma mark - 处理接收到的 音视频通话 系统通知 (102多人模式)
- (void)imSdkDealReceiveServiceMessageForGroupCall:(IMServerMessage *)message {
    //自定义事件model
    CustomEvent *Call = message.customEvent;
    
    NSString *jsonContent = Call.content;
    LIMMediaCallGroupModel *mediaCallModel = [LIMMediaCallGroupModel mj_objectWithKeyValues:jsonContent];
    CIMLog(@"102类型消息内容：%@===我的id:%@",mediaCallModel,[self myUserID]);
    
    LIMMediaCallModel *callModel = [LIMMediaCallModel new];
    callModel.callGroupModel = mediaCallModel;
    
    if ([mediaCallModel.action isEqualToString:@"request"]) {
        //被邀请者收到 邀请 进行多人音视频通话
        [self.mediaCallDelegate imSdkMediaCallGroupRequestWith:callModel];
    }else if ([mediaCallModel.action isEqualToString:@"invite"]) {
        //邀请多人进行 多人音视频通话(告知房间通话成员，又邀请了新成员加入通话)
        //邀请成员id args:[userUid]
        [self.mediaCallDelegate imSdkMediaCallGroupInviteWith:callModel];
        
    }else if ([mediaCallModel.action isEqualToString:@"join"]) {
        //成员加入 多人音视频通话(告知房间成员，有新的成员加入了通话)
        //加入者id user_id
        [self.mediaCallDelegate imSdkMediaCallGroupJoinWith:callModel];
        
    }else if ([mediaCallModel.action isEqualToString:@"leave"]) {
        //成员离开 多人音视频通话(告知房间成员，有成员离开了通话)
        //离开者id user_id
        [self.mediaCallDelegate imSdkMediaCallGroupLeaveWith:callModel];
        /*
         leave离开原因
         "": 空字符串，通话建立之后正常挂断，离开房间
         refused: 拒绝接听
         timeout: 呼叫超时
         */
        
    }else {//discard
        //通话结束
        [self.mediaCallDelegate imSdkMediaCallGroupDiscardWith:callModel];
        /*
         discard挂断原因
         "": 空字符串, 通话建立之后正常挂断
         accept: 已在其他设备接听
         */
    }
}

#pragma mark - 处理接收到的 音视频通话 系统通知 (103多人模式) 给群里所有人发(音视频房间信息，成员信息发生变化)
- (void)imSdkDealReceiveServiceMessageForGroupCallInfoChange:(IMServerMessage *)message {
    //自定义事件model
    CustomEvent *Call = message.customEvent;
    NSString *jsonContent = Call.content;
    LIMMediaCallGroupParticipantAction *mediaCallModel = [LIMMediaCallGroupParticipantAction mj_objectWithKeyValues:jsonContent];
    CIMLog(@"103类型消息内容：%@===我的id:%@",mediaCallModel,[self myUserID]);
    
    LIMMediaCallModel *callModel = [LIMMediaCallModel new];
    callModel.callGroupParticipantActionModel = mediaCallModel;
    
    [self.mediaCallDelegate imSdkMediaCallGroupParticipantActionWith:callModel];
    
    if ([mediaCallModel.action isEqualToString:@"new"]) {
        //user_id发起了多人音视频通话
        [self saveCallGroupMessageWith:message customEventMessage:mediaCallModel];
    } else if ([mediaCallModel.action isEqualToString:@"discard"]) {
        //user_id结束了多人音视频通话
        [self saveCallGroupMessageWith:message customEventMessage:mediaCallModel];
    }
}

//LiveKit 群组音视频通话 保存消息
- (void)saveCallGroupMessageWith:(IMServerMessage *)message customEventMessage:(LIMMediaCallGroupParticipantAction *)mediaCallModel {
    //1.系统通知消息转换为数据库类型消息
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    model.serverMessageProtobuf = message.delimitedData;//protobuf
    model.messageType = CIMChatMessageType_ServerMessage;//群聊里的系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_GroupChat;//群聊类型
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;//当前版本支持音视频通话消息
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    
    
    //消息的发送方和接收方
    model.toID = mediaCallModel.chat_id;//群id
    model.fromID = mediaCallModel.user_id;//相当于该成员发送的消息
    if ([mediaCallModel.user_id isEqualToString: [self myUserID]]) {
        //我是发起者
        model.fromNickname = [self myUserNickname];
        model.fromIcon = [self myUserAvatar];
    }else {
        //群成员是发起者
        LingIMGroupMemberModel *groupMemberModel = [IMSDKManager imSdkCheckGroupMemberWith:mediaCallModel.user_id groupID:mediaCallModel.chat_id];
        if (groupMemberModel) {
            model.fromNickname = groupMemberModel.showName;//备注或昵称
            model.fromIcon = groupMemberModel.userAvatar;//头像
        }else {
            [self requestGroupMemberInfoWith:model groupMember:mediaCallModel.user_id];
            return;
        }
    }
    
    //更新会话列表+存储到数据库+进行UI上的展示
    BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
    
    if (resultSession) {
        //本地存储成功后，将消息传递到UI层
        //数据传递到UI层
        //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
        [self.messageDelegate cimToolChatMessageReceive:model];
    }
    
}

// 根据用户ID获取用户的信息
- (void)requestGroupMemberInfoWith:(NoaIMChatMessageModel *)model groupMember:(NSString *)groupMemberID {
    CIMWeakSelf
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:groupMemberID forKey:@"userUid"];
    
    [self getUserInfoWith:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        
        if ([data isKindOfClass:[NSDictionary class]]) {
            
            NSDictionary *userDict = (NSDictionary *)data;
            LingIMUserModel *userModel = [LingIMUserModel mj_objectWithKeyValues:userDict];
            
            //用户备注或昵称
            model.fromNickname = userModel.userRemark.length > 0 ? userModel.userRemark : userModel.userNickname;
            //用户头像
            model.fromIcon = userModel.userAvatar;
            //更新会话列表+存储到数据库+进行UI上的展示
            BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
            if (resultSession) {
                //本地存储成功后，将消息传递到UI层
                //数据传递到UI层
                //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                [weakSelf.messageDelegate cimToolChatMessageReceive:model];
            }
            
        }
        
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
    }];
}

#pragma mark - ******接口逻辑处理******

#pragma mark - 用户发起音视频请求(告知对方，用户想要和对方进行音视频通话)
- (void)imSdkCallRequestCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callRequestCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户响应对方发来的音视频请求(用户接收到对方发来的音视频通话的请求，进入音视频相关的UI，告知对方waiting等待用户接通音视频通话)
- (void)imSdkCallReceiveCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callReceiveCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户接受对方发来的音视频请求(告知对方accept用户接通了音视频通话)
- (void)imSdkCallAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callAcceptCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户确认音视频会话，创建房间(用户接收到对方已经接受了这次音视频通话，进行房间的创建)
- (void)imSdkCallConfirmCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callConfirmCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户结束/音视频会话(告知对方，用户结束或拒绝与对方的音视频通话)
- (void)imSdkCallDiscardCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callDiscardCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户发起 多人音视频通话请求(告知对方，用户想要和对方进行音视频通话)
- (void)imSdkCallGroupRequestWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callGroupRequestCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户接受对方发来的 多人音视频通话
- (void)imSdkCallGroupAcceptWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callGroupAcceptCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 邀请加入 多人音视频通话
- (void)imSdkCallGroupInviteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callGroupInviteCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 主动加入多人音视频通话
- (void)imSdkCallGroupJoinWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callGroupJoinCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 结束 多人音视频通话
- (void)imSdkCallGroupDiscardWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callGroupDiscardCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 当前群是否有多人通话
- (void)imSdkCallGroupStateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] callGroupStateCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - ******房间逻辑处理******

#pragma mark - 音视频通话房间信息
- (Room *)imSdkCallRoom {
    return [NoaIMCallManager sharedManager].callRoom;
}
#pragma mark - 音视频通话房间断开连接
- (void)imSdkCallRoomDisconnect {
    [[NoaIMCallManager sharedManager] callRoomDisconnect];
}
#pragma mark - 用户连接房间
- (void)imSdkCallRoomConnectWithOptions:(NoaIMCallOptions *)callOptions delegate:(id<RoomDelegateObjC>)roomDelegateObjc {
    [[NoaIMCallManager sharedManager] callRoomConnectWithOptions:callOptions delegate:roomDelegateObjc];
}

#pragma mark - 用户服从房间代理
- (void)imSdkCallRoomDelegate:(id<RoomDelegateObjC>)roomDelegate {
    [[NoaIMCallManager sharedManager] callRoomDelegate:roomDelegate];
}

#pragma mark - 音频是否静默
- (void)imSdkCallRoomAudioMuteWith:(BOOL)isMuted complete:(nonnull void (^)(BOOL))muteBlock{
    if (isMuted) {
        [[NoaIMCallManager sharedManager] callRoomAudioMuteOn:^(BOOL muteOn) {
            if (muteBlock) {
                //静音开启成功，有静音
                muteBlock(muteOn ? YES : NO);
            }
        }];
    }else {
        [[NoaIMCallManager sharedManager] callRoomAudioMuteOff:^(BOOL muteOff) {
            if (muteBlock) {
                //静音关闭成功，没有静音
                muteBlock(muteOff ? NO : YES);
            }
        }];
    }
}

#pragma mark - 视频是否静默
- (void)imSdkCallRoomVideoMuteWith:(BOOL)isMuted complete:(void (^)(BOOL))muteBlock {
    if (isMuted) {
        [[NoaIMCallManager sharedManager] callRoomVideoMuteOn:^(BOOL muteOn) {
            if (muteBlock) {
                //静默开启成功，视频关闭
                muteBlock(muteOn ? YES : NO);
            }
        }];
    }else {
        [[NoaIMCallManager sharedManager] callRoomVideoMuteOff:^(BOOL muteOff) {
            if (muteBlock) {
                //静默关闭成功，视频打开
                muteBlock(muteOff ? NO : YES);
            }
        }];
        
    }
}

#pragma mark - 音频外放是否静默
- (void)imSdkCallRoomAudioExternalMuteWith:(BOOL)isMute {
    if (isMute) {
        [[NoaIMCallManager sharedManager] callRoomAudioExternalOff];
    }else {
        [[NoaIMCallManager sharedManager] callRoomAudioExternalOn];
    }
}

#pragma mark - 视频切换摄像头方向
- (void)imSdkCallRoomVideoCameraSwitch:(void (^)(BOOL))cameraSwitchResult {
    [[NoaIMCallManager sharedManager] callRoomVideoCameraSwitch:^(BOOL success) {
        if (cameraSwitchResult) {
            cameraSwitchResult(success);
        }
    }];
}

#pragma mark - 获取房间远端参与者
- (NSArray *)imSdkCallRoomGetRemoteParticipants {
    return [[NoaIMCallManager sharedManager] callRoomGetRemoteParticipants];
}

#pragma mark - <<<<<<音视频通话通用接口>>>>>>

#pragma mark - 发起者创建音视频通话
- (void)imSdkUserCreateCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userCreateCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 发起者取消通话(通话未接听)
- (void)imSdkUserCancelCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userCancelCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 被邀请者接听通话
- (void)imSdkUserAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userAcceptCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 被邀请者拒绝通话(通话未接听)
- (void)imSdkUserRejectCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userRejectCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 挂断通话
- (void)imSdkUserHangUpCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userHangUpCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群聊 主动加入某个音视频通话
- (void)imSdkUserJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userJoinCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群聊 邀请加入某个音视频通话
- (void)imSdkUserInviteToCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userInviteToCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群聊 获取某个群 当前正在进行的音视频通话信息(判断是否有正在进行的音视频通话)
- (void)imSdkUserGetGroupCallInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userGetGroupCallInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 根据callId获取某个用户的token鉴权信息
- (void)imSdkUserGetCallInfoTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userGetCallInfoTokenWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 音视频通话确认完成了整个加入流程
- (void)imSdkUserConfirmJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userConfirmJoinCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 音视频通话心跳接口
- (void)userHeartbeatCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userHeartbeatCallWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - <<<<<<即构SDK方法封装>>>>>>

#pragma mark - 即构SDK基本信息配置
- (void)imSdkZGConfigWith:(NoaIMZGCallConfig *)config {
    [[NoaIMZGCallManager sharedManager] configSDKWith:config];
}

#pragma mark - 创建 ZegoExpressEngine 单例对象并初始化 SDK(第一步)
- (void)imSdkZGCallRoomCreateEngineWithOptions:(NoaIMZGCallOptions *)callOptions delegate:(id <ZegoEventHandler> _Nullable)roomDelegate {
    [[NoaIMZGCallManager sharedManager] callRoomCreateEngineWithOptions:callOptions delegate:roomDelegate];
}

#pragma mark - 登录房间(第二步)
- (void)imSdkZGCallRoomLoginRoom:(LingIMZGLoginRoomBlock)block {
    [[NoaIMZGCallManager sharedManager] callRoomLoginRoom:block];
}

#pragma mark - 开始推流(第三步)
- (void)imSdkZGCallRoomStartPublish {
    [[NoaIMZGCallManager sharedManager] callRoomStartPublish];
}

#pragma mark - 停止推流
- (void)imSdkZGCallRoomStopPublish {
    [[NoaIMZGCallManager sharedManager] callRoomStopPublish];
}

#pragma mark - 退出房间
- (void)imSdkZGCallRoomLogout {
    [[NoaIMZGCallManager sharedManager] callRoomLogout];
}

#pragma mark - 开始拉流
- (void)imSdkZGCallRoomStartPlayingStream:(NSString *)streamID with:(UIView *)viewPreview;{
    [[NoaIMZGCallManager sharedManager] callRoomStartPlayingStream:streamID with:viewPreview];
}

#pragma mark - 停止拉流
- (void)imSdkZGCallRoomStopPlayingStram:(NSString *)streamID {
    [[NoaIMZGCallManager sharedManager] callRoomStopPlayingStram:streamID];
}

#pragma mark - 服从代理
- (void)imSdkZGCallRoomDelegate:(id <ZegoEventHandler>)roomDelegate {
    [[NoaIMZGCallManager sharedManager] callRoomDelegate:roomDelegate];
}

#pragma mark - 开始视频预览
- (void)imSdkZGCallRoomStartPreviewWith:(UIView *)viewPreview {
    [[NoaIMZGCallManager sharedManager] callRoomStartPreviewWith:viewPreview];
}

#pragma mark - 停止视频预览
- (void)imSdkZGCallRoomStopPreview {
    [[NoaIMZGCallManager sharedManager] callRoomStopPreview];
}

#pragma mark - 用户房间类型
- (LingIMCallType)imSdkZGCallRoomType {
    return [[NoaIMZGCallManager sharedManager] callRoomType];
}

#pragma mark - 即构 音视频麦克风静默
- (void)imSdkZGCallRoomMicrophoneMute:(BOOL)mute {
    [ZGCALL callRoomMicrophoneMute:mute];
}

#pragma mark - 即构 音视频麦克风静默状态
- (LingIMCallMicrophoneMuteState)imSdkZGCallRoomMicrophoneState {
    return [ZGCALL callRoomMicrophoneState];
}

#pragma mark - 即构 音视频摄像头静默
- (void)imSdkZGCallRoomCameraMute:(BOOL)mute {
    [ZGCALL callRoomCameraMute:mute];
}

#pragma mark - 即构 音视频摄像头静默状态
- (LingIMCallCameraMuteState)imSdkZGCallRoomCameraState {
    return [ZGCALL callRoomCameraState];
}

#pragma mark - 即构 音视频摄像头方向切换
- (void)imSdkZGCallRoomCameraUseFront:(BOOL)frontEnable {
    [ZGCALL callRoomCameraUseFront:frontEnable];
}

#pragma mark - 即构 音视频摄像头方向状态
- (LingIMCallCameraDirection)imSdkZGCallRoomCameraDirection {
    return [ZGCALL callRoomCameraDirection];
}

#pragma mark - 即构 音视频扬声器静默
- (void)imSdkZGCallRoomSpeakerMute:(BOOL)mute {
    [ZGCALL callRoomSpeakerMute:mute];
}

#pragma mark - 即构 音视频扬声器静默状态
- (LingIMCallSpeakerMuteState)imSdkZGCallRoomSpeakderState {
    return [ZGCALL callRoomSpeakerState];
}

#pragma mark - ******即构 处理接收到的 音视频通话 聊天类型消息******
- (void)imSdkDealReceiveChatMessageForCall:(IMChatMessage *)message {
    
    
    NetCallMessage *callMessage = message.netCallMessage;
    
    if (callMessage.chatType == 1) {
        //单聊音视频
        //例如：A邀请者 B被邀请者
        //音视频发起者信息
        NSString *callCreateUser = callMessage.roomCreateUser;
        //1:发起，2:取消，3:超时未应答，4:拒绝，5:挂断，6:接受，7:通话中断,8:其他设备已接听,12：加入房间超时
        switch (callMessage.status) {
            case 1:
            {
                //被邀请者接收到音视频通话的邀请 收到消息的只有B
                if (![callCreateUser isEqualToString:[self myUserID]]) {
                    //我 是 B
                    [self.mediaCallDelegate imSdkCallInviteeReceiveRequestWith:message];
                }
            }
                break;
            case 2://邀请者在被邀请者处理邀请之前，取消了音视频通话的邀请 收到消息的有AB
            case 3://被邀请者超时未处理音视频通话的邀请 收到消息的有AB
            case 4://被邀请者拒绝了邀请者的音视频通话邀请 收到消息的有AB
            case 5://有一方挂断了音视频通话，通话结束 收到消息的有AB
            case 7://通话中断因为某些原因 收到消息的有AB
            case 12://加入房间超时了
            {
                //相当于通话结束了，进行存储展示
                [self.mediaCallDelegate imSdkCallDiscardWith:message];
                [self saveChatMessageForCallWith:message];
            }
                break;
            case 6:
            {
                //被邀请者同意了邀请者的音视频通话邀请 收到消息的只有A
                [self.mediaCallDelegate imSdkCallInviteeAcceptRequestWith:message];
            }
                break;
            case 8:
            {
                //告知被邀请者的其他设备，通话已接听 收到消息的为B的其他设备
                //相当于通话结束了，进行存储展示
                [self.mediaCallDelegate imSdkCallDiscardWith:message];
                if (![callCreateUser isEqualToString:[self myUserID]]) {
                    //我 是 B 已在其他设备接听
                    [self saveChatMessageForCallWith:message];
                }
            }
                break;
                
            default:
                break;
        }
        
    }else if (callMessage.chatType == 2) {
        //群聊音视频
        //例如：A发起者 邀请B C进行音视频通话 D在线 E离线
        //1:发起，3:超时未应答，4:拒绝，5:挂断，6:接受，7:通话中断,8:其他设备已接听，9:邀请加入，10：主动加入，11:结束，12：加入房间超时
        switch (callMessage.status) {
            case 1:
            {
                //群成员收到A发起了 群 音视频通话(A,B,C,D,E)
                //本次群聊音视频发起者ID
                NSString *callGroupInviter = [NSString stringWithFormat:@"%@", message.from];
                
                if (![callGroupInviter isEqualToString:[self myUserID]]) {
                    //我不是发起者
                    [self.mediaCallDelegate imSdkCallInviteeReceiveRequestWith:message];
                }
                
                //进行消息存储展示在群聊聊天界面
                [self saveChatMessageForCallWith:message];
             
            }
                break;
            case 3://超时未应答
            case 4://拒绝
            case 5://挂断
            case 6://接受
            case 7://通话中断
            case 8://其他设备已接听
            case 9://邀请加入
            case 10://主动加入
            case 12://加入房间超时
            {
                //群聊房间内成员状态发生变化
                [self.mediaCallDelegate imSdkCallGroupMemberStateChangeWith:message];
                //判断群成员状态变化，是否有 我 的状态 发生变化
                [self mediaCallGroupMemberStateChangeForMeWith:message];
            }
                break;
            case 11:
            {
                //相当于通话结束了，进行存储展示
                [self.mediaCallDelegate imSdkCallDiscardWith:message];
                [self saveChatMessageForCallWith:message];
            }
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - 即构 音视频通话 通话结束 保存消息
- (void)saveChatMessageForCallWith:(IMChatMessage *)messageChat {
    
    //聊天消息转换为数据库类型消息
    NoaIMChatMessageModel *chatModel = [[LingIMModelTool sharedTool] getChatMessageModelFromIMChatMessage:messageChat];
    chatModel.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    
    //更新会话列表+发送消息存储到数据库
    BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:YES];
    
    if (resultSession) {
        //本地存储成功后，将消息传递到UI层
        //数据传递到UI层
        //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
        [self.messageDelegate cimToolChatMessageReceive:chatModel];
    }
}

#pragma mark - 群聊音视频通话 群成员状态变化 有 我的状态发生变化的处理
- (void)mediaCallGroupMemberStateChangeForMeWith:(IMChatMessage *)messageChat {
    
    //1:发起，3:超时未应答，4:拒绝，5:挂断，6:接受，7:通话中断,8:其他设备已接听，9:邀请加入，10：主动加入，11:结束，12：加入房间超时
    
    NetCallMessage *callMessage = messageChat.netCallMessage;
    
    //如果发生状态的群成员里有我的话
    if ([callMessage.operationUsersArray containsObject:[self myUserID]]) {
        
        switch (callMessage.status) {
            case 3://超时未应答
            case 4://拒绝
            case 5://挂断
            case 7://通话中断
            case 8://其他设备已接听
            case 12://加入房间超时
            {
                //相当于通话结束，不存储消息
                [self.mediaCallDelegate imSdkCallDiscardWith:messageChat];
            }
                
                break;
            case 9://邀请加入
            {
                [self.mediaCallDelegate imSdkCallInviteeReceiveRequestWith:messageChat];
            }
                break;
                
            default:
                break;
        }
        
    }
}

/*
 单聊通话消息状态
 1. A邀请B通话，待接通状态：  A对B发邀请消息（B的所有设备收到）
 2. A取消通话，取消状态：A对B发取消消息（A当前设备，B的所有设备收到）
 3. B超时未接听，呼叫超时状态：A对B发取消消息（A当前设备，B的所有设备收到）
 4. B拒绝，拒绝状态：B对A发拒绝消息（A当前设备，B的所有设备收到）
 5. A或B挂断，挂断状态：挂断方 向被挂断方发挂断消息（AB当前设备）
 6. B接听，接听状态：B向A发消息（A当前设备收到）
 7. 回调通话中断，A向B发消息（AB当前设备）
 8. B接听，已在其他设备接听状态：A向B的其他在线设备发消息（B的其他设备收到）
 */

@end
