//
//  NoaIMSDKManager+ChatMessage.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "NoaIMSDKManager+ChatMessage.h"

#import "NoaIMHttpManager+Message.h"//消息
#import "NoaIMSDKManager+Session.h"//会话
#import "NoaIMSDKManager+Friend.h"//好友
#import "NoaIMSDKManager+Group.h"//群组
#import "NoaIMSDKManager+MessageRemind.h"//消息提醒
#import "NoaIMSDKManager+Call.h"//音视频通话
#import "NoaIMSDKManager+GroupMember.h"
#import "NoaIMSDKManager+Translate.h"
#import "NoaIMSDKManager+AppInfo.h"
#import "NoaChatMessageModel.h"

/// 每页展示数据数量（分页上限，统一 100 条）
#define kPageNumber 100

/// 历史回写时合并本地字段，并保护已确认消息的 sendTime，避免小幅时间差导致跨日乱序
static inline void LIMMergeLocalFieldsBeforeHistoryUpsert(NoaIMChatMessageModel *serverMessage, NoaIMChatMessageModel *localMessage) {
    if (!serverMessage || !localMessage) { return; }
    if (localMessage.translateStatus != CIMTranslateStatusNone) {
        serverMessage.translateStatus = localMessage.translateStatus;
        if (localMessage.translateContent.length > 0) {
            serverMessage.translateContent = localMessage.translateContent;
        }
        if (localMessage.againTranslateContent.length > 0) {
            serverMessage.againTranslateContent = localMessage.againTranslateContent;
        }
        serverMessage.localTranslatedShown = localMessage.localTranslatedShown;
    }
    if (localMessage.messageSendType == CIMChatMessageSendTypeSuccess &&
        localMessage.sendTime > 0 &&
        serverMessage.sendTime > 0 &&
        llabs(localMessage.sendTime - serverMessage.sendTime) <= 3000) {
        serverMessage.sendTime = localMessage.sendTime;
    }
}

@implementation NoaIMSDKManager (ChatMessage)

#pragma mark - 发送聊天消息
- (void)toolSendChatMessageWith:(NoaIMChatMessageModel *)message {
    
    //1.将数据库聊天消息，转换为发送消息
    IMChatMessage *chatMessage = [[LingIMModelTool sharedTool] getChatMessageModelFromLingIMChatMessageModel:message];
    
    if (message.messageType == CIMChatMessageType_HaveReadMessage) {
        //已读消息HaveReadMessage
        message.messageStatus = 1;//发送的消息，默认是正常状态消息
        message.currentVersionMessageOK = YES;//发送的消息，默认是当前版本支持的

        IMMessage *messageModel = [[IMMessage alloc] init];
        messageModel.dataType = IMMessage_DataType_ImchatMessage;
        messageModel.chatMessage = chatMessage;
        cim_function_sendChatMessage(messageModel);

    } else {
        //其他正常聊天消息
        //2.发送消息 临时 保存在MMKV
        BOOL mmkvResult = [MMKVTOOL addSendChatMessageWith:chatMessage];
        
        if (mmkvResult) {
            
            //3.更新会话列表+发送消息存储到数据库
            message.chatMessageReaded = YES;//发送的消息，默认已读
            message.messageStatus = 1;//发送的消息，默认是正常状态消息
            message.currentVersionMessageOK = YES;//发送的消息，默认是当前版本支持的
            
            BOOL resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:message isRemind:YES];
            
            //4.调用SDK的发送
            if (resultSession) {
                IMMessage *messageModel = [[IMMessage alloc] init];
                messageModel.dataType = IMMessage_DataType_ImchatMessage;
                messageModel.chatMessage = chatMessage;
                cim_function_sendChatMessage(messageModel);
            }
        }
    }
}

