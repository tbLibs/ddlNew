//
//  NoaIMSDKManager+ServiceMessage.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/26.
//

#import "NoaIMSDKManager+ServiceMessage.h"
#import "NoaIMSDKManager+ChatMessage.h"
#import "NoaIMSDKManager+Session.h"
#import "NoaIMSDKManager+Group.h"
#import "NoaIMSDKManager+GroupMember.h"
#import "NoaIMSDKManager+Friend.h"
#import "NoaIMSDKManager+Call.h"
#import "NoaIMSDKManager+AppInfo.h"
#import "NoaIMSDKManager+Translate.h"


@implementation NoaIMSDKManager (ServiceMessage)

#pragma mark - <<<<<<普通系统通知>>>>>>
#pragma mark - 处理接收到的 系统消息
- (void)toolDealReceiveServiceMessage:(IMServerMessage *)message {
    CIMLog(@"接收到的系统通知消息类型%d",message.sMsgType);
    switch (message.sMsgType) {
        case IMServerMessage_ServerMsgType_DelMsgMessage://清除某个回话的全部 聊天记录
        {
            [self serverMessageForSessionClearMessageWith:nil serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_UserOperationStatus://上报日志
        {
            [self serverMessageForSystemUserOperationStatusMessageWith:nil serverMessage:message];
        }
            break;
        default:
            break;
    }
}




#pragma mark - <<<<<<聊天相关系统通知>>>>>>
#pragma mark - 处理接收到的 消息已读 系统通知
- (void)toolDealReceiveServiceForReadMessage:(IMServerMessage *)message {
    if (message) {
        //会话ID
        NSString *sessionID = message.from;
        //消息已读的信息
        MsgHaveReadMessage *readMessage = message.msgHaveReadMessage;
        //服务端生成的消息ID
        NSString *cMsgId = readMessage.cMsgId;
        
        //查询本地消息
        NoaIMChatMessageModel *chatMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:cMsgId sessionID:sessionID];
        
        if (chatMessage) {
            //更新消息的已读信息
            chatMessage.totalNeedReadCount = readMessage.total;
            chatMessage.haveReadCount = readMessage.read;
            //更新数据库
            BOOL resultUpdateChatMessage = [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
            if (resultUpdateChatMessage) {
                //更新本地存储成功后，将消息传递到UI层
                [self.messageDelegate cimToolChatMessageUpdate:chatMessage];
            }
            
            //查询该会话下的最新消息
            NoaIMChatMessageModel *chatMessageLatest = [IMSDKManager toolGetLatestChatMessageWithSessionID:sessionID];
            if ([chatMessageLatest.msgID isEqualToString:chatMessage.msgID]) {
                //是当前会话的最新消息已读
                //查询本地会话
                LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
                if (sessionModel) {
                    //更新会话的最新消息的已读状态
                    sessionModel.sessionLatestMessage = chatMessage;
                    [self.sessionDelegate cimToolSessionUpdateWith:sessionModel];
                }
            }
        }
    }
}
#pragma mark - 处理接收到的 我已读某消息 系统通知
- (void)toolDealReceiveServiceForUpdateMessageRead:(IMServerMessage *)message {
    if (message) {
        //会话ID
        NSString *sessionID = message.from;
        //我读的消息信息
        UpdateMsgReads *myRead = message.updateMsgReads;
        NSString *serviceMessageID = myRead.msgId;
        //查询本地消息
        NoaIMChatMessageModel *chatMessage = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:serviceMessageID sessionID:sessionID];
        
        if (chatMessage) {
            //消息已读+更新会话红点
            [IMSDKManager toolMessageHaveReadWith:chatMessage];
        }else {
            //更新会话红点，比如用户在另一端已读的消息，但是在本端还未去读或拉取下消息。
            LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
            sessionModel.sessionUnreadCount = 0;
            [IMSDKManager toolUpdateSessionWith:sessionModel];
        }
        
    }
}

#pragma mark - 处理接收到的 消息定时自动删除 系统通知
- (void)imSdkDealReceiveServiceMessageForMessageTimeDelete:(IMServerMessage *)message {
    //1.系统通知消息转换为数据库类型消息
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    //protobuf
    NSData *messageData = message.delimitedData;
    model.serverMessageProtobuf = messageData;
    model.messageType = CIMChatMessageType_ServerMessage;//系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    //消息定时自动删除相关信息
    ScheduleDeleteMessage *messageTimeDeleteModel = message.scheduleDeleteMessage;
    model.chatType = messageTimeDeleteModel.chatType;//聊天类型
    model.toID = messageTimeDeleteModel.peerUid;//接收消息方
    model.fromID = messageTimeDeleteModel.userId;//消息发送方
    model.fromNickname = messageTimeDeleteModel.userNick;
    
    //2.根据消息定时删除状态，确定是否存储到数据库
    if (messageTimeDeleteModel.type == 1) {
        //消息定时删除功能发生修改，进行UI提示，进行数据存储
        BOOL resultSession;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:messageTimeDeleteModel.peerUid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
        if (resultSession) {
            //本地存储成功后，将消息传递到UI层
            [self.messageDelegate cimToolChatMessageReceive:model];
        }
    }else {
        //执行了消息定时删除功能，进行数据库操作和UI更新，不进行数据库存储
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        //消息删除执行时间
        [dict setValue:@(message.sendTime) forKey:@"messageDeleteTime"];
        //消息删除类型
        [dict setValue:@(messageTimeDeleteModel.freq) forKey:@"messageDeleteType"];
        //消息删除的会话
        [dict setValue:messageTimeDeleteModel.peerUid forKey:@"messageDeleteSession"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ChatMessageTimeDelete" object:nil userInfo:dict];
    }
}

#pragma mark - <<<<<<好友相关系统通知>>>>>>
#pragma mark - 处理接收到的 好友申请确认 系统通知
- (void)toolDealReceiveServiceMessageForUserFriendConfirm:(IMServerMessage *)message {
    FriendConfirmMessage *friendConfirm = message.friendConfirmMessage;
    //用户同意/拒绝你发起的好友申请
    if (friendConfirm.status == 1) {
        //同意，更新本地通讯录数据
        LingIMFriendModel *model = [LingIMFriendModel new];
        model.friendUserUID = friendConfirm.uid;
        model.nickname = friendConfirm.nick;
        model.nicknamePinyin = friendConfirm.nickPinyin;
        model.avatar = friendConfirm.avatarFileName;
        model.msgTop = NO;
        model.msgNoPromt = NO;
        model.showName = friendConfirm.nick;
        model.onlineStatus = friendConfirm.liveStatus == 1 ? YES : NO;
        [self toolAddMyFriendOnlyWith:model];
        
        //更新好友列表UI
        [self.userDelegate cimToolUserFriendConfirm:message];
        //更新好友分组列表UI
        [self.userDelegate imSdkUserFriendGroupChange];
    }
    
}

#pragma mark - 处理接收到的 好友不存在 系统通知
- (void)toolDealReceiveServiceMessageForUserFriendNoneExist:(IMServerMessage *)message {
    //好友不存在的信息
    FriendMessage *friendModel = message.friendMessage;
    
    //1.系统通知消息转换为数据库类型消息
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    //protobuf
    NSData *messageData = message.delimitedData;
    model.serverMessageProtobuf = messageData;
    model.messageType = CIMChatMessageType_ServerMessage;//系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_SingleChat;//单聊类型
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.toID = message.to;//接收消息方(我)
    model.fromID = friendModel.fUid;//好友ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    
    //2.更新会话列表+消息存储到数据库
    BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
    if (resultSession) {
        //本地存储成功后，将消息传递到UI层
        //数据传递到UI层
        //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
        [self.messageDelegate cimToolChatMessageReceive:model];
    }
    
    //3.更新已发送消息的状态为失败
    NoaIMChatMessageModel *chatMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:friendModel.msgId sessionID:friendModel.fUid];
    chatMessage.messageSendType = CIMChatMessageSendTypeFail;
    BOOL resultUpdate = [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
    if (resultUpdate) {
        //本地存储成功后，将消息传递到UI层
        [self.messageDelegate cimToolChatMessageUpdate:chatMessage];
    }
    
    
}
#pragma mark - 处理接收到的 好友拉黑 系统通知
- (void)toolDealReceiveServiceMessageForUserFriendBlack:(IMServerMessage *)message {
    //好友加入黑名单信息
    FriendBlackMessage *friendBlack = message.friendBlackMessage;
    
    //1.系统通知消息转换为数据库类型消息
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    //protobuf
    NSData *messageData = message.delimitedData;
    model.serverMessageProtobuf = messageData;
    model.messageType = CIMChatMessageType_ServerMessage;//系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_SingleChat;//单聊类型
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    
    model.toID = message.to;//接收消息方(我)
    model.fromID = friendBlack.fUid;//好友ID
    //friendBlack.type 1我拉黑好友 2好友拉黑我
    
    //2.更新会话列表+消息存储到数据库
    BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
    if (resultSession) {
        //本地存储成功后，将消息传递到UI层
        //数据传递到UI层
        //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
        [self.messageDelegate cimToolChatMessageReceive:model];
    }
    
    //3.更新已发送消息的状态为失败
    NoaIMChatMessageModel *chatMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:friendBlack.msgId sessionID:friendBlack.fUid];
    chatMessage.messageSendType = CIMChatMessageSendTypeFail;
    BOOL resultUpdate = [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
    if (resultUpdate) {
        //本地存储成功后，将消息传递到UI层
        [self.messageDelegate cimToolChatMessageUpdate:chatMessage];
    }
}

#pragma mark - 处理接收到的 好友账号注销 系统通知
- (void)toolDealReceiveServiceMessageForUserAccoutClose:(IMServerMessage *)message {
    //好友账号注销
    UserAccountClose *accountClose = message.userAccountClose;
    
    //1.系统通知消息转换为数据库类型消息
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    //protobuf
    NSData *messageData = message.delimitedData;
    model.serverMessageProtobuf = messageData;
    model.messageType = CIMChatMessageType_ServerMessage;//系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_SingleChat;//单聊类型
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    
    model.toID = message.to;//接收消息方(我)
    model.fromID = accountClose.userId;//好友ID
    //friendBlack.type 1我拉黑好友 2好友拉黑我
    
    //2.更新会话列表+发送消息存储到数据库
    BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
    if (resultSession) {
        //本地存储成功后，将消息传递到UI层
        //数据传递到UI层
        //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
        [self.messageDelegate cimToolChatMessageReceive:model];
    }
    
    //3.更新已发送消息的状态为失败
    NoaIMChatMessageModel *chatMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:accountClose.msgId sessionID:accountClose.userId];
    chatMessage.messageSendType = CIMChatMessageSendTypeFail;
    BOOL resultUpdate = [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
    if (resultUpdate) {
        //本地存储成功后，将消息传递到UI层
        [self.messageDelegate cimToolChatMessageUpdate:chatMessage];
    }
}


#pragma mark - 处理接收到的 好友在线状态 系统通知
- (void)toolDealReceiveServiceMessageForUserFriendOnline:(IMServerMessage *)message {
    FriendLineStatus *friendOnline = message.friendLineStatus;
    NSString *friendID = friendOnline.friendId;
    BOOL onlineStatus = friendOnline.status == 1 ? YES : NO;
    
    LingIMFriendModel *myFriendModel = [self toolCheckMyFriendWith:friendID];
    if (myFriendModel.onlineStatus != onlineStatus) {
        myFriendModel.onlineStatus = onlineStatus;
        //更新数据库好友信息
        [self toolAddMyFriendOnlyWith:myFriendModel];
        
        [self.userDelegate cimToolUserFriendLineStatus:message];
        [self.userDelegate imSdkUserFriendGroupChange];
    }
}

#pragma mark - 处理接收到的 好友分组 系统通知
- (void)toolDealReceiveServiceMessageForFriendGroup:(IMServerMessage *)message {
    __weak typeof(self) weakSelf = self;
    
    if (message.sMsgType == IMServerMessage_ServerMsgType_UserGroupsEventMessage) {
        //509 好友分组 管理
        UserGroupsEventMessage *friendGroupMessage = message.userGroupsEventMessage;
        
        //操作：-1:删除，1:添加，2:修改
        switch (friendGroupMessage.operate) {
            case -1://删除好友分组
            {
                //好友分组ID 将该分组下的好友，更新到默认分组下
                NSString *friendGroupID = friendGroupMessage.ugUuid;
                [self toolDeleteMyFriendGroupWith:friendGroupID];
                
                //默认好友分组
                LingIMFriendGroupModel *defaultFriendGroupModel = [self toolGetMyFriendGroupTypeList:-1].firstObject;
                
                NSArray *friendList = [self toolGetMyFriendGroupFriendsWith:friendGroupID];
                if (defaultFriendGroupModel && friendList.count > 0) {
                    
                    [friendList enumerateObjectsUsingBlock:^(LingIMFriendModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        obj.ugUuid = defaultFriendGroupModel.ugUuid;
                        //仅仅更新好友分组的信息
                        [weakSelf toolAddMyFriendOnlyWith:obj];
                    }];
                }
                
                //接口更新 好友分组 数据
                [self requestUpdateFriendGroupListFromServiceOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                    //更新好友分组列表
                    [self.userDelegate imSdkUserFriendGroupChange];
                } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                }];
                
                
                
            }
                break;
            case 1://新增好友分组
            {
                LingIMFriendGroupModel *newFriendGroupModel = [LingIMFriendGroupModel new];
                newFriendGroupModel.ugUuid = friendGroupMessage.ugUuid;
                newFriendGroupModel.ugName = friendGroupMessage.ugName;
                newFriendGroupModel.ugOrder = friendGroupMessage.ugOrder;
                newFriendGroupModel.ugType = friendGroupMessage.ugType;
                BOOL result = [self toolAddMyFriendGroupWith:newFriendGroupModel];
                if (result) {
                    //更新好友分组列表
                    [self.userDelegate imSdkUserFriendGroupChange];
                }
                
            }
                break;
            case 2://修改好友分组
            {
                //好友分组ID
                NSString *friendGroupID = friendGroupMessage.ugUuid;
                LingIMFriendGroupModel *friendGroupModel = [self toolCheckMyFriendGroupWith:friendGroupID];
                if (friendGroupModel) {
                    friendGroupModel.ugUuid = friendGroupMessage.ugUuid;
                    friendGroupModel.ugName = friendGroupMessage.ugName;
                    friendGroupModel.ugOrder = friendGroupMessage.ugOrder;
                    friendGroupModel.ugType = friendGroupMessage.ugType;
                    BOOL result = [self toolUpdateMyFriendGroupWith:friendGroupModel];
                    if (result) {
                        //更新好友分组列表
                        [self.userDelegate imSdkUserFriendGroupChange];
                    }
                }else {
                    //调用接口，更新好友分组列表
                    [self requestUpdateFriendGroupListFromServiceOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                        [weakSelf.userDelegate imSdkUserFriendGroupChange];
                    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                    }];
                }
                
                
            }
                break;
                
            default:
                break;
        }
        
        
    }else if (message.sMsgType == IMServerMessage_ServerMsgType_UserGroupUserEventMessage) {
        //510 好友分组 好友的分组管理
        UserGroupUserEventMessage *friendOfFriendGroupMessage = message.userGroupUserEventMessage;
        //操作：-1:删除，1:添加，2:修改
        switch (friendOfFriendGroupMessage.operate) {
            case -1:
            {
                
            }
                break;
            case 1:
            {
                
            }
                break;
            case 2:
            {
                //好友分组ID
                NSString *friendGroupID = friendOfFriendGroupMessage.uguUgUuid;
                LingIMFriendGroupModel *friendGroupModel = [self toolCheckMyFriendGroupWith:friendGroupID];
                
                //好友ID
                NSString *friendID = friendOfFriendGroupMessage.uguUserUid;
                LingIMFriendModel *friendModel = [self toolCheckMyFriendWith:friendID];
                //更新好友所在分组的信息
                if (friendModel) {
                    friendModel.ugUuid = friendGroupID;
                    [self toolAddMyFriendOnlyWith:friendModel];
                }
                
                if (friendGroupModel) {
                    //更新好友分组列表
                    [self.userDelegate imSdkUserFriendGroupChange];
                }else {
                    //调用接口，更新好友分组列表
                    [self requestUpdateFriendGroupListFromServiceOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                        [weakSelf.userDelegate imSdkUserFriendGroupChange];
                    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                    }];
                }
                
                
            }
                break;
                
            default:
                break;
        }
        
        
    }
}

