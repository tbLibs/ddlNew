// Passive call-history compatibility only. This build has no calling engine or signaling API.
#import "NoaIMSDKManager+CallRecords.h"
#import "NoaIMSDKManager+User.h"
#import "NoaIMSDKManager+Friend.h"
#import "NoaIMSDKManager+Session.h"
#import "NoaIMSDKManager+GroupMember.h"
#import "LIMMediaCallSingleModel.h"
#import "LIMMediaCallGroupParticipantAction.h"

@implementation NoaIMSDKManager (CallRecords)
- (void)imSdkDealReceiveServiceMessageForCall:(IMServerMessage *)message {
    
    //自定义事件model
    CustomEvent *Call = message.customEvent;
    
    NSString *jsonContent = Call.content;
    LIMMediaCallSingleModel *singleModel = [LIMMediaCallSingleModel mj_objectWithKeyValues:jsonContent];
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

- (void)imSdkDealReceiveServiceMessageForGroupCallInfoChange:(IMServerMessage *)message {
    //自定义事件model
    CustomEvent *Call = message.customEvent;
    NSString *jsonContent = Call.content;
    LIMMediaCallGroupParticipantAction *mediaCallModel = [LIMMediaCallGroupParticipantAction mj_objectWithKeyValues:jsonContent];
    if ([mediaCallModel.action isEqualToString:@"new"]) {
        //user_id发起了多人音视频通话
        [self saveCallGroupMessageWith:message customEventMessage:mediaCallModel];
    } else if ([mediaCallModel.action isEqualToString:@"discard"]) {
        //user_id结束了多人音视频通话
        [self saveCallGroupMessageWith:message customEventMessage:mediaCallModel];
    }
}

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

- (void)imSdkDealReceiveChatMessageForCall:(IMChatMessage *)message {
    // Keep cross-device history compatible; live invitations cannot start a call in this build.
    NetCallMessage *record = message.netCallMessage;
    BOOL shouldSave = NO;
    if (record.chatType == 1) {
        switch (record.status) {
            case 2: case 3: case 4: case 5: case 7: case 12:
                shouldSave = YES;
                break;
            case 8:
                shouldSave = ![record.roomCreateUser isEqualToString:[self myUserID]];
                break;
            default:
                break;
        }
    } else if (record.chatType == 2) {
        shouldSave = record.status == 1 || record.status == 11;
    }
    if (shouldSave) {
        [self saveChatMessageForCallWith:message];
    }
}

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

@end