#pragma mark - 处理接收到的聊天消息
- (void)toolDealReceiveChatMessage:(IMMessage *)message {
    IMChatMessage *messageChat = message.chatMessage;
    
    //接受到的消息去重
    NoaIMChatMessageModel *checkLocalChatMessage;
    NSString *sessionId = @"";
    if (messageChat.cType == ChatType_SingleChat) {
        if ([messageChat.from isEqualToString:self.myUserID]) {
            sessionId = messageChat.to;
        }
        if ([messageChat.to isEqualToString:self.myUserID]) {
            sessionId = messageChat.from;
        }
        checkLocalChatMessage = [self toolGetOneChatMessageWithMessageID:messageChat.msgId sessionID:sessionId];
    } else if (messageChat.cType == ChatType_GroupChat) {
        sessionId = messageChat.to;
        checkLocalChatMessage = [self toolGetOneChatMessageWithMessageID:messageChat.msgId sessionID:sessionId];
    }
    if (checkLocalChatMessage) {
        return;
    }
    
    //音视频通话
    if (messageChat.cType == ChatType_NetCallChat) {
        [self imSdkDealReceiveChatMessageForCall:messageChat];
        return;
    }
    
    //聊天消息转换为数据库类型消息
    NoaIMChatMessageModel *chatModel = [[LingIMModelTool sharedTool] getChatMessageModelFromIMChatMessage:messageChat];
    chatModel.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    
    //15双向删除消息，不做存储，只进行消息的数据库删除
    if (chatModel.messageType == CIMChatMessageType_BilateralDel) {
        [self toolChatMessageDeleteBothwayWith:chatModel];
        return;
    }
    
    //更新会话列表+消息存储到数据库
    BOOL resultSession =  NO;
    
    //8撤回消息 数据库删除撤回的消息
    if (chatModel.messageType == CIMChatMessageType_BackMessage) {
        if (chatModel.chatType == CIMChatType_GroupChat) {
            //群聊
            if (message.chatMessage.backDelMessage.informSwitch == 2) {
                //关闭群通知
                resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:chatModel];
                if (resultSession) {
                    [self.messageDelegate cimToolChatMessageReceive:chatModel];
                }
            } else {
                //开启群通知
                if (message.chatMessage.backDelMessage.informUidArray != nil) {
                    if (message.chatMessage.backDelMessage.informUidArray.count == 0 || [message.chatMessage.backDelMessage.informUidArray containsObject:self.myUserID]) {
                        resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:YES];
                    } else {
                        resultSession = [IMSDKManager toolInsertSessionForCloseGroupRemindWith:chatModel];
                    }
                } else {
                    resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:YES];
                }
                if (resultSession) {
                    [self.messageDelegate cimToolChatMessageReceive:chatModel];
                    //消息提醒
                    [IMSDKManager toolMessageReceiveRemindWith:message];
                }
            }
        } else {
            //单聊
            //更新会话列表+消息存储到数据库
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:YES];
            if (resultSession) {
                [self.messageDelegate cimToolChatMessageReceive:chatModel];
                //消息提醒
                [IMSDKManager toolMessageReceiveRemindWith:message];
            }
        }

        [self toolChatMessageDeleteBackWith:chatModel];
    } else {
        //翻译
        if (chatModel.messageType == CIMChatMessageType_TextMessage || chatModel.messageType == CIMChatMessageType_AtMessage) {
            LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:sessionId];
            if (sessionModel.isReceiveAutoTranslate == 1 && [IMSDKManager toolIsTranslateEnabled]) {
                __weak typeof(self) weakSelf = self;
                if (chatModel.messageType == CIMChatMessageType_AtMessage) {
                    chatModel.translateStatus = CIMTranslateStatusLoading;
                    [self requestTranslateActionWithContent:chatModel.atContent atUserDictList:chatModel.atUsersInfoList sessionId:sessionId messageType:chatModel.messageType success:^(NSString * _Nullable result) {
                        chatModel.translateStatus = CIMTranslateStatusSuccess;
                        chatModel.againAtTranslateContent = result;
                        // 标记：本机已成功展示过译文
                        chatModel.localTranslatedShown = 1;
                        // 持久化消息，保证下次进入仍展示
                        [IMSDKManager toolInsertOrUpdateChatMessageWith:chatModel];
                        
                        //更新会话列表+消息存储到数据库
                        BOOL translateResultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:NO];
                        if (translateResultSession) {
                            //本地存储成功后，将消息传递到UI层
                            //数据传递到UI层
                            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                            // 使用 cimToolChatMessageUpdate 而不是 cimToolChatMessageReceive，避免重复添加消息
                            [weakSelf.messageDelegate cimToolChatMessageUpdate:chatModel];
                            //                            [weakSelf.sessionDelegate imSdkSessionSyncFinish];
                            //消息提醒
                            [IMSDKManager toolMessageReceiveRemindWith:message];
                        }
                    } failure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                        chatModel.translateStatus = CIMTranslateStatusFail;
                        //更新会话列表+消息存储到数据库
                        BOOL translateResultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:NO];
                        if (translateResultSession) {
                            //本地存储成功后，将消息传递到UI层
                            //数据传递到UI层
                            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                            // 使用 cimToolChatMessageUpdate 而不是 cimToolChatMessageReceive，避免重复添加消息
                            [weakSelf.messageDelegate cimToolChatMessageUpdate:chatModel];
                            //                            [weakSelf.sessionDelegate imSdkSessionSyncFinish];
                            //消息提醒
                            [IMSDKManager toolMessageReceiveRemindWith:message];
                        }
                    }];
                } else if (chatModel.messageType == CIMChatMessageType_TextMessage) {
                    chatModel.translateStatus = CIMTranslateStatusLoading;
                    [self requestTranslateActionWithContent:chatModel.textContent atUserDictList:@[] sessionId:sessionId messageType:chatModel.messageType success:^(NSString * _Nullable result) {
                        chatModel.translateStatus = CIMTranslateStatusSuccess;
                        chatModel.againTranslateContent = result;
                        // 标记：本机已成功展示过译文
                        chatModel.localTranslatedShown = 1;
                        // 持久化消息，保证下次进入仍展示
                        [IMSDKManager toolInsertOrUpdateChatMessageWith:chatModel];
                        
                        //更新会话列表+消息存储到数据库
                        BOOL translateResultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:NO];
                        if (translateResultSession) {
                            //本地存储成功后，将消息传递到UI层
                            //数据传递到UI层
                            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                            //过滤掉空白打招呼的消息
                            if (chatModel.textContent != nil && chatModel.textContent.length > 0) {
                                [weakSelf.messageDelegate cimToolChatMessageUpdate:chatModel];
                            }
                        }
                    } failure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                        chatModel.translateStatus = CIMTranslateStatusFail;
                        //更新会话列表+消息存储到数据库
                        BOOL translateResultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:NO];
                        if (translateResultSession) {
                            //本地存储成功后，将消息传递到UI层
                            //数据传递到UI层
                            //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                            //过滤掉空白打招呼的消息
                            if (chatModel.textContent != nil && chatModel.textContent.length > 0) {
                                [weakSelf.messageDelegate cimToolChatMessageUpdate:chatModel];
                            }
                        }
                    }];
                }
            }
            //更新会话列表+消息存储到数据库
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:YES];
            if (resultSession) {
                //本地存储成功后，将消息传递到UI层
                //数据传递到UI层
                //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                //过滤掉空白打招呼的消息
                if (chatModel.messageType == CIMChatMessageType_TextMessage && (chatModel.textContent == nil || chatModel.textContent.length <= 0)) {
                    return;
                } else {
                    [self.messageDelegate cimToolChatMessageReceive:chatModel];
                    //消息提醒
                    [IMSDKManager toolMessageReceiveRemindWith:message];
                }
            }
        } else {
            //更新会话列表+消息存储到数据库
            resultSession = [IMSDKManager toolInsertOrUpdateSessionWith:chatModel isRemind:YES];
            if (resultSession) {
                //本地存储成功后，将消息传递到UI层
                //数据传递到UI层
                //此处代理方法，就不能像以前那样判断是否响应，要直接触发，记录一下，防止写错
                //过滤掉空白打招呼的消息
                if (chatModel.messageType == CIMChatMessageType_TextMessage && (chatModel.textContent == nil || chatModel.textContent.length <= 0)) {
                    return;
                } else {
                    [self.messageDelegate cimToolChatMessageReceive:chatModel];
                    //消息提醒
                    [IMSDKManager toolMessageReceiveRemindWith:message];
                }
            }
        }
    }
}

#pragma mark - 获取会话聊天历史记录
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID offset:(NSInteger)offset {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    NSArray *historyList = [DBTOOL getChatMessageHistoryWith:sessionTableName limit:kPageNumber offset:offset];//时间倒序
    return [[historyList reverseObjectEnumerator] allObjects];
}

#pragma mark - 重连后获取会话聊天历史
- (NSArray *)toolReConnectGetChatMessageHistoryWith:(NSString *)sessionID limit:(NSInteger)limit offset:(NSInteger)offset {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    NSArray *historyList = [DBTOOL getChatMessageHistoryWith:sessionTableName limit:limit offset:offset];//时间倒序
    return [[historyList reverseObjectEnumerator] allObjects];
}

#pragma mark - 获取签到提醒历史消息记录
- (NSArray *)toolGetSignInHistoryWith:(NSString *)sessionID offset:(NSInteger)offset {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    NSArray *historyList = [DBTOOL getChatMessageHistoryWith:sessionTableName limit:15 offset:offset];//时间倒序
    return historyList;
}

#pragma mark - 获取某类型的聊天历史记录
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString *)likeStr {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    
    NSArray *historyList = [DBTOOL getChatMessageHistoryWith:sessionTableName limit:50 offset:offset messageType:messageType textMessageLike:likeStr];
    return historyList;
    //return [[historyList reverseObjectEnumerator] allObjects];
}

#pragma mark - 获取指定用户发送的、某类型的聊天历史记录
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString * _Nullable)likeStr userIdList:(NSArray *)userIdList {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    
    NSArray *historyList = [DBTOOL getChatMessageHistoryWith:sessionTableName limit:50 offset:offset messageType:messageType textMessageLike:likeStr userIdList:userIdList];
    return historyList;
}

#pragma mark - 获取某个时间范围内容的聊天历史记录
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID startTime:(long long)startTime endTime:(long long)endTime {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    
    NSArray *historyList = [DBTOOL getChatMessageHistoryWith:sessionTableName startTime:startTime endTime:endTime];
    return [[historyList reverseObjectEnumerator] allObjects];
}