#pragma mark - 处理接收到的 用户更新了翻译配置信息 系统通知
- (void)toolDealReceiveServiceMessageForUpdateTranslateConfig:(IMServerMessage *)message {
    UserTranslateConfigUploadMessage *updateTranslateConfig = message.userTranslateConfigUploadMessage;
    [self.userDelegate imsdkUserUpdateTranslateConfigInfo:updateTranslateConfig];
}

#pragma mark - 处理接收到的 单聊消息置顶
- (void)toolDealReceiveServiceMessageForMessageTop:(IMServerMessage *)message {
    DialogUserMessageTop *dialogUserMessageTop = message.dialogUserMessageTop;
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    model.serverMessageProtobuf = message.delimitedData;//protobuf
    model.messageType = CIMChatMessageType_ServerMessage;//系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_SingleChat;//群聊类型
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;//当前版本支持音视频通话消息(默认)
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    model.toID = dialogUserMessageTop.friendUid;
    model.fromID = dialogUserMessageTop.uid;
    [self.messageDelegate cimToolChatMessageReceive:model];
}

#pragma mark - 消息编辑
// 根据服务端编辑通知更新本地原消息，并通知聊天页替换对应消息。
- (void)toolDealReceiveServiceMessageForMessageEdit:(IMServerMessage *)message {
    EditedOneMsg *editMessage = message.editedOneMsg;
    if (!editMessage || editMessage.msgId.length == 0 || editMessage.content.length == 0) {
        return;
    }

    // 单聊 dialogId 由双方用户 ID 组成，群聊 dialogId 即群 ID。
    NSString *sessionID = @"";
    NSArray<NSString *> *dialogIDs = [editMessage.dialogId componentsSeparatedByString:@":"];
    for (NSString *dialogID in dialogIDs) {
        if (dialogID.length > 0 && ![dialogID isEqualToString:self.myUserID]) {
            sessionID = dialogID;
            break;
        }
    }
    if (sessionID.length == 0) {
        return;
    }

    NoaIMChatMessageModel *chatMessage = [self toolGetOneChatMessageWithMessageID:editMessage.msgId sessionID:sessionID];
    if (!chatMessage) {
        // 本地不存在原消息时不能安全补齐发送状态、已读状态等字段，因此忽略本次增量通知。
        return;
    }

    NSDictionary *contentDictionary = [editMessage.content mj_JSONObject];
    NSString *bodyString = [contentDictionary objectForKey:@"body"];
    if (![bodyString isKindOfClass:NSString.class] || bodyString.length == 0) {
        return;
    }
    NSDictionary *bodyDictionary = [bodyString mj_JSONObject];
    if (![bodyDictionary isKindOfClass:NSDictionary.class] || bodyDictionary.count == 0) {
        return;
    }

    CIMChatMessageType previousType = chatMessage.messageType;
    CIMChatMessageType editedType = [[contentDictionary objectForKey:@"mType"] integerValue];
    NSString *content = [bodyDictionary objectForKey:@"content"] ?: @"";
    NSString *extension = [bodyDictionary objectForKey:@"ext"] ?: @"";
    NSString *translation = [bodyDictionary objectForKey:@"translate"] ?: @"";
    BOOL isSelf = [chatMessage.fromID isEqualToString:self.myUserID];

    if (editedType == CIMChatMessageType_TextMessage) {
        // 从 @ 消息切换为文本时清空旧 @ 数据，避免 UI 继续渲染过期成员信息。
        if (previousType == CIMChatMessageType_AtMessage) {
            chatMessage.atContent = @"";
            chatMessage.atUsersInfoList = @[];
            chatMessage.atUsersDict = NSMutableDictionary.dictionary;
            chatMessage.atExt = @"";
            chatMessage.showContent = @"";
            chatMessage.atTranslateContent = @"";
            chatMessage.againAtTranslateContent = @"";
            chatMessage.showTranslateContent = @"";
        }
        chatMessage.messageType = editedType;
        chatMessage.textContent = content;
        chatMessage.textExt = extension;
        chatMessage.translateContent = translation;
        chatMessage.againTranslateContent = @"";
    } else if (editedType == CIMChatMessageType_AtMessage) {
        NSArray *atInformation = [bodyDictionary objectForKey:@"atInfo"];
        if (![atInformation isKindOfClass:NSArray.class] || atInformation.count == 0) {
            return;
        }
        NSMutableArray *atUsers = NSMutableArray.array;
        for (NSDictionary *atUser in atInformation) {
            NSString *userID = [atUser objectForKey:@"uId"];
            NSString *nickname = [atUser objectForKey:@"uNick"];
            if (userID.length > 0 && nickname.length > 0) {
                [atUsers addObject:@{userID : nickname}];
            }
        }
        if (atUsers.count == 0) {
            return;
        }
        // 从文本切换为 @ 消息时清空旧文本数据，保证模型只有一种正文来源。
        if (previousType == CIMChatMessageType_TextMessage) {
            chatMessage.textContent = @"";
            chatMessage.textExt = @"";
            chatMessage.translateContent = @"";
            chatMessage.againTranslateContent = @"";
        }
        chatMessage.messageType = editedType;
        chatMessage.atContent = content;
        chatMessage.atUsersInfoList = atUsers;
        chatMessage.atUsersDict = NSMutableDictionary.dictionary;
        chatMessage.atExt = extension;
        chatMessage.showContent = @"";
        chatMessage.atTranslateContent = translation;
        chatMessage.againAtTranslateContent = @"";
        chatMessage.showTranslateContent = @"";
    } else {
        return;
    }

    if (isSelf && translation.length > 0) {
        chatMessage.translateStatus = CIMTranslateStatusSuccess;
    }

    LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:sessionID];
    BOOL shouldTranslate = sessionModel.isReceiveAutoTranslate == 1 && [self toolIsTranslateEnabled];
    if (shouldTranslate) {
        chatMessage.translateStatus = CIMTranslateStatusLoading;
        NSArray *atUsers = editedType == CIMChatMessageType_AtMessage ? chatMessage.atUsersInfoList : @[];
        CIMWeakSelf
        [self requestTranslateActionWithContent:content atUserDictList:atUsers sessionId:sessionID messageType:editedType success:^(NSString * _Nullable result) {
            chatMessage.translateStatus = CIMTranslateStatusSuccess;
            if (editedType == CIMChatMessageType_TextMessage) {
                chatMessage.againTranslateContent = result;
            } else {
                chatMessage.againAtTranslateContent = result;
            }
            chatMessage.localTranslatedShown = 1;
            [weakSelf toolInsertOrUpdateChatMessageWith:chatMessage];
            [weakSelf toolInsertOrUpdateSessionWith:chatMessage isRemind:NO];
            if ([weakSelf.messageDelegate respondsToSelector:@selector(cimToolEditChatMessageUpdate:)]) {
                [weakSelf.messageDelegate cimToolEditChatMessageUpdate:chatMessage];
            }
        } failure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
            chatMessage.translateStatus = CIMTranslateStatusFail;
            [weakSelf toolInsertOrUpdateChatMessageWith:chatMessage];
            [weakSelf toolInsertOrUpdateSessionWith:chatMessage isRemind:NO];
            if ([weakSelf.messageDelegate respondsToSelector:@selector(cimToolEditChatMessageUpdate:)]) {
                [weakSelf.messageDelegate cimToolEditChatMessageUpdate:chatMessage];
            }
        }];
    }

    [self toolInsertOrUpdateChatMessageWith:chatMessage];
    if ([self.messageDelegate hasDelegateThatRespondsToSelector:@selector(cimToolEditChatMessageUpdate:)]) {
        [self.messageDelegate cimToolEditChatMessageUpdate:chatMessage];
    }

    // 原消息是会话最后一条消息时同步更新会话摘要。
    if ([sessionModel.sessionLatestMessage.msgID isEqualToString:chatMessage.msgID]) {
        sessionModel.sessionLatestMessage = chatMessage;
        [self toolUpdateSessionWith:sessionModel];
    }

    // 发送轻量系统模型，供聊天页刷新引用了该消息的气泡。
    NoaIMChatMessageModel *referenceUpdate = NoaIMChatMessageModel.new;
    referenceUpdate.serverMessageProtobuf = message.delimitedData;
    referenceUpdate.messageType = CIMChatMessageType_ServerMessage;
    referenceUpdate.messageSendType = CIMChatMessageSendTypeSuccess;
    referenceUpdate.chatType = editMessage.chatType;
    referenceUpdate.sendTime = message.sendTime;
    referenceUpdate.toSource = message.toSource;
    referenceUpdate.msgID = editMessage.msgId;
    referenceUpdate.serviceMsgID = editMessage.sMsgId;
    referenceUpdate.chatMessageReaded = YES;
    referenceUpdate.currentVersionMessageOK = YES;
    referenceUpdate.messageStatus = 1;
    referenceUpdate.toID = editMessage.toUid;
    referenceUpdate.fromID = editMessage.uid;
    [self.messageDelegate cimToolChatMessageReceive:referenceUpdate];
}