#pragma mark - 按中心消息ID获取前后各N条图片/视频
- (NSArray *)toolGetImageVideoAroundWith:(NSString *)sessionID centerMsgId:(NSString *)centerMsgId before:(NSInteger)beforeCount after:(NSInteger)afterCount {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    NSArray *list = [DBTOOL getImageVideoAroundWith:sessionTableName centerMsgId:centerMsgId before:beforeCount after:afterCount];
    return list;
}


#pragma mark - 更新 或 新增 消息到 消息表
- (BOOL)toolInsertOrUpdateChatMessageWith:(NoaIMChatMessageModel *)message {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionTableName = [DBTOOL getSessionTableNameWith:message];
    return [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionTableName];
}

- (void)toolInsertOrUpdateChatMessagesWith:(NSArray <NoaIMChatMessageModel *>*)messageList {
    //表名称 CIMDB_myUserID_toUserID_Table
    if (messageList.count == 0) {
        return;
    }
    
    NSMutableDictionary *messageListDic = [NSMutableDictionary new];
    for (NoaIMChatMessageModel *message in messageList) {
        if (!message || ![message isKindOfClass:[NoaIMChatMessageModel class]]) {
            continue;
        }
        
        NSString *sessionTableName = [DBTOOL getSessionTableNameWith:message];
        if (!sessionTableName || sessionTableName.length == 0) {
            continue;
        }
        
        NSMutableArray *messageArr = messageListDic[sessionTableName];
        if (!messageArr) {
            messageArr = [NSMutableArray new];
            messageListDic[sessionTableName] = messageArr;
        }
        [messageArr addObject:message];
    }
   
    if (messageListDic.count == 0) {
        return;
    }
    for (NSString *sessionTableName in messageListDic) {
        NSMutableArray *messageArr = messageListDic[sessionTableName];
        if (messageArr.count == 0) {
            continue;
        }
        [DBTOOL insertOrUpdateChatMessagesWith:messageArr tableName:sessionTableName];
    }
}

#pragma mark - 删除数据库某消息
- (BOOL)toolDeleteChatMessageWith:(NoaIMChatMessageModel *)message {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionID;
    if (message.chatType == CIMChatType_NetCallChat) {
        //音视频 消息
        if (message.netCallChatType == 1) {
            //单聊音视频
            if ([message.fromID isEqualToString:[DBTOOL myUserID]]) {
                //我发的消息
                LingIMFriendModel *friendModel = [DBTOOL checkMyFriendWith:message.toID];
                sessionID = friendModel.friendUserUID;
            }else {
                //对方发的消息
                sessionID = message.fromID;
            }
        } else {
            //群聊音视频
            sessionID = message.toID;
        }
    } else {
        sessionID = [DBTOOL getSessionIDWith:message];
    }
    
    //当前最新消息
    NoaIMChatMessageModel *latestMessage = [IMSDKManager toolGetLatestChatMessageWithSessionID:sessionID];
    
    NSString *sessionTableName = [DBTOOL getSessionTableNameWith:message];
    BOOL result = [DBTOOL deleteChatMessageWith:message tableName:sessionTableName];
    
    //获取会话信息
    LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
    
    //判断删除的消息是否是最新的一条
    if ([latestMessage.msgID isEqualToString:message.msgID]) {
        NoaIMChatMessageModel *newMessage = [IMSDKManager toolGetLatestChatMessageWithSessionID:sessionID];
        sessionModel.sessionLatestMessage = newMessage;
        sessionModel.sessionLatestTime = newMessage.sendTime;
        sessionModel.sessionLatestServerMsgID = newMessage.serviceMsgID;
    }
    
    //如果删除的是我未读的消息
    if (!message.chatMessageReaded && ![message.fromID isEqualToString:[self myUserID]]) {
        if (sessionModel.sessionUnreadCount > 0) {
            sessionModel.sessionUnreadCount--;
        }else {
            sessionModel.sessionUnreadCount = 0;
        }
    }
    
    //更新会话信息
    [IMSDKManager toolUpdateSessionWith:sessionModel];
    
    return result;
}
#pragma mark - 撤回数据库某消息
- (BOOL)toolBackDeleteChatMessageWith:(NoaIMChatMessageModel *)message {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionTableName = [DBTOOL getSessionTableNameWith:message];
    BOOL result = [DBTOOL backDeleteChatMessageWith:message tableName:sessionTableName];
    //撤回消息，会有撤回提醒，相当于更新了最新消息，所以不存在最新消息删除的那种情况
    
    //如果撤回的是我未读的消息
    NSString *sessionID = [DBTOOL getSessionIDWith:message];
    if (!message.chatMessageReaded && ![message.fromID isEqualToString:[self myUserID]]) {
        LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
        if (sessionModel.sessionUnreadCount > 0) {
            sessionModel.sessionUnreadCount--;
        }else {
            sessionModel.sessionUnreadCount = 0;
        }
        [IMSDKManager toolUpdateSessionWith:sessionModel];
    } else {
        LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
        if (sessionModel) {
            [IMSDKManager toolUpdateSessionWith:sessionModel];
        }
    }
    
    return result;
}
#pragma mark - 根据会话ID删除全部聊天数据
- (BOOL)toolDeleteAllChatMessageWith:(NSString *)sessionID {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    BOOL result = [DBTOOL deleteAllChatMessageWith:sessionTableName];
    if (result) {
        LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
        sessionModel.sessionLatestMessage = nil;
        sessionModel.sessionLatestServerMsgID = nil;
        sessionModel.sessionUnreadCount = 0;
        [IMSDKManager toolUpdateSessionWith:sessionModel];
        
        //告知UI 数据清空
        [self.messageDelegate cimToolMessageDeleteAll:sessionID];
    }
    return result;
}

#pragma mark - 根据某个消息ID获取消息
- (NoaIMChatMessageModel *)toolGetOneChatMessageWithMessageID:(NSString *)msgID sessionID:(NSString *)sessionID {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return [DBTOOL getOneChatMessageWithMessageID:msgID withTableName:sessionTableName];
}

#pragma mark - 根据某个服务端消息ID获取消息
- (NoaIMChatMessageModel *)toolGetOneChatMessageWithServiceMessageID:(NSString *)smsgID sessionID:(NSString *)sessionID {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return [DBTOOL getOneChatMessageWithServiceMessageID:smsgID withTableName:sessionTableName];
}
#pragma mark - 根据某个服务端消息ID获取消息（排除删除和撤回的消息）
- (NoaIMChatMessageModel *)toolGetOneChatMessageWithServiceMessageIDExcludeDeleted:(NSString *)smsgID sessionID:(NSString *)sessionID {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return [DBTOOL getOneChatMessageWithServiceMessageIDExcludeDeleted:smsgID withTableName:sessionTableName];
}


#pragma mark - 获取某个会话的最新消息
- (NoaIMChatMessageModel *)toolGetLatestChatMessageWithSessionID:(NSString *)sessionID {
    //表名称 CIMDB_myUserID_toUserID_Table
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return [DBTOOL getLatestChatMessageWithTableName:sessionTableName];
}