#pragma mark - <<<<<<群相关系统通知>>>>>>
#pragma mark - 处理接收到的 群聊相关提示类型 系统通知消息
- (void)toolDealReceiveServiceMessageForGroupTip:(IMServerMessage *)message {
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
    model.currentVersionMessageOK = YES;//当前版本支持音视频通话消息(默认)
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    
    
    /*
     以下类型，当前版本暂无
     case IMServerMessage_ServerMsgType_JoinConfirmGroupMessage://进群确认/进群通知  该消息体如果拒绝状态只转发给发送申请加入群聊的用户，如果同意该消息会转发给所有在线的群成员
     case IMServerMessage_ServerMsgType_JoinReqGroupMessage://进群申请  该消息体只转发给群主及群管理员
     case IMServerMessage_ServerMsgType_LockAndNoGroupMessage://锁定/解锁群组  该消息只转发给在线的所有群成员
     */
    
    //2.不同系统通知消息解析
    switch (message.sMsgType) {
        case IMServerMessage_ServerMsgType_CreateGroupMessage://群聊创建成功
        {
            [self serverMessageForGroupCreatWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_InviteConfirmGroupMessage://邀请进群确认/邀请进群通知  该消息只转发给在线的所有群成员 215
        {
            [self serverMessageForGroupInviteConfirmWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupNoChatMessage://告知发消息的用户 群禁言 开启
        case IMServerMessage_ServerMsgType_NullGroupMessage://群组不存在
        case IMServerMessage_ServerMsgType_MemberNoGroupMessage://用户不在群内
        case IMServerMessage_ServerMsgType_MemberGroupForbidMessage://告知某个发消息的群成员， 你已被禁言
        {
            [self serverMessageForGroupTipsWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_KickGroupMessage://群成员被踢
        {
            [self serverMessageForGroupMemberKickWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_OutGroupMessage://群成员退群
        {
            [self serverMessageForGroupMemberQuitWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_TransferOwnerMessage://转让群主
        {
            [self serverMessageForGroupOwnerTransferWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_EstoppelGroupMessage://告知全部群成员 群禁言 开启/关闭
        {
            [self serverMessageForGroupBannedWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_AdminGroupMessage://变更管理员
        {
            [self serverMessageForGroupAdminSetWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_NameGroupMessage://群名称修改
        {
            [self serverMessageForGroupNameChangeWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_NoticeGroupMessage://群公告设置
        {
            [self serverMessageForGroupNoticeSetWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupSingleForbidMessage://群主或管理员 禁言某个群成员
        {
            [self serverMessageForGroupMemberBannedWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_FieldNumber_GroupAllForbidMessage:
        {
            // 原先是永久禁言某群内成员后，通知全体群成员删除被永久禁言的群成员的群消息，现在此消息改为清除群内成员历史消息后的通知消息
            [self deleteGroupMemberMessageWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupAllForbidMessage:
        {
            // 原先是群内单人永久禁言后，通知全体群成员删除被禁言成员的群消息，现在此消息改为清除群内成员历史消息后的通知消息
            [self deleteGroupMemberMessageWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_DelGroupMessage://解散群组  该消息只转发给在线的所有群成员
        {
            [self serverMessageForGroupDissolveWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_InviteJoinGroupNoFriendMessage://邀请好友进群，但是好友不存在，该消息只转发给邀请加入的用户
        {
            [self serverMessageForInviteJoinGroupNoFriendWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_InviteJoinGroupBlackFriendMessage://邀请好友进群，但是已被拉黑，该消息只转发给邀请加入的用户
        {
            [self serverMessageForInviteJoinGroupBlackFriendWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_AvatarGroupMessage://变更群头像  该消息只转发给在线的所有群成员
        {
            [self serverMessageForGroupAvatarChangeWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_DelGroupNotice://删除群公告
        {
            [self serverMessageForGroupNoticeDeleteWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_NoChatGroupMessage://是否禁止私聊  该消息只转发给在线的所有群成员
        {
            [self serverMessageForGroupNoChatWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_JoinVerifyGroupMessage://是否进群验证  该消息只转发给在线的所有群成员 213
        {
            [self serverMessageForGroupJoinVerifyWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_InviteJoinRepGroupMessage://邀请进群申请  该消息发送给群管理员? 214
        {
            [self serverMessageForGroupInviteToJoinWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_LockAndNoGroupMessage://锁定/解锁群组  该消息只转发给在线的所有群成员 209
        {
            [self serverMessageForGroupLockWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupIsAllowNetCallMessage://是否开启全员禁止拨打音视频 234
        {
            [self serverMessageForIsAllowNetCallMessageWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupMessageInform://是否开启群提示 236
        {
            [self serverMessageForIsGroupMessageInformWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_IsShowHistoryMessage://是否开启群聊天记录 238
        {
            [self serverMessageForIsShowHistoryMessageWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupCloseSearchUserMessage://关闭搜索用户消息通知 240
        {
            [self serverMessageForGroupCloseSearchUserMessageWith:model serverMessage:message];
        }
            break;
        case IMServerMessage_ServerMsgType_GroupMessageTop://群消息置顶/取消置顶 该消息转发给在线所有成员 516
        {
            [self serverMessageForGroupMessageTopWith:model serverMessage:message];
        }
            break;

        default:
        {
            model.currentVersionMessageOK = NO;
        }
            break;
    }
    
    
    //群封禁，不做数据存储，不进行展示
    if (message.sMsgType == IMServerMessage_ServerMsgType_LockAndNoGroupMessage) return;
    //群内禁止私聊，不做数据存储，不进行展示
    if(message.sMsgType == IMServerMessage_ServerMsgType_NoChatGroupMessage) {
        return;
    }
    //群消息置顶/取消置顶，不做数据存储，不进行展示，只通知UI层刷新
    if (message.sMsgType == IMServerMessage_ServerMsgType_GroupMessageTop) {
        // 通知UI层刷新置顶消息列表
        [self.messageDelegate cimToolChatMessageReceive:model];
        return;
    }

    //是否允许是视频通话，不进行展示
    if (message.sMsgType == IMServerMessage_ServerMsgType_GroupIsAllowNetCallMessage) {
        BOOL resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        if (resultSession) {
            [self.messageDelegate cimToolChatMessageReceive:model];
        }
        return;
    }
    
    //开启/关闭 群通知（管理后台修改群消息通知）
    if (message.sMsgType == IMServerMessage_ServerMsgType_UpdateGroupInformStatusForAdminSystem) {
        GroupStatusMessage *statusMessage = message.groupStatusMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:statusMessage.gid];
        groupModel.groupInformStatus = statusMessage.status;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        BOOL resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        [self.messageDelegate cimToolChatMessageReceive:model];
        return;
    }
    
    //开启/关闭 "关闭群提示"开关
    if (message.sMsgType == IMServerMessage_ServerMsgType_GroupMessageInform) {
        GroupStatusMessage *statusMessage = message.groupStatusMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:statusMessage.gid];
        groupModel.isMessageInform = statusMessage.status;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        BOOL resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        return;
    }
    //踢人，踢出的是虚拟用户
    if (message.sMsgType == IMServerMessage_ServerMsgType_KickGroupMessage) {
        KickGroupMessage *kickGroupMessage = message.kickGroupMessage;
        if (kickGroupMessage.type == 2) {
            return;
        }
    }
    //虚拟用户主动退群
    if (message.sMsgType == IMServerMessage_ServerMsgType_OutGroupMessage) {
        OutGroupMessage *outGroupMessage = message.outGroupMessage;
        if (outGroupMessage.type == 2) {
            return;
        }
    }
    //邀请虚拟用户进群
    if (message.sMsgType == IMServerMessage_ServerMsgType_InviteConfirmGroupMessage) {
        InviteConfirmGroupMessage *inviteModel = message.inviteConfirmGroupMessage;
        if (inviteModel.type == 5) {
            return;
        }
    }
    
    
    //3.更新会话列表+消息存储到数据库
    BOOL resultSession = NO;
    if (message.sMsgType == IMServerMessage_ServerMsgType_OutGroupMessage) {
        /**主动退群*/
        OutGroupMessage *outGroupMember = message.outGroupMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:outGroupMember.gid];
        //       if (groupModel.groupInformStatus == 1) {
        //           //开启群通知
        //           LingIMGroupMemberModel *groupOwnerModel = [self imSdkGetGroupOwnerWith:outGroupMember.gid exceptUserId:@""];
        //           if (groupModel.isMessageInform == 1) {
        //               //开关打开，除了群主，其他人不显示该条提示
        //               if ([groupOwnerModel.userUid isEqualToString:self.myUserID]) {
        //                   //群主 此消息需要缓存数据库，并且传递给kit层
        //                   resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        //               } else {
        //                   resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        //               }
        //           } else {
        //               //此消息需要缓存数据库，并且传递给kit层
        //               if (outGroupMember.informUidArray != nil) {
        //                   if (outGroupMember.informUidArray.count == 0 || [outGroupMember.informUidArray containsObject:self.myUserID]) {
        //                       resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        //                   } else {
        //                       resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        //                   }
        //               } else {
        //                   resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        //               }
        //           }
        //       } else {
        //           //关闭群通知（此消息不需要缓存数据库，但是需要传递给kit层）
        //           resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        //       }
        //        resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        [self.messageDelegate cimToolChatMessageReceive:model];
   } else if (message.sMsgType == IMServerMessage_ServerMsgType_DelGroupMessage) {
        [self.messageDelegate cimToolChatMessageReceive:model];

   } else if (message.sMsgType == IMServerMessage_ServerMsgType_KickGroupMessage) {
       /**踢人*/
       KickGroupMessage *kickGroupMsg = message.kickGroupMessage;
       if (kickGroupMsg.msgDel) {//是否删除该成员在本群发送的所有消息
           [self toolDeleteGroupMemberAllSendMessageWith:kickGroupMsg.uid groupID:kickGroupMsg.gid];
       }
       //       LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:kickGroupMsg.gid];
       //       if (groupModel.groupInformStatus == 1) {
       //           LingIMGroupMemberModel *groupOwnerModel = [self imSdkGetGroupOwnerWith:message.kickGroupMessage.gid exceptUserId:@""];
       //           if (groupModel.isMessageInform == 1) {
       //               //开关打开，除了群主和相关操作人员，其他人不显示该条提示
       //               /*群内收到踢人消息消息KickGroupMessage：
       //                1、uid等于自己，代表自己被踢了；（执行逻辑之前一样，展示被踢弹窗）
       //                2、operate_uid等于自己，代表自己踢了某人；（展示内容和之前一样）
       //                3、uid不等于自己，operate_uid不等于自己，自己是群主，代表管理员踢了某人；（展示内容和之前一样）
       //                4、其他情况，代表群主或管理员踢了某人；（不展示，但是需要更新群信息与群成员列表）
       //                */
       //               if ([message.kickGroupMessage.uid isEqualToString:self.myUserID] || [message.kickGroupMessage.operateUid isEqualToString:self.myUserID] || (![message.kickGroupMessage.uid isEqualToString:self.myUserID] && ![message.kickGroupMessage.operateUid isEqualToString:self.myUserID] && [groupOwnerModel.userUid isEqualToString:self.myUserID])) {
       //
       //                   resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
       //               }
       //           } else {
       //               if (kickGroupMsg.informUidArray != nil) {
       //                   if (kickGroupMsg.informUidArray.count == 0 || [kickGroupMsg.informUidArray containsObject:self.myUserID]) {
       //                       resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
       //                   } else {
       //                       resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
       //                   }
       //               } else {
       //                   resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
       //               }
       //           }
       //       } else {
       //           resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
       //       }
              [self.messageDelegate cimToolChatMessageReceive:model];

   } else if (message.sMsgType == IMServerMessage_ServerMsgType_EstoppelGroupMessage) {
       /**全员禁言/解除禁言提示**/
       GroupStatusMessage *groupStatusMessage = message.groupStatusMessage;
       LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:groupStatusMessage.gid];
       if (groupModel.groupInformStatus == 1) {
           resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
       } else {
           resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
       }
   } else if (message.sMsgType == IMServerMessage_ServerMsgType_GroupSingleForbidMessage) {
       /**单人禁言**/
       GroupSingleForbidMessage *forbidMessage = message.groupSingleForbidMessage;
       LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:forbidMessage.gid];
       
       if (groupModel.groupInformStatus == 1) {
           /** 群内收到单人禁言消息GroupSingleForbidMessage：
            1、to_uid等于自己，代表自己被禁言/解除禁言；（展示内容和之前一样）
            2、from_uid等于自己，代表自己禁言/解除禁言了某人；（展示内容和之前一样）
            3、to_uid不等于自己，from_uid不等于自己，自己是群主，代表管理员主动禁言/解除禁言了某人；（展示内容和之前一样）
            4、其他情况，代表群主或管理员禁言/解除禁言了某人；（不展示）*/
           NSArray *groupOwnerMangerArr = [self imSdkGetGroupOwnerAndManagerWith:message.groupSingleForbidMessage.gid];
           NSString *ownerId = @"";
           for (LingIMGroupMemberModel *ownerManager in groupOwnerMangerArr) {
               if (ownerManager.role == 2) {
                   //群主uid
                   ownerId = ownerManager.userUid;
               }
           }
           if ([message.groupSingleForbidMessage.toUid isEqualToString:self.myUserID] || [message.groupSingleForbidMessage.fromUid isEqualToString:self.myUserID] || (![message.groupSingleForbidMessage.toUid isEqualToString:self.myUserID] && ![message.groupSingleForbidMessage.fromUid isEqualToString:self.myUserID] && [ownerId isEqualToString:self.myUserID])) {
               
               resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
           }
       } else {
           resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
       }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_InviteConfirmGroupMessage) {
        /**邀请进群**/
        InviteConfirmGroupMessage *inviteModel = message.inviteConfirmGroupMessage;
        if (inviteModel.isSilence) {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        } else {
            LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:inviteModel.gid];
            BOOL resultSession;
            if (groupModel.groupInformStatus == 1) {
                //开启群通知
                if (inviteModel.type != 5) {
                    //排除掉邀请机器人进群，邀请机器人进群只更新群成员信息，不显示系统消息提示
                    if (inviteModel.informUidArray != nil) {
                        if (inviteModel.informUidArray.count == 0 || [inviteModel.informUidArray containsObject:self.myUserID]) {
                            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
                        } else {
                            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
                        }
                    } else {
                        resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
                    }
                } else {
                    resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
                }
                [self imSdkCreatSaveGroupMemberTableWith:model.toID syncGroupMemberSuccess:^{
                } syncGroupMemberFaiule:^{
                }];
            } else {
                //关闭群通知
                //更新会话列表
                resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
                [self imSdkCreatSaveGroupMemberTableWith:model.toID syncGroupMemberSuccess:^{
                } syncGroupMemberFaiule:^{
                }];
            }
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_NoticeGroupMessage) {
        /**发布/修改群公告**/
        NoticeGroupMessage *noticeGroupMessage = message.noticeGroupMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:noticeGroupMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_DelGroupNotice) {
        /**删除群公告**/
        DelGroupNotice *delGroupNotice = message.delGroupNotice;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:delGroupNotice.gid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_AdminGroupMessage) {
        /**变更群管理员**/
        AdminGroupMessage *adminGroupMessage = message.adminGroupMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:adminGroupMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            if (adminGroupMessage.informUidArray != nil) {
                if (adminGroupMessage.informUidArray.count == 0 || [adminGroupMessage.informUidArray containsObject:self.myUserID]) {
                    resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
                } else {
                    resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
                }
            } else {
                resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
            }
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_TransferOwnerMessage) {
        /**移交群主**/
        TransferOwnerMessage *transferOwnerMessage = message.transferOwnerMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:transferOwnerMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            //开启群通知
            if (transferOwnerMessage.informUidArray != nil) {
                if (transferOwnerMessage.informUidArray.count == 0 || [transferOwnerMessage.informUidArray containsObject:self.myUserID]) {
                    resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
                } else {
                    resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
                }
            } else {
                resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
            }
        } else {
            //关闭群通知
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_NameGroupMessage) {
        /**修改群名称**/
        NameGroupMessage *groupNameMessage = message.nameGroupMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:groupNameMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            //开启群通知
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            //关闭群通知
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_InviteJoinGroupNoFriendMessage) {
        /**邀请好友进群，好友拒绝进群，邀请的好友实际为“非好友关系”，被删除*/
        InviteJoinGroupNoFriendMessage *inviteJoinGroupNoFriendMessage = message.inviteJoinGroupNoFriendMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:inviteJoinGroupNoFriendMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_AvatarGroupMessage) {
        /**修改群头像**/
        AvatarGroupMessage *groupAvatarMessage = message.avatarGroupMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:groupAvatarMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_ScheduleDeleteMessage) {
        /**定时删除设置提示**/
        ScheduleDeleteMessage *scheduleDeleteMessage = message.scheduleDeleteMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:scheduleDeleteMessage.peerUid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_InviteJoinGroupBlackFriendMessage) {
        /**邀请好友进群，好友拒绝进群，邀请的好友实际为“非好友关系”，被拉黑**/
        InviteJoinGroupBlackFriendMessage *inviteJoinGroupBlackFriendMessage = message.inviteJoinGroupBlackFriendMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:inviteJoinGroupBlackFriendMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_IsShowHistoryMessage) {
        /**新成员可查看历史消息提示**/
        GroupStatusMessage *groupStatusMessage = message.groupStatusMessage;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:groupStatusMessage.gid];
        if (groupModel.groupInformStatus == 1) {
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        } else {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        }
    } else if (message.sMsgType == IMServerMessage_ServerMsgType_CreateGroupMessage) {
        /**创建群组**/
        if (message.createGroupMessage.isSilence) {
            resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
        } else {
            if ([message.createGroupMessage.uid isEqualToString:self.myUserID]) {
                //群主
                resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
            } else {
                resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:model];
            }
        }
        [self imSdkCreatSaveGroupMemberTableWith:model.toID syncGroupMemberSuccess:^{
        
        } syncGroupMemberFaiule:^{
        }];
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:message.createGroupMessage.gid];
        groupModel.groupInformStatus = 1;// 默认开启群通知
        groupModel.isMessageInform = 1; //默认开启 关闭群提示 开关
        groupModel.isActiveEnabled = 1;//默认开启
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
    } else {
        resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
    }
    
    if (resultSession) {
        //本地存储成功后，将消息传递到UI层
        //数据传递到UI层
        //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
        if (message.sMsgType == IMServerMessage_ServerMsgType_CreateGroupMessage) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.messageDelegate cimToolChatMessageReceive:model];
            });
        } else {
            [self.messageDelegate cimToolChatMessageReceive:model];
        }
    }
}

#pragma mark - 处理接收到的 支付通知 系统通知消息
- (void)toolDealReceiveServiceMessageForPaymentAssistant:(IMServerMessage *)message {
    //系统通知消息转换为数据库类型消息
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    model.serverMessageProtobuf = message.delimitedData;//protobuf
    model.messageType = CIMChatMessageType_ServerMessage;//群聊里的系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_PaymentAssistant;//支付通知
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = YES;//系统通知消息，默认已读
    model.currentVersionMessageOK = YES;//当前版本支持音视频通话消息(默认)
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    model.fromID = message.from;
    model.fromNickname = message.nick;
    
    //更新到本地数据库
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID], @"100009"];
    [DBTOOL insertOrUpdateChatMessageWith:model tableName:sessionTableName];
}

#pragma mark - <<<<<<自定义事件 系统通知>>>>>>
#pragma mark - 处理接收到的 自定义事件 系统通知
- (void)imSdkDealReceiveServiceMessageForCustomEvent:(IMServerMessage *)message {
    //系统通知消息-自定义事件
    CustomEvent *Call = message.customEvent;
    switch (Call.type) {
        case 101://音视频通话(单人)
        {
            [self imSdkDealReceiveServiceMessageForCall:message];
        }
            break;
        case 102://音视频通话(多人) 仅发给通话成员
        {
            [self imSdkDealReceiveServiceMessageForGroupCall:message];
        }
            break;
        case 103://音视频通话状态信息(成员加入，退出，通话结束)给群里所有人发
        {
            [self imSdkDealReceiveServiceMessageForGroupCallInfoChange:message];
        }
            break;
            
            
        default:
            break;
    }
}

#pragma mark - <<<<<<私有方法>>>>>>
#pragma mark - 创建群聊
- (void)serverMessageForGroupCreatWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    CreateGroupMessage *createGroupModel = message.createGroupMessage;
    
    //群组新增数据
    LingIMGroupModel *groupModel = [LingIMGroupModel new];
    groupModel.groupId = createGroupModel.gid;
    groupModel.groupName = createGroupModel.gName;
    groupModel.groupAvatar = createGroupModel.gHeader;
    groupModel.msgTop = createGroupModel.groupInfo.msgTop;//置顶
    groupModel.msgNoPromt = createGroupModel.groupInfo.msgNoPromt;//消息免打扰
    groupModel.isGroupChat = createGroupModel.groupInfo.isGroupChat;//全员禁言
    groupModel.isNeedVerify = createGroupModel.groupInfo.isNeedVerify;//进群验证
    groupModel.isPrivateChat = createGroupModel.groupInfo.isPrivateChat;//群内禁止私聊
    groupModel.groupStatus = createGroupModel.groupInfo.gStatus;//群状态
    groupModel.isMessageInform = 1;//是否关闭提示 默认开启
    groupModel.isActiveEnabled = 1;//是否展示群活跃等级 默认开启
    
    [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
    //代理到UI层
    [self.groupDelegate cimToolGroupReceiveWith:groupModel];
    
    //和该群相关的信息
    model.toID = createGroupModel.gid;
    model.fromID = createGroupModel.gid;
    model.fromNickname = createGroupModel.gName;
    model.fromIcon = createGroupModel.gHeader;
}

#pragma mark - 邀请进群
- (void)serverMessageForGroupInviteConfirmWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    
    InviteConfirmGroupMessage *inviteConfirmModel = message.inviteConfirmGroupMessage;
    
    if (inviteConfirmModel.status == 1) {
        //确认进群
        //被邀请进群成员
        __weak typeof(self) weakSelf = self;
        NSArray *invitedMemberArr = inviteConfirmModel.inviteUidArray;
        [invitedMemberArr enumerateObjectsUsingBlock:^(UserInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.uId isEqualToString:[self myUserID]]) {
                //我被邀请进群 群组新增数据
                LingIMGroupModel *groupModel = [LingIMGroupModel new];
                groupModel.groupId = inviteConfirmModel.gid;
                groupModel.groupName = inviteConfirmModel.gName;
                groupModel.groupAvatar = inviteConfirmModel.gHeader;
                groupModel.msgTop = NO;//置顶
                groupModel.msgNoPromt = NO;//消息免打扰
                groupModel.isGroupChat = NO;//全员禁言
                groupModel.isNeedVerify = NO;//进群验证
                groupModel.isPrivateChat = NO;//群内禁止私聊
                groupModel.groupStatus = 1;//群状态
                groupModel.isMessageInform = 1;//群提示状态
                groupModel.isActiveEnabled = 1;//展示群活跃等级 默认开启
                [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
                //代理到UI层
                [weakSelf.groupDelegate cimToolGroupReceiveWith:groupModel];
                [weakSelf imSdkCreatSaveGroupMemberTableWith:inviteConfirmModel.gid syncGroupMemberSuccess:^{
                    
                } syncGroupMemberFaiule:^{
                    
                }];
                *stop = YES;
            }
        }];
        
    }else {
        //拒绝进群
    }
    
    //和该群相关的信息
    model.toID = inviteConfirmModel.gid;
    model.fromID = inviteConfirmModel.gid;
    model.fromNickname = inviteConfirmModel.gName;
    model.fromIcon = inviteConfirmModel.gHeader;
    model.backDelInformSwitch = inviteConfirmModel.informSwitch;
    model.backDelInformUidArray = inviteConfirmModel.informUidArray;
    [self.messageDelegate cimToolChatMessageReceive:model];
    
}

#pragma mark - 处理接收到的 用户不在群内、群组不存在、群禁言(全员)开启、用户在群组内被禁言 系统通知消息
- (void)serverMessageForGroupTipsWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    
    GroupTipChatMessage *groupTipMessage = message.groupTipChatMessage;
    
    //和该群相关的信息
    model.toID = groupTipMessage.gid;
    
    //接收到该提示消息的时候，说明上一个发送的消息是展示失败状态
    //更新已发送消息的状态为失败
    NSString *serverMessageID = message.sMsgId;
    NoaIMChatMessageModel *chatMessage = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:serverMessageID sessionID:model.toID];
    if (chatMessage && ![chatMessage.fromID isEqualToString:[self myUserID]]) chatMessage = nil;
    if (chatMessage) {
        switch (message.sMsgType) {
            case IMServerMessage_ServerMsgType_GroupNoChatMessage:
            case IMServerMessage_ServerMsgType_MemberGroupForbidMessage:
                chatMessage.sendFailureReason = CIMMessageSendFailureReasonGroupMuted;
                break;
            case IMServerMessage_ServerMsgType_NullGroupMessage:
                chatMessage.sendFailureReason = CIMMessageSendFailureReasonGroupUnavailable;
                break;
            case IMServerMessage_ServerMsgType_MemberNoGroupMessage:
                chatMessage.sendFailureReason = CIMMessageSendFailureReasonNotGroupMember;
                break;
            default: break;
        }
    }
    chatMessage.messageSendType = CIMChatMessageSendTypeFail;
    BOOL resultUpdate = chatMessage && [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
    if (resultUpdate) {
        //本地存储成功后，将消息传递到UI层
        [self.messageDelegate cimToolChatMessageUpdate:chatMessage];
    }
    
    //消息类型 用户不在群内(你不在该群内)，群组不存在(该群不存在)，查询本地是否有该群，有则删除，代理到UI层
    if (message.sMsgType == IMServerMessage_ServerMsgType_MemberNoGroupMessage || message.sMsgType == IMServerMessage_ServerMsgType_NullGroupMessage) {
        LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupTipMessage.gid];
        if (groupModel) {
            [self toolDeleteMyGroupWith:groupTipMessage.gid];
            [self.groupDelegate cimToolGroupDeleteWith:groupModel];
        }
    }
    
}

#pragma mark - 处理接收到的 群成员被踢 系统通知消息
- (void)serverMessageForGroupMemberKickWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //被踢成员信息
    KickGroupMessage *memberKickMessage = message.kickGroupMessage;
    
    if ([memberKickMessage.uid isEqualToString:[self myUserID]]) {
        //我被踢出群聊
        LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:memberKickMessage.gid];
        if (groupModel) {
            [self toolDeleteMyGroupWith:memberKickMessage.gid];
            //代理到UI层
            [self.groupDelegate cimToolGroupDeleteWith:groupModel];
        }
    }
    
    //和该群相关的信息
    model.toID = memberKickMessage.gid;
    
    model.backDelInformSwitch = memberKickMessage.informSwitch;
    
    model.backDelInformUidArray = memberKickMessage.informUidArray;
}

#pragma mark - 处理接收到的 群成员退群 系统通知消息
- (void)serverMessageForGroupMemberQuitWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //退群成员信息
    OutGroupMessage *memberOut = message.outGroupMessage;
    
    if ([memberOut.uid isEqualToString:[self myUserID]]) {
        //我退出了群聊
        LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:memberOut.gid];
        if (groupModel) {
            [self toolDeleteMyGroupWith:memberOut.gid];
            //代理到UI层
            [self.groupDelegate cimToolGroupDeleteWith:groupModel];
        }
    }
    
    //和该群相关的信息
    model.toID = memberOut.gid;
    
    model.backDelInformSwitch = memberOut.informSwitch;
    
    model.backDelInformUidArray = memberOut.informUidArray;
}

#pragma mark - 处理接收到的 转让群主 系统通知消息
- (void)serverMessageForGroupOwnerTransferWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //新群主信息
    TransferOwnerMessage *newOwner = message.transferOwnerMessage;
    
    //和该群相关的信息
    model.toID = newOwner.gid;
    model.backDelInformSwitch = newOwner.informSwitch;
    model.backDelInformUidArray = newOwner.informUidArray;
}

#pragma mark - 处理接收到的 群禁言开启/关闭 系统通知消息
- (void)serverMessageForGroupBannedWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群状态
    GroupStatusMessage *groupStatus = message.groupStatusMessage;
    //groupStatus.status 1群主开启了全员禁言 2群主关闭了全员禁言
    
    //和该群相关的信息
    model.toID = groupStatus.gid;
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupStatus.gid];
    if (groupModel) {
        groupModel.isGroupChat = groupStatus.status == 1 ? YES : NO;
        [self toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
}

#pragma mark - 处理接收到的 群管理员设置 系统通知消息
- (void)serverMessageForGroupAdminSetWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //管理员操作
    AdminGroupMessage *groupAdmin = message.adminGroupMessage;
    
    //和该群相关的信息
    model.toID = groupAdmin.gid;
    
    model.backDelInformSwitch = groupAdmin.informSwitch;
    
    model.backDelInformUidArray = groupAdmin.informUidArray;
    
}

#pragma mark - 处理接收到的 群名称修改 系统通知消息
- (void)serverMessageForGroupNameChangeWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群名称修改
    NameGroupMessage *groupName = message.nameGroupMessage;
    
    //和该群相关的信息
    model.toID = groupName.gid;
    
    //修改数据库会话信息
    LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:groupName.gid];
    if (sessionModel) {
        sessionModel.sessionName = groupName.gName;
        [IMSDKManager toolUpdateSessionWith:sessionModel];
    }
    
    //修改数据库群信息
    LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:groupName.gid];
    if (groupModel) {
        groupModel.groupName = groupName.gName;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
    
}

#pragma mark - 处理接收到的 群公告设置 系统通知消息
- (void)serverMessageForGroupNoticeSetWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群公告信息
    NoticeGroupMessage *groupNotice = message.noticeGroupMessage;
    
    //和该群相关的信息
    model.toID = groupNotice.gid;
}

#pragma mark - 处理接收到的 群成员被禁言 系统通知消息
- (void)serverMessageForGroupMemberBannedWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //被禁言群成员信息
    GroupSingleForbidMessage *memberBanned = message.groupSingleForbidMessage;
    
    //和该群相关的信息
    model.toID = memberBanned.gid;
}

#pragma mark - 处理接收到的 解散群组 系统通知消息 该消息只转发给在线的所有群成员
- (void)serverMessageForGroupDissolveWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群解散信息
    DelGroupMessage *groupDissolve = message.delGroupMessage;
    
    //和该群相关的信息
    model.toID = groupDissolve.gid;
    
    //如果解散群，本地有数据，删除，更新到UI层
    LingIMGroupModel *groupDissolveModel = [self toolCheckMyGroupWith:groupDissolve.gid];
    if (groupDissolveModel) {
        [self toolDeleteMyGroupWith:groupDissolve.gid];
        [self.groupDelegate cimToolGroupDeleteWith:groupDissolveModel];
    }
    
}

#pragma mark - 邀请好友进群，但是好友不存在，该消息只转发给邀请加入的用户
- (void)serverMessageForInviteJoinGroupNoFriendWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //非好友不能邀请入群
    InviteJoinGroupNoFriendMessage *InviteJoinGroupNoFriend = message.inviteJoinGroupNoFriendMessage;
    
    //和该群相关的信息
    model.toID = InviteJoinGroupNoFriend.gid;
}

#pragma mark - 邀请好友进群，但是已被拉黑，该消息只转发给邀请加入的用户
- (void)serverMessageForInviteJoinGroupBlackFriendWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //被拉黑不能邀请入群
    InviteJoinGroupBlackFriendMessage *InviteJoinGroupBlackFriend = message.inviteJoinGroupBlackFriendMessage;
    
    //和该群相关的信息
    model.toID = InviteJoinGroupBlackFriend.gid;
}

#pragma mark - 群头像修改
- (void)serverMessageForGroupAvatarChangeWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群头像更改
    AvatarGroupMessage *avatarGroup = message.avatarGroupMessage;
    
    //和该群相关的信息
    model.toID = avatarGroup.gid;
    
    //修改数据库会话信息
    LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:avatarGroup.gid];
    if (sessionModel) {
        sessionModel.sessionAvatar = avatarGroup.gAvatar;
        [IMSDKManager toolUpdateSessionWith:sessionModel];
    }
    
    //修改数据库群信息
    LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:avatarGroup.gid];
    if (groupModel) {
        groupModel.groupAvatar = avatarGroup.gAvatar;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
    
}

#pragma mark - 删除群公告
- (void)serverMessageForGroupNoticeDeleteWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //删除群公告信息
    DelGroupNotice *delGroupNotice = message.delGroupNotice;
    
    //和该群相关的信息
    model.toID = delGroupNotice.gid;
    
}

#pragma mark - 群内禁止私聊
- (void)serverMessageForGroupNoChatWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群内禁止私聊信息
    GroupStatusMessage *groupNoChat = message.groupStatusMessage;
    
    //和该群相关的信息
    model.toID = groupNoChat.gid;
    
    //群内禁止私聊消息，不进行数据库存储和UI展示
    
    if (groupNoChat.type != 8) {
        //发送通知进行状态更新
        NSDictionary *userInfoDict = @{@"gid":groupNoChat.gid,@"status":@(groupNoChat.status)};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupNoChatStatusChange" object:nil userInfo:userInfoDict];
        //更新本地数据库群组信息
        LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupNoChat.gid];
        if (groupModel) {
            groupModel.isPrivateChat = groupNoChat.status == 1 ? YES : NO;
            [self toolInsertOrUpdateGroupModelWith:groupModel];
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
        }
    } else {
        //更新本地数据库群组信息
        LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupNoChat.gid];
        if (groupModel) {
            groupModel.isShowHistory = groupNoChat.status == 1 ? YES : NO;
            [self toolInsertOrUpdateGroupModelWith:groupModel];
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
        }
    }
    
}

#pragma mark - 群内删除通知全体群成员删除指定群成员历史消息
- (void)deleteGroupMemberMessageWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群内单人禁言删除通知全体群成员
    GroupAllForbidMessage *groupAllForbid = message.groupAllForbidMessage;
    
        
    //群内清空某群成员消息通知全体群成员消息，不进行数据库存储和UI展示
    for (NSString *uid in groupAllForbid.uidArray) {
        [self toolDeleteGroupMemberAllSendMessageWith:uid groupID:groupAllForbid.gid];
    }
    
    //发送通知进行状态更新
    NSDictionary *userInfoDict = @{@"gid":groupAllForbid.gid,@"deleteMemberUidList":groupAllForbid.uidArray};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupDeleteMemberHistoryNotification" object:nil userInfo:userInfoDict];
}

#pragma mark - 是否开启群聊天历史记录
- (void)serverMessageForIsShowHistoryMessageWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群内禁止私聊信息
    GroupStatusMessage *groupNoChat = message.groupStatusMessage;
    
    //和该群相关的信息
    model.toID = groupNoChat.gid;
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupNoChat.gid];
    if (groupModel) {
        groupModel.isShowHistory = groupNoChat.status == 1 ? YES : NO;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
}


#pragma mark - 关闭搜索用户消息通知
- (void)serverMessageForGroupCloseSearchUserMessageWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    GroupCloseSearchUserMessage *groupCloseSearchUserMessage = message.groupCloseSearchUserMessage;
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupCloseSearchUserMessage.gId];
    if (groupModel) {
        groupModel.closeSearchUser = groupCloseSearchUserMessage.closeSearchUser;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
}

#pragma mark - 是否进群验证 告知所有在线的群成员群是否开启或关闭了进群验证 213
- (void)serverMessageForGroupJoinVerifyWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //是否开启了进群验证
    GroupStatusMessage *groupJoinVerify = message.groupStatusMessage;
    
    //和该群相关的信息
    model.toID = groupJoinVerify.gid;
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:groupJoinVerify.gid];
    if (groupModel) {
        groupModel.isNeedVerify = groupJoinVerify.status == 1 ? YES : NO;
        [IMSDKManager toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
}
#pragma mark - 邀请进群申请  该消息发送给群管理员? 214
- (void)serverMessageForGroupInviteToJoinWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //邀请入群信息
    //InviteJoinRepGroupMessage *inviteJoinGroup = message.inviteJoinRepGroupMessage;
    
    //收到系统消息(群助手)相关的 serverMessage需要特殊的操作(区别之前的群操作)
    
    //和该会话相关的信息
    model.toID = message.from;//系统消息(群助手)的会话ID
    model.fromID = message.from;
    model.fromNickname = message.nick;
    model.fromIcon = message.icon;
    model.chatType = CIMChatType_SystemMessage;//系统消息 (群助手) 类型
    model.chatMessageReaded = NO;//系统通知消息，此处设为未读
    
}
#pragma mark - 处理接收到的 群锁定开启/关闭 系统通知消息 209
- (void)serverMessageForGroupLockWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群锁定状态
    GroupStatusMessage *groupLock = message.groupStatusMessage;
    //groupLock.status 1群锁定 2群解除锁定
    
    //和该群相关的信息
    model.toID = groupLock.gid;
    
    //群锁定消息，不进行数据库存储和UI展示
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupLock.gid];
    if (groupModel) {
        groupModel.groupStatus = groupLock.status == 1 ? 0 : 1;
        [self toolInsertOrUpdateGroupModelWith:groupModel];
        [self.groupDelegate cimToolGroupUpdateWith:groupModel];
    }
    
    //发送通知进行状态更新
    NSDictionary *userInfoDict = @{@"gid":groupLock.gid,@"status":@(groupLock.status)};//1封禁 2解封
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GroupBannedStatusChange" object:nil userInfo:userInfoDict];
    
}

#pragma mark - 是否开启全员禁止拨打音视频 234
- (void)serverMessageForIsAllowNetCallMessageWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群状态Message
    GroupStatusMessage *groupStatusMsg = message.groupStatusMessage;
    //groupStatusMsg.status 1:开启,0:关闭
    
    //和该群相关的信息
    model.toID = groupStatusMsg.gid;
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupStatusMsg.gid];
    if (groupModel) {
        groupModel.isNetCall = groupStatusMsg.status == 1 ? NO : YES;
        BOOL isResult = [self toolInsertOrUpdateGroupModelWith:groupModel];
        if (isResult) {
            //本地存储成功后，将消息传递到UI层
            //数据传递到UI层
            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
            [self.messageDelegate cimToolChatMessageReceive:model];
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
        }
    }
}

#pragma mark - 是否开启群提示 236
- (void)serverMessageForIsGroupMessageInformWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //群状态Message
    GroupStatusMessage *groupStatusMsg = message.groupStatusMessage;
    //groupStatusMsg.status 1:开启,0:关闭
    
    //和该群相关的信息
    model.toID = groupStatusMsg.gid;
    
    //更新本地数据库群组信息
    LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupStatusMsg.gid];
    if (groupModel) {
        groupModel.isMessageInform = groupStatusMsg.status;
        BOOL isResult = [self toolInsertOrUpdateGroupModelWith:groupModel];
        if (isResult) {
            //本地存储成功后，将消息传递到UI层
            //数据传递到UI层
            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
        }
    }
}

#pragma mark - 处理接收到的 封禁 系统通知消息 508
- (void)serverMessageForSystemBannedWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    //系统封禁消息
    SystemBannedMessage *systemBanned = message.systemBannedMessage;
    
    //封禁类型 1:用户，2:IP，3:设备
    if (systemBanned.bannedType == 1) {
    }else if (systemBanned.bannedType == 2) {
    }else if (systemBanned.bannedType == 3) {
    }
    
}

#pragma mark - 处理接收到的 清空会话聊天记录 系统通知
- (void)serverMessageForSessionClearMessageWith:(NoaIMChatMessageModel * _Nullable)model serverMessage:(IMServerMessage *)message {
    //清空聊天记录信息
    DelMsgMessage *clearMessage = message.delMsgMessage;
    
    if (clearMessage.cType == ChatType_SingleChat) {
        //清空单聊的会话聊天记录
    }else if (clearMessage.cType == ChatType_GroupChat) {
        //清空群聊的会话聊天记录
    }
    
    //会话ID
    NSString *sessionID = [NSString stringWithFormat:@"%@", clearMessage.toUid];
    //清空该会话的聊天消息
    [self toolDeleteAllChatMessageWith:sessionID];
}

#pragma mark - 处理接收到的 上报日志 系统通知
- (void)serverMessageForSystemUserOperationStatusMessageWith:(NoaIMChatMessageModel * _Nullable)model serverMessage:(IMServerMessage *)message {
    UserOperationStatus *userOperationStatus = message.userOperationStatus;
    
    if (userOperationStatus.status == 1 && [userOperationStatus.operationType isEqualToString:@"1"]) {

        //上传前一天的日志
        NSDate *todayDate = [NSDate date];
        NSDate *lastDayDate = [NSDate dateWithTimeInterval:-24 * 60 * 60 sinceDate:todayDate];
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
        NSString *lastDayDateStr = [fmt stringFromDate:lastDayDate];
        [[NoaIMLoganManager sharedManager] loganUploadWith:lastDayDateStr complete:nil];

    }
    
}

#pragma mark - 处理接收到的 群消息置顶/取消置顶 系统通知消息
- (void)serverMessageForGroupMessageTopWith:(NoaIMChatMessageModel *)model serverMessage:(IMServerMessage *)message {
    GroupMessageTop *groupMessageTop = message.groupMessageTop;
    
    //和该群相关的信息
    model.toID = groupMessageTop.gid;
    model.fromID = groupMessageTop.gid;
    model.fromNickname = groupMessageTop.nick;
    model.fromIcon = @"";
}

@end