#pragma mark - 删除某个群的群成员在本群发的所有消息
- (BOOL)toolDeleteGroupMemberAllSendMessageWith:(NSString *)memberID groupID:(nonnull NSString *)groupID {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID], groupID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return [DBTOOL deleteGroupMemberAllSendChatMessageWith:sessionTableName withMemberId:memberID];
}

#pragma mark - 消息已读
- (BOOL)toolMessageHaveReadWith:(NoaIMChatMessageModel *)message {
    
    message.chatMessageReaded = YES;
    //更新消息和会话
    BOOL result = [IMSDKManager toolInsertOrUpdateChatMessageWith:message];
    if (result) {
        NSString *sessionID = [DBTOOL getSessionIDWith:message];
        LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
        sessionModel.sessionUnreadCount = 0;
        [IMSDKManager toolUpdateSessionWith:sessionModel];
    }
    return result;
}
#pragma mark - 消息全部已读
- (BOOL)toolMessageHaveReadAllWith:(NSString *)sessionID {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    BOOL result = [DBTOOL messageHaveReadAllWith:sessionTableName];
    if (result) {
        LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:sessionID];
        sessionModel.sessionUnreadCount = 0;
        sessionModel.readTag = 0;
        [IMSDKManager toolUpdateSessionWith:sessionModel];
    }
    return result;
}

#pragma mark - 删除某会话的某个时间之前的全部消息
- (BOOL)toolMessageDeleteBeforTime:(long long)timeValue withSessionID:(NSString *)sessionID {
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return [DBTOOL messageDeleteBeforTime:timeValue withTableName:sessionTableName];
}

#pragma mark - 发送MMKV里未发送成功的消息
- (void)toolMMKVSendChatMessage {
    
    NSLog(@"========== toolMMKVSendChatMessage");
    NSArray *chatList = [MMKVTOOL getAllSendChatMessage];
    [chatList enumerateObjectsUsingBlock:^(IMChatMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NoaIMChatMessageModel *sendChatMessage = [[LingIMModelTool sharedTool] getChatMessageModelFromIMChatMessage:obj];
        [IMSDKManager toolSendChatMessageWith:sendChatMessage];
    }];
}

#pragma mark - 根据搜索内容查询群组数据
- (NSArray <NoaIMChatMessageModel *> *)toolSearchMessageWith:(NSString *)searchStr {
    return [DBTOOL searchChatMessageWith:searchStr];
}

#pragma mark - <<<<<<私有方法>>>>>>
#pragma mark - 消息双向删除，数据库处理
- (void)toolChatMessageDeleteBothwayWith:(NoaIMChatMessageModel *)chatMessage {
    NSString *sessionID;
    if (chatMessage.chatType == CIMChatType_SingleChat) {
        //单聊
        if ([chatMessage.fromID isEqualToString:[self myUserID]]) {
            //我发出的消息
            sessionID = chatMessage.toID;
        }else {
            //对方发出的消息
            sessionID = chatMessage.fromID;
        }
    } else if (chatMessage.chatType == CIMChatType_GroupChat) {
        //群聊
        sessionID = chatMessage.toID;
    } else {
        CIMLog(@"AAA消息解析未实现的chatType类型:%ld",chatMessage.chatType);
    }
    
    //找到需要删除的消息
    NoaIMChatMessageModel *deleteModel = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
    //删除消息
    [IMSDKManager toolDeleteChatMessageWith:deleteModel];
    
    //更新到UI层，界面刷新
    [self.messageDelegate cimToolChatMessageReceive:chatMessage];
    
}
#pragma mark - 消息撤回，数据库处理
- (void)toolChatMessageDeleteBackWith:(NoaIMChatMessageModel *)chatMessage{
    NSString *sessionID;
    if (chatMessage.chatType == CIMChatType_SingleChat) {
        //单聊
        if ([chatMessage.fromID isEqualToString:[self myUserID]]) {
            //我发出的消息
            sessionID = chatMessage.toID;
        }else {
            //对方发出的消息
            sessionID = chatMessage.fromID;
        }
    }else if (chatMessage.chatType == CIMChatType_GroupChat) {
        //群聊
        sessionID = chatMessage.toID;
    }else {
        CIMLog(@"BBB消息解析未实现的chatType类型:%ld",chatMessage.chatType);
    }
    
    //找到需要撤销删除的消息
    NoaIMChatMessageModel *deleteModel = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
    //撤销消息
    [IMSDKManager toolBackDeleteChatMessageWith:deleteModel];
    
}


#pragma mark - <<<<<<网络接口请求>>>>>>
#pragma mark - 获取在服务器保存的会话列表
- (void)getConversationsFromServer:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageGetConversationsFromServer:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 删除服务器端某个会话
- (void)deleteServerConversation:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        [[NoaIMHttpManager sharedManager] MessageDeleteServerConversation:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 指定会话的已读回执
- (void)ackConversationRead:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageAckConversationRead:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 会话-群聊 消息免打扰
- (void)groupConversationPromt:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageGroupConversationPromt:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //操作成功
            NSInteger resultStatus = [[params objectForKey:@"status"] integerValue];//0关闭消息免打扰，1开启消息免打扰
            
            //更新会话免打扰状态
            NSString *sessionID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群组ID为会话ID
            
            //更新 群组的会话 免打扰状态
            LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:sessionID];
            sessionModel.sessionNoDisturb = resultStatus == 1 ? YES : NO;
            [self toolUpdateSessionWith:sessionModel];
            
            //更新 群组 免打扰状态
            LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:sessionID];
            groupModel.msgNoPromt = resultStatus == 1 ? YES : NO;
            [self toolInsertOrUpdateGroupModelWith:groupModel];
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
            
        }
        
    } onFailure:onFailure];
}

#pragma mark - 会话-群聊 置顶
- (void)groupConversationTop:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageGroupConversationTop:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //操作成功
            NSInteger resultStatus = [[params objectForKey:@"status"] integerValue];//0取消置顶，1设置置顶
            
            //更新会话置顶状态
            NSString *sessionID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群组ID为会话ID
            
            //更新 群组的会话 置顶状态
            LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:sessionID];
            sessionModel.sessionTop = resultStatus == 1 ? YES : NO;
            if (sessionModel.sessionTop) {
                //毫秒
                NSDate *date = [NSDate date];
                long long time = [date timeIntervalSince1970] * 1000;
                sessionModel.sessionTopTime = time;
            }else {
                sessionModel.sessionTopTime = 0;
            }
            [self toolUpdateSessionWith:sessionModel];
            
            //更新 群组 置顶状态
            LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:sessionID];
            groupModel.msgTop = resultStatus == 1 ? YES : NO;
            [self toolInsertOrUpdateGroupModelWith:groupModel];
            //代理到UI层
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
        }
        
    } onFailure:onFailure];
    
}

#pragma mark - 会话-单聊 消息免打扰
- (void)singleConversationPromt:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        [[NoaIMHttpManager sharedManager] MessageSingleConversationPromt:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            if (onSuccess) {
                onSuccess(data, traceId);
            }
            
            BOOL dataResult = [data boolValue];
            if (dataResult) {
                //操作成功
                NSInteger resultStatus = [[params objectForKey:@"status"] integerValue];//0关闭消息免打扰，1开启消息免打扰
                
                NSString *sessionID = [NSString stringWithFormat:@"%@", [params objectForKey:@"friendUserUid"]];//好友ID为会话ID
                
                //更新 好友的会话 免打扰状态
                LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:sessionID];
                sessionModel.sessionNoDisturb = resultStatus == 1 ? YES : NO;
                [self toolUpdateSessionWith:sessionModel];
                
                //更新 好友 免打扰状态
                LingIMFriendModel *friendModel = [self toolCheckMyFriendWith:sessionID];
                friendModel.msgNoPromt = resultStatus == 1 ? YES : NO;
                [self toolUpdateMyFriendWith:friendModel];
            }
            
            
        } onFailure:onFailure];
    }
    
    //    [[NoaIMHttpManager sharedManager] MessageSingleConversationPromt:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 会话-单聊 置顶
- (void)singleConversationTop:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageSingleConversationTop:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //操作成功
            
            NSInteger resultStatus = [[params objectForKey:@"status"] integerValue];//0取消置顶，1设为置顶
            
            NSString *sessionID = [NSString stringWithFormat:@"%@", [params objectForKey:@"friendUserUid"]];//好友ID为会话ID
            
            //更新 好友的会话 置顶状态
            LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:sessionID];
            if (sessionModel) {
                sessionModel.sessionTop = resultStatus == 1 ? YES : NO;
                if (sessionModel.sessionTop) {
                    //毫秒
                    NSDate *date = [NSDate date];
                    long long time = [date timeIntervalSince1970] * 1000;
                    sessionModel.sessionTopTime = time;
                }else {
                    sessionModel.sessionTopTime = 0;
                }
                [self toolUpdateSessionWith:sessionModel];
            }
            
            //更新 好友 置顶状态
            LingIMFriendModel *friendModel = [self toolCheckMyFriendWith:sessionID];
            if (friendModel) {
                friendModel.msgTop = resultStatus == 1 ? YES : NO;
                [self toolUpdateMyFriendWith:friendModel];
            }
            
            
        }
        
    } onFailure:onFailure];
}

#pragma mark - 会话- 标记未读/标记已读
- (void)conversationReadedStatus:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageConversationReadedStatus:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 清空单聊的聊天记录
- (void)clearChatMessageHistory:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageClearChatMessageHistory:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        if (data) {
            //清空 单聊/群聊 聊天记录成功
            NSString *sessionID = [NSString stringWithFormat:@"%@", [params objectForKey:@"receiveId"]];
            //删除好友相关的聊天记录
            [self toolDeleteAllChatMessageWith:sessionID];
        }
        
    } onFailure:onFailure];
}

#pragma mark - 查询 单聊 消息记录
- (void)querySingleMsgRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageQuerySingleMsgRecord:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询 群聊 消息记录
- (void)queryGroupMsgRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageQueryGroupMsgRecord:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询 通知 离线消息记录
- (void)queryOfflineMsgRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageQueryOfflineMsgRecord:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 消息转发
- (void)transpondMessage:(NSData *)messageData onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageTranspondMessage:messageData onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 消息转发-校验接受者
- (void)transpondComplianceMessage:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageTranspondComplianceMessage:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 消息删除(单向/双向)
- (void)deleteMessage:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageDeleteMessage:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 消息撤回
- (void)recallMessage:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageRecallMessage:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 发送消息已读
- (void)readedMessage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageReadedMessage:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取多个群聊会话的最新消息
- (void)messageGetLatestForGroupSessionsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageGetGroupSessionsLatestMessages:params onSuccess:onSuccess onFailure:onFailure];
    
}

#pragma mark - 获取多个单聊会话的最新消息
- (void)messageGetLatestForSingleSessionsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageGetSingleSessionsLatestMessages:params onSuccess:onSuccess onFailure:onFailure];
    
}

#pragma mark - 重连后获取聊天消息历史记录
/// messageId: 本地最新消息的 serviceMsgID（优先）或 msgID；用于拉取「比它更新」的缺口
/// lastMessageId: 兼容旧参数，当前游标补缺场景可传最旧 serviceMsgID（可选）
- (void)messageReConnectGetHistoryRecordWith:(NSString *)sessionID chatType:(CIMChatType)chatType lastMessageId:(NSString *)lastMessageId messageId:(NSString *)messageId offset:(NSInteger)offset historyList:(LingIMReConnectMessageHistoryBlock)block {
    int pageNum = 1;
    // 重连补缺：按 serviceMsgID 游标拉更新消息（isThanMsgId=2），避免纯 pageNumber 把旧页灌进当前会话
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(kPageNumber) forKey:@"pageSize"];
    [dict setValue:@(1) forKey:@"pageNumber"];
    [dict setValue:[self myUserID] forKey:@"userUid"];
    NSString *cursorSid = messageId ?: @"";
    if (cursorSid.length > 0) {
        [dict setValue:cursorSid forKey:@"sMsgId"];
        [dict setValue:@(2) forKey:@"isThanMsgId"]; // 大于 cursor 的更新消息
    }
    CIMLog(@"[MsgTime] reconnect gap-fill session=%@ chatType=%ld cursor=%@ oldest=%@", sessionID, (long)chatType, cursorSid, lastMessageId ?: @"");
    if (chatType == CIMChatType_SingleChat) {
        [dict setValue:sessionID forKey:@"fromUid"];
        [self messageSingleChatHistory:dict pageNum:pageNum limit:0 sessionId:sessionID lastMessageId:lastMessageId messageId:messageId isContinue:NO onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            NSNumber *limit = (NSNumber *)data;
            NSInteger fetchLimit = MAX(limit.integerValue, kPageNumber);
            NSArray *historyList = [IMSDKManager toolReConnectGetChatMessageHistoryWith:sessionID limit:fetchLimit offset:offset];
            if (block) {
                block(historyList, offset);
            }
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
            NSArray *historyList = [IMSDKManager toolReConnectGetChatMessageHistoryWith:sessionID limit:kPageNumber offset:offset];
            if (block) {
                block(historyList, offset);
            }
        }];
    } else if (chatType == CIMChatType_GroupChat) {
        [dict setValue:sessionID forKey:@"groupId"];
        [self messageGroupChatHistory:dict pageNum:pageNum limit:0 sessionId:sessionID lastMessageId:lastMessageId messageId:messageId isContinue:NO onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            NSNumber *limit = (NSNumber *)data;
            NSInteger fetchLimit = MAX(limit.integerValue, kPageNumber);
            NSArray *historyList = [IMSDKManager toolReConnectGetChatMessageHistoryWith:sessionID limit:fetchLimit offset:offset];
            if (block) {
                block(historyList, offset);
            }
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
            NSArray *historyList = [IMSDKManager toolReConnectGetChatMessageHistoryWith:sessionID limit:kPageNumber offset:offset];
            if (block) {
                block(historyList, offset);
            }
        }];
    } else {
        CIMLog(@"CCC消息解析未实现的chatType类型:%ld",chatType);
    }
}

/// 重连补缺：把一页历史写入 DB（含本地字段保护）
- (NSString *)lim_upsertReconnectHistoryRows:(NSArray *)rowList sessionID:(NSString *)sessionID {
    NSString *lastSid = @"";
    for (NSDictionary *obj in rowList) {
        NoaChatMessageModel *model = [NoaChatMessageModel mj_objectWithKeyValues:obj];
        NoaIMChatMessageModel *chatMessage = [model getChatMessageFromMessageRecordModel];
        if (chatMessage.serviceMsgID.length > 0) {
            lastSid = chatMessage.serviceMsgID;
        }
        if (chatMessage.messageType == CIMChatMessageType_BilateralDel) {
            NoaIMChatMessageModel *chatMessageBilateralDel = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
            if (chatMessageBilateralDel.messageStatus != 0 && chatMessageBilateralDel) {
                chatMessageBilateralDel.messageStatus = 0;
                [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessageBilateralDel];
            }
        } else if (chatMessage.messageType == CIMChatMessageType_BackMessage) {
            NoaIMChatMessageModel *chatMessageBack = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
            if (chatMessageBack && chatMessageBack.messageStatus != 2) {
                chatMessageBack.messageStatus = 2;
                [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessageBack];
            }
            if (chatMessage.chatType != CIMChatType_GroupChat || chatMessage.backDelInformSwitch != 2) {
                [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
            }
        } else {
            NoaIMChatMessageModel *localChatMesaage = [IMSDKManager toolGetOneChatMessageWithMessageID:chatMessage.msgID sessionID:sessionID];
            if (localChatMesaage == nil) {
                if (!(chatMessage.messageType == CIMChatMessageType_TextMessage && chatMessage.textContent.length <= 0)) {
                    [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                }
            } else {
                long long before = localChatMesaage.sendTime;
                LIMMergeLocalFieldsBeforeHistoryUpsert(chatMessage, localChatMesaage);
                if (before != chatMessage.sendTime) {
                    CIMLog(@"[MsgTime] historyOverwrite msgId=%@ local=%lld server=%lld used=%lld", chatMessage.msgID, before, model.sendTime, chatMessage.sendTime);
                }
                [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
            }
        }
    }
    return lastSid;
}

- (void)messageSingleChatHistory:(NSMutableDictionary *)dict pageNum:(int)pageNum limit:(int)limit sessionId: (NSString *)sessionID lastMessageId:(NSString *)lastMessageId messageId:(NSString *)messageId isContinue:(BOOL)isContinue onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    __block int num = pageNum;
    __block int lim = limit;
    // 游标补缺时 pageNumber 固定为 1，靠 sMsgId 前移
    [dict setValue:@(1) forKey:@"pageNumber"];
    [[NoaIMSDKManager sharedTool] querySingleMsgRecord:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (![data isKindOfClass:[NSDictionary class]]) {
            if (onSuccess) { onSuccess(@(lim), traceId); }
            return;
        }
        NSArray *rowList = [(NSDictionary *)data objectForKey:@"rows"];
        if (rowList.count <= 0) {
            if (onSuccess) { onSuccess(@(lim), traceId); }
            return;
        }
        NSString *nextCursor = [self lim_upsertReconnectHistoryRows:rowList sessionID:sessionID];
        lim += (int)rowList.count;
        // 本页未满或无新游标 / 达到上限：结束
        if (rowList.count < kPageNumber || nextCursor.length == 0 || num >= 5) {
            if (onSuccess) { onSuccess(@(lim), traceId); }
            return;
        }
        [dict setValue:nextCursor forKey:@"sMsgId"];
        [dict setValue:@(2) forKey:@"isThanMsgId"];
        [self messageSingleChatHistory:dict pageNum:num + 1 limit:lim sessionId:sessionID lastMessageId:lastMessageId messageId:messageId isContinue:YES onSuccess:onSuccess onFailure:onFailure];
    } onFailure:onFailure];
}

- (void)messageGroupChatHistory:(NSMutableDictionary *)dict pageNum:(int)pageNum limit:(int)limit sessionId: (NSString *)sessionID lastMessageId:(NSString *)lastMessageId messageId:(NSString *)messageId isContinue:(BOOL)isContinue onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    __block int num = pageNum;
    __block int lim = limit;
    [dict setValue:@(1) forKey:@"pageNumber"];
    [[NoaIMSDKManager sharedTool] queryGroupMsgRecord:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (![data isKindOfClass:[NSDictionary class]]) {
            if (onSuccess) { onSuccess(@(lim), traceId); }
            return;
        }
        NSArray *rowList = [(NSDictionary *)data objectForKey:@"rows"];
        if (rowList.count <= 0) {
            if (onSuccess) { onSuccess(@(lim), traceId); }
            return;
        }
        NSString *nextCursor = [self lim_upsertReconnectHistoryRows:rowList sessionID:sessionID];
        lim += (int)rowList.count;
        if (rowList.count < kPageNumber || nextCursor.length == 0 || num >= 5) {
            if (onSuccess) { onSuccess(@(lim), traceId); }
            return;
        }
        [dict setValue:nextCursor forKey:@"sMsgId"];
        [dict setValue:@(2) forKey:@"isThanMsgId"];
        [self messageGroupChatHistory:dict pageNum:num + 1 limit:lim sessionId:sessionID lastMessageId:lastMessageId messageId:messageId isContinue:YES onSuccess:onSuccess onFailure:onFailure];
    } onFailure:onFailure];
}

#pragma mark - 获取聊天消息历史记录
- (void)messageGetHistoryRecordWith:(NSString *)sessionID chatType:(CIMChatType)chatType serviceMsgID:(NSString *)serviceMsgID offset:(NSInteger)offset pageNum:(NSInteger)pageNum historyList:(LingIMChatMessageHistoryBlock)block {
    //优先展示本地数据库消息，可提高用户体验
    
    if (serviceMsgID.length > 0) {
        // 上拉更旧：使用 sMsgId 游标 + isThanMsgId=1，避免纯 pageNumber 漂移
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@(kPageNumber) forKey:@"pageSize"];
        [dict setValue:@(1) forKey:@"pageNumber"];
        [dict setValue:serviceMsgID forKey:@"sMsgId"];
        [dict setValue:@(1) forKey:@"isThanMsgId"]; // 小于 cursor 的更旧消息
        [dict setValue:[self myUserID] forKey:@"userUid"];
        CIMLog(@"[MsgTime] history pull older session=%@ cursor=%@ offset=%ld", sessionID, serviceMsgID, (long)offset);

        void (^finishWithDB)(NSInteger nextPage) = ^(NSInteger nextPage) {
            NSArray *historyList = [IMSDKManager toolGetChatMessageHistoryWith:sessionID offset:offset];
            if (block) {
                block(historyList, offset, NO, nextPage);
            }
        };

        if (chatType == CIMChatType_SingleChat) {
            [dict setValue:sessionID forKey:@"fromUid"];
            [[NoaIMSDKManager sharedTool] querySingleMsgRecord:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
                if ([data isKindOfClass:[NSDictionary class]]) {
                    NSArray *rowList = [(NSDictionary *)data objectForKey:@"rows"] ?: @[];
                    [self lim_upsertReconnectHistoryRows:rowList sessionID:sessionID];
                }
                finishWithDB(pageNum + 1);
            } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                finishWithDB(pageNum);
            }];
        } else if (chatType == CIMChatType_GroupChat) {
            [dict setValue:sessionID forKey:@"groupId"];
            [[NoaIMSDKManager sharedTool] queryGroupMsgRecord:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
                if ([data isKindOfClass:[NSDictionary class]]) {
                    NSArray *rowList = [(NSDictionary *)data objectForKey:@"rows"] ?: @[];
                    if (rowList.count <= 0) {
                        if (block) {
                            block(@[], offset, NO, pageNum);
                        }
                        return;
                    }
                    [self lim_upsertReconnectHistoryRows:rowList sessionID:sessionID];
                }
                finishWithDB(pageNum + 1);
            } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                finishWithDB(pageNum);
            }];
        } else {
            CIMLog(@"CCC消息解析未实现的chatType类型:%ld",chatType);
        }
        
    } else {
        //1.先展示本地数据库消息内容
        NSArray *historyList = [IMSDKManager toolGetChatMessageHistoryWith:sessionID offset:offset];
        if (block) {
            block(historyList, offset, YES, pageNum);
        }
        
        //2.更新服务端第一页到 DB；仅当补到本地没有的消息时才回调 UI，避免整表刷新把旧消息「突然」插进当前会话
        NSMutableSet *localIdSet = [NSMutableSet set];
        for (NoaIMChatMessageModel *localMsg in historyList) {
            if (localMsg.msgID.length > 0) {
                [localIdSet addObject:localMsg.msgID];
            }
            if (localMsg.serviceMsgID.length > 0) {
                [localIdSet addObject:localMsg.serviceMsgID];
            }
        }
        [self messageRequestHistoryRecordWith:sessionID chatType:chatType currentHistoryList:historyList pageNumber:1 newHistoryList:^(NSArray<NoaIMChatMessageModel *> * _Nullable chatMessageHistory, NSInteger syncOffset, BOOL isLocal, NSInteger pageNumber) {
            if (!block || chatMessageHistory.count == 0) {
                return;
            }
            BOOL hasNewMessage = NO;
            for (NoaIMChatMessageModel *msg in chatMessageHistory) {
                BOOL knownMsg = (msg.msgID.length > 0 && [localIdSet containsObject:msg.msgID]);
                BOOL knownSid = (msg.serviceMsgID.length > 0 && [localIdSet containsObject:msg.serviceMsgID]);
                if (!knownMsg && !knownSid) {
                    hasNewMessage = YES;
                    break;
                }
            }
            if (hasNewMessage) {
                block(chatMessageHistory, 0, NO, pageNumber);
            }
        }];
    }
}

#pragma mark - 仅用于更新会话的第一页消息
- (void)messageRequestHistoryRecordWith:(NSString *)sessionID chatType:(CIMChatType)chatType currentHistoryList:(NSArray *)historyList pageNumber:(NSInteger)pageNumber newHistoryList:(LingIMChatMessageHistoryBlock)block {
    
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@(kPageNumber) forKey:@"pageSize"];//每页返回数据个数
    [dict setValue:@(pageNumber) forKey:@"pageNumber"];//分页
    //[dict setValue:@"" forKey:@"sMsgId"];//服务端消息ID(如查询某条消息后多少条消息,则传该值。如查询最新消息,则不用传该值
//    [dict setValue:@(1) forKey:@"isThanMsgId"];//是否查询小于传入的消息ID的消息记录 1:是 2:否
    [dict setValue:[self myUserID] forKey:@"userUid"];//当前用户uid
    
    __block BOOL isChecked = NO;
    
    if (chatType == CIMChatType_SingleChat) {
        //单聊
        [dict setValue:sessionID forKey:@"fromUid"];
        
        [[NoaIMSDKManager sharedTool] querySingleMsgRecord:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            
            if ([data isKindOfClass:[NSDictionary class]]) {
                
                NSDictionary *dataDict = (NSDictionary *)data;
                
                NSArray *rowList = [dataDict objectForKey:@"rows"];
                if (rowList.count <= 0) {
                    if (block) {
                        block(@[], 0, NO, pageNumber);
                    }
                    return;
                }
                
                [rowList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    
                    NoaChatMessageModel *model = [NoaChatMessageModel mj_objectWithKeyValues:obj];
                    NoaIMChatMessageModel *chatMessage = [model getChatMessageFromMessageRecordModel];
                    
                    //15双向删除消息 不存数据库，进行数据库检测，将被双向删除的消息状态置为0
                    if (chatMessage.messageType == CIMChatMessageType_BilateralDel) {
                        
                        //找到需要双向删除的消息
                        NoaIMChatMessageModel *chatMessageBilateralDel = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
                        if (chatMessageBilateralDel.messageStatus != 0 && chatMessageBilateralDel) {
                            chatMessageBilateralDel.messageStatus = 0;
                            //更新数据库
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessageBilateralDel];
                        }
                        
                    } else if (chatMessage.messageType == CIMChatMessageType_BackMessage) {
                        //8撤回消息 存数据库，并进行数据库检测，将撤回消息状态置为2
                        //找到需要撤销删除的消息
                        NoaIMChatMessageModel *chatMessageBack = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
                        if (chatMessageBack && chatMessageBack.messageStatus != 2) {
                            chatMessageBack.messageStatus = 2;
                            //更新数据库
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessageBack];
                        }
                
                        //更新数据库 撤回消息提示
                        [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                    } else {
                        //重复消息去重
                        NoaIMChatMessageModel *localChatMesaage = [IMSDKManager toolGetOneChatMessageWithMessageID:chatMessage.msgID sessionID:sessionID];
                        if (localChatMesaage == nil) {
                            if (chatMessage.messageType == CIMChatMessageType_TextMessage && chatMessage.textContent.length <= 0) {
                                //过滤掉打招呼的空白消息
                            } else {
                                //更新数据库 聊天消息 + 撤回消息提示
                                BOOL saveResult = [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                                if (saveResult) {
                                    //CIMLog(@"消息更新成功");
                                }else {
                                    //CIMLog(@"消息更新失败");
                                }
                            }
                        } else {
                            LIMMergeLocalFieldsBeforeHistoryUpsert(chatMessage, localChatMesaage);
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                        }
                    }
                    
                    if (isChecked == NO && chatMessage.messageStatus == 1) {
                        LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
                        sessionModel.sessionLatestTime = chatMessage.sendTime;
                        sessionModel.sessionLatestMessage = chatMessage;
                        sessionModel.sessionLatestServerMsgID = chatMessage.serviceMsgID;
                        [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                        [weakSelf.sessionDelegate cimToolSessionUpdateWith:sessionModel];
                        isChecked = YES;
                    }
                    //已执行完毕遍历（仅同步第一页，不再递归翻页，避免把更旧消息灌进当前会话刷新）
                    if (idx == rowList.count - 1) {
                        NSArray *historyList = [IMSDKManager toolGetChatMessageHistoryWith:sessionID offset:0];
                        if (block) {
                            block(historyList, 0, NO, pageNumber+1);
                        }
                    }
                }];
            }
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
            
            if (block) {
                block(@[] , 0, NO, pageNumber);
            }
            
        }];
    }else if (chatType == CIMChatType_GroupChat){

        [dict setValue:sessionID forKey:@"groupId"];
        
        [[NoaIMSDKManager sharedTool] queryGroupMsgRecord:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            
            if ([data isKindOfClass:[NSDictionary class]]) {
                
                NSDictionary *dataDict = (NSDictionary *)data;
                
                NSArray *rowList = [dataDict objectForKey:@"rows"];
                if (rowList.count <= 0) {
                    if (block) {
                        block(@[], 0, NO, pageNumber);
                    }
                    return;
                }
                
                [rowList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    
                    NoaChatMessageModel *model = [NoaChatMessageModel mj_objectWithKeyValues:obj];
                    NoaIMChatMessageModel *chatMessage = [model getChatMessageFromMessageRecordModel];
                    
                    //15双向删除消息 不存数据库，进行数据库检测，将被双向删除的消息状态置为0
                    if (chatMessage.messageType == CIMChatMessageType_BilateralDel) {
                        
                        //找到需要双向删除的消息
                        NoaIMChatMessageModel *chatMessageBilateralDel = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
                        if (chatMessageBilateralDel.messageStatus != 0 && chatMessageBilateralDel) {
                            chatMessageBilateralDel.messageStatus = 0;
                            //更新数据库
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessageBilateralDel];
                        }
                        
                    } else if (chatMessage.messageType == CIMChatMessageType_BackMessage) {
                        //8撤回消息 存数据库，并进行数据库检测，将撤回消息状态置为2
                        //找到需要撤销删除的消息
                        NoaIMChatMessageModel *chatMessageBack = [IMSDKManager toolGetOneChatMessageWithServiceMessageID:chatMessage.backDelServiceMsgID sessionID:sessionID];
                        if (chatMessageBack && chatMessageBack.messageStatus != 2) {
                            chatMessageBack.messageStatus = 2;
                            //更新数据库
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessageBack];
                        }
                        if (chatMessage.backDelInformSwitch != 2) {
                            //更新数据库 撤回消息提示
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                        }
                    } else {
                        //重复消息去重
                        NoaIMChatMessageModel *localChatMesaage = [IMSDKManager toolGetOneChatMessageWithMessageID:chatMessage.msgID sessionID:sessionID];
                        if (localChatMesaage == nil) {
                            if (chatMessage.messageType == CIMChatMessageType_TextMessage && chatMessage.textContent.length <= 0) {
                                //过滤掉打招呼的空白消息
                            } else {
                                //更新数据库 聊天消息 + 撤回消息提示
                                BOOL saveResult = [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                                if (saveResult) {
                                    //CIMLog(@"消息更新成功");
                                }else {
                                    //CIMLog(@"消息更新失败");
                                }
                            }
                        } else {
                            LIMMergeLocalFieldsBeforeHistoryUpsert(chatMessage, localChatMesaage);
                            [IMSDKManager toolInsertOrUpdateChatMessageWith:chatMessage];
                        }
                    }
                    
                    if (isChecked == NO && chatMessage.messageStatus == 1) {
                        LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
                        sessionModel.sessionLatestTime = chatMessage.sendTime;
                        sessionModel.sessionLatestMessage = chatMessage;
                        sessionModel.sessionLatestServerMsgID = chatMessage.serviceMsgID;
                        [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                        [weakSelf.sessionDelegate cimToolSessionUpdateWith:sessionModel];
                        isChecked = YES;
                    }
                    // 仅同步第一页：不再因本地不足 kPageNumber 继续翻旧页，防止旧消息被灌入当前会话 UI
                    if (idx == rowList.count - 1) {
                        NSArray *syncedHistoryList = [IMSDKManager toolGetChatMessageHistoryWith:sessionID offset:0];
                        if (block) {
                            block(syncedHistoryList, 0, NO, pageNumber + 1);
                        }
                    }
                }];
            }
            
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
            if (block) {
                block(@[] , 0, NO, pageNumber);
            }
            
        }];
        
    }else {
        CIMLog(@"DDD消息解析未实现的chatType类型:%ld",chatType);
    }
}

#pragma mark - 获取聊天消息历史记录
- (NSArray *)messageGetSignInHistoryRecordWith:(NSString *)sessionID offset:(NSInteger)offset {
    
    NSArray *historyList = [IMSDKManager toolGetSignInHistoryWith:sessionID offset:offset];
    return historyList;
}

#pragma mark - 推荐好友名片
- (void)MessageUserCardRecommend:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageRecommentFriendCard:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询 定时删除消息 功能的 设置信息
- (void)MessageTimeDeleteInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageTimeDeleteInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 设置 定时删除消息 功能
- (void)MessageTimeDeleteSetWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageTimeDeleteSetWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 添加消息到 "我的收藏"
- (void)MessageCollectionSave:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] MessageSaveCollectionWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群发助手-创建消息转发组
- (void)GroupHairCreateHairGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] GroupHairCreateHairGroupWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群发助手-发送群发消息
- (void)GroupHairSendHairMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] GroupHairSendHairMessageWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群发助手-获取群发消息列表
- (void)GroupHairGetMessageListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] GroupHairGetMessageListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群发助手-删除群发消息
- (void)GroupHairDeleteHairMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] GroupHairDeleteHairMessageWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群发助手-查询群发消息的成员列表
- (void)GroupHairGetGroupHairUserListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] GroupHairGetGroupHairUserListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群发助手-查询群发消息的发送失败成员列表
- (void)GroupHairGetGroupHairErrorUserListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] GroupHairGetGroupHairErrorUserListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 聊天标签-获取标签链接信息
- (void)MessageChatTagListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageGetChatTagListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 聊天标签-新增标签链接信息
- (void)MessageChatTagAddWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageAddChatTagWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 聊天标签-更新标签链接信息
- (void)MessageChatTagUpdateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageUpdateChatTagWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 聊天标签-移除标签链接信息
- (void)MessageChatTagRemoveWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageRemoveChatTagWith:params onSuccess:onSuccess onFailure:onFailure];
    
}

#pragma mark - 全部已读上报
- (void)MessageReadAllMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageReadAllMessageWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 长链接失败后发送消息接口
- (void)MessagePushMsg:(NSData * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessagePushMsg:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 查询群置顶消息列表
- (void)MessageQueryGroupTopMsgListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageQueryGroupTopMsgListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询群消息是否可以置顶
- (void)MessageQueryGroupMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageQueryGroupMsgStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询群置顶消息悬浮列表
- (void)MessageQueryGroupTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageQueryGroupTopMsgsWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询个人消息是否可以置顶
- (void)MessageQueryUserMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageQueryUserMsgStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 设置/取消 消息置顶
- (void)MessageSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageSetMsgTopWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询个人置顶消息列表
- (void)MessageQueryUserTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] MessageQueryUserTopMsgsWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 编辑已发送消息
- (void)editMessage:(NSData *)messageData onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    // SDK 只负责透传编辑消息体，业务侧在成功回调后更新本地展示。
    [[NoaIMHttpManager sharedManager] MessageEditOneMsgWith:messageData onSuccess:onSuccess onFailure:onFailure];
}

@end
