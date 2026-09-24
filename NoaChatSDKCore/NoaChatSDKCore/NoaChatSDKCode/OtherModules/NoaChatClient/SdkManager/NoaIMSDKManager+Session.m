//
//  NoaIMSDKManager+Session.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/27.
//

#import "NoaIMSDKManager+Session.h"
// 统一的签到助手会话ID（避免重复会话）
static NSString * const kSignInSessionID = @"SIGNIN_ASSISTANT";
#import "NoaIMSDKManager+User.h"//用户相关
#import "NoaIMSDKManager+Friend.h"//好友相关
#import "NoaIMSDKManager+Group.h"//群组相关
#import "NoaIMSDKManager+ChatMessage.h"//聊天相关
#import "NoaIMSDKManager+MessageRemind.h"//消息提醒相关



@implementation NoaIMSDKManager (Session)

#pragma mark - 新增/更新会话列表
- (BOOL)toolInsertOrUpdateSessionWith:(NoaIMChatMessageModel *)message isRemind:(BOOL)isRemind {
    
    //表名称 CIMDB_myUserID_toUserID_Table
    
    NSString *sessionID;//会话ID
    NSString *sessionName;//会话名称
    NSString *sessionAvatar;//会话头像
    NSInteger sessionType = CIMSessionTypeDefault;//会话类型
    NSInteger groupType = CIMGroupTypeDefault;//群聊类型
    
    if (message.chatType == CIMChatType_SingleChat) {
        //单聊消息
        sessionType = CIMSessionTypeSingle;
        
        if ([message.fromID isEqualToString:[IMSDKManager myUserID]]) {
            //我发的消息
            LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.toID];
            if (friendModel) {
                sessionID = friendModel.friendUserUID;
                sessionName = friendModel.nickname;
                sessionAvatar = friendModel.avatar;
            }else {
                //本地查询不到好友信息，调用接口查询
                [self privateGetFriendInfoWithReceiveMessage:message userUid:message.toID];
            }
        }else {
            //对方发的消息
            LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.fromID];
            if (friendModel) {
                sessionID = friendModel.friendUserUID;
                sessionName = friendModel.nickname;
                sessionAvatar = friendModel.avatar;
            }else {
                //本地查询不到好友信息，调用接口查询
                [self privateGetFriendInfoWithReceiveMessage:message userUid:message.fromID];
            }
        }
        
    }else if (message.chatType == CIMChatType_GroupChat) {
        //群聊信息
        sessionType = CIMSessionTypeGroup;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:message.toID];
        if (groupModel) {
            sessionID = groupModel.groupId;
            sessionName = groupModel.groupName;
            sessionAvatar = groupModel.groupAvatar;
        }else {
            //本地查询不到群聊信息，调用接口查询
            [self privateGetGroupInfoWithReceiveMessage:message groupID:message.toID];
        }
        
        if ([message.fromID isEqualToString:[IMSDKManager myUserID]]) {
            //我发的消息
        }else {
            //其他群成员发的消息
        }
        
    } else if (message.chatType == CIMChatType_SystemMessage) {
        //系统消息(群助手) 消息
        sessionType = CIMSessionTypeSystemMessage;
        
        //相当于 对方发送 的消息
        sessionID = message.fromID;
        sessionName = message.fromNickname;
        sessionAvatar = message.fromIcon;
    } else if (message.chatType == CIMChatType_PaymentAssistant) {
            //系统消息(支付通知) 消息
            sessionType = CIMSessionTypePaymentAssistant;
            
            //相当于 对方发送 的消息
            sessionID = message.fromID;
            sessionName = message.fromNickname;
            sessionAvatar = message.fromIcon;
    }else if (message.chatType == CIMChatType_NetCallChat) {
        //即构 音视频 消息
        
        if (message.netCallChatType == 1) {
            //单聊音视频
            sessionType = CIMSessionTypeSingle;
            
            if ([message.fromID isEqualToString:[self myUserID]]) {
                //我操作的音视频行为
                LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.toID];
                if (friendModel) {
                    sessionID = friendModel.friendUserUID;
                    sessionName = friendModel.nickname;
                    sessionAvatar = friendModel.avatar;
                }else {
                    //本地查询不到好友信息，调用接口查询
                    [self privateGetFriendInfoWithReceiveMessage:message userUid:message.toID];
                }
                
            }else {
                //别人操作的音视频行为
                LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.fromID];
                if (friendModel) {
                    sessionID = friendModel.friendUserUID;
                    sessionName = friendModel.nickname;
                    sessionAvatar = friendModel.avatar;
                }else {
                    //本地查询不到好友信息，调用接口查询
                    [self privateGetFriendInfoWithReceiveMessage:message userUid:message.fromID];
                }
            }
            
        }else if (message.netCallChatType == 2) {
            //群聊音视频
            sessionType = CIMSessionTypeGroup;
            
            LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:message.toID];
            if (groupModel) {
                sessionID = groupModel.groupId;
                sessionName = groupModel.groupName;
                sessionAvatar = groupModel.groupAvatar;
            }else {
                //本地查询不到群聊信息，调用接口查询
                [self privateGetGroupInfoWithReceiveMessage:message groupID:message.toID];
            }
            
        }
        
    } else if (message.chatType == CIMChatType_SignInReminder) {
        //系统消息(签到提醒)
        sessionType = CIMSessionTypeSignInReminder;
        
        // 统一映射为固定会话ID，避免因为不同来源字段导致重复会话
        sessionID = kSignInSessionID;
        sessionName = message.serverMessage.nick.length > 0 ? message.serverMessage.nick : @"签到助手";
        sessionAvatar = @"";
    } else {
        CIMLog(@"EEE消息解析未实现的chatType类型:%ld",message.chatType);
    }
    
    if (sessionID.length > 0) {
        //判断本地是否已有该会话
        LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
        
        if (sessionModel) {
            //本地已有该会话
            //1更新会话列表最新消息
            sessionModel.sessionLatestTime = message.sendTime;
            sessionModel.sessionStatus = 1;
            
            if (message.messageType == CIMChatMessageType_TextMessage && message.textContent.length <= 0) {
                //过滤掉打招呼的空白消息
                sessionModel.sessionLatestMessage = nil;
                sessionModel.sessionLatestServerMsgID = @"";
                sessionModel.sessionUnreadCount += 0;
                [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
            } else {
                sessionModel.sessionLatestMessage = message;
                sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
                if (isRemind) {
                    sessionModel.sessionUnreadCount += message.chatMessageReaded ? 0 : 1;
                }
                [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                //2更新会话表里聊天信息
                [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionModel.sessionTableName];
            }
            
            if (isRemind) {
                //3.更新未读消息总数
                NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
            }
            //4.更新到UI层
            [self.sessionDelegate cimToolSessionUpdateWith:sessionModel];
            
            return YES;
        }else {
            //本地没有该会话
            //存储消息的表名称
            NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
            CIMLog(@"sessionTableName = %@",sessionTableName);
            
            //1.创建某一会话表
            [DBTOOL createTableWithName:sessionTableName model:NoaIMChatMessageModel.class];
            
            //2.会话列表新增数据
            sessionModel = [LingIMSessionModel new];
            
            sessionModel.sessionID = sessionID;
            sessionModel.sessionName = sessionName;
            sessionModel.sessionAvatar = sessionAvatar;
            sessionModel.sessionType = sessionType;
            sessionModel.sessionGroupType = groupType;
            sessionModel.sessionTableName = sessionTableName;
            sessionModel.sessionLatestTime = message.sendTime;
            sessionModel.sessionStatus = 1;
            
            if (message.messageType == CIMChatMessageType_TextMessage && message.textContent.length <= 0) {
                //过滤掉打招呼的空白消息
                sessionModel.sessionLatestMessage = nil;
                sessionModel.sessionLatestServerMsgID = @"";
                sessionModel.sessionUnreadCount = 0;
                [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
            } else {
                sessionModel.sessionLatestMessage = message;
                sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
                if (isRemind) {
                    sessionModel.sessionUnreadCount = message.chatMessageReaded ? 0 : 1;
                }
                [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                //3.消息存储到表
                [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionTableName];
            }
            
            if (isRemind) {
                //4.更新未读消息总数
                NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
            }
            //5.更新到UI层
            [self.sessionDelegate cimToolSessionReceiveWith:sessionModel];
            
            return YES;
        }
        
    }
    
    return NO;
}

#pragma mark - 新增/更新会话列表(如果开启了 关闭群信息 ，则创建群时，只在会话列表里显示新会话，不显示创建群聊的邀请进群的系统消息)
- (BOOL)toolInsertSessionForCloseGroupRemindWith:(NoaIMChatMessageModel *)message {
    //表名称 CIMDB_myUserID_toUserID_Table
    
    NSString *sessionID;//会话ID
    NSString *sessionName;//会话名称
    NSString *sessionAvatar;//会话头像
    NSInteger sessionType = CIMSessionTypeDefault;//会话类型
    NSInteger groupType = CIMGroupTypeDefault;//群聊类型
    
    if (message.chatType == CIMChatType_SingleChat) {
        //单聊消息
        sessionType = CIMSessionTypeSingle;
        
        if ([message.fromID isEqualToString:[IMSDKManager myUserID]]) {
            //我发的消息
            LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.toID];
            if (friendModel) {
                sessionID = friendModel.friendUserUID;
                sessionName = friendModel.nickname;
                sessionAvatar = friendModel.avatar;
            }else {
                //本地查询不到好友信息，调用接口查询
                [self privateGetFriendInfoWithReceiveMessage:message userUid:message.toID];
            }
        }else {
            //对方发的消息
            LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.fromID];
            if (friendModel) {
                sessionID = friendModel.friendUserUID;
                sessionName = friendModel.nickname;
                sessionAvatar = friendModel.avatar;
            }else {
                //本地查询不到好友信息，调用接口查询
                [self privateGetFriendInfoWithReceiveMessage:message userUid:message.fromID];
            }
        }
        
    }else if (message.chatType == CIMChatType_GroupChat) {
        //群聊信息
        sessionType = CIMSessionTypeGroup;
        LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:message.toID];
        if (groupModel) {
            sessionID = groupModel.groupId;
            sessionName = groupModel.groupName;
            sessionAvatar = groupModel.groupAvatar;
        }else {
            //本地查询不到群聊信息，调用接口查询
            [self privateGetGroupInfoWithReceiveMessage:message groupID:message.toID];
        }
        
        if ([message.fromID isEqualToString:[IMSDKManager myUserID]]) {
            //我发的消息
        }else {
            //其他群成员发的消息
        }
        
    } else if (message.chatType == CIMChatType_SystemMessage) {
        //系统消息(群助手) 消息
        sessionType = CIMSessionTypeSystemMessage;
        
        //相当于 对方发送 的消息
        sessionID = message.fromID;
        sessionName = message.fromNickname;
        sessionAvatar = message.fromIcon;
    } else if (message.chatType == CIMChatType_PaymentAssistant) {
        //系统消息(支付通知) 消息
        sessionType = CIMSessionTypePaymentAssistant;
        
        //相当于 对方发送 的消息
        sessionID = message.fromID;
        sessionName = message.fromNickname;
        sessionAvatar = message.fromIcon;
    }else if (message.chatType == CIMChatType_NetCallChat) {
        //即构 音视频 消息
        
        if (message.netCallChatType == 1) {
            //单聊音视频
            sessionType = CIMSessionTypeSingle;
            
            if ([message.fromID isEqualToString:[self myUserID]]) {
                //我操作的音视频行为
                LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.toID];
                if (friendModel) {
                    sessionID = friendModel.friendUserUID;
                    sessionName = friendModel.nickname;
                    sessionAvatar = friendModel.avatar;
                }else {
                    //本地查询不到好友信息，调用接口查询
                    [self privateGetFriendInfoWithReceiveMessage:message userUid:message.toID];
                }
                
            }else {
                //别人操作的音视频行为
                LingIMFriendModel *friendModel = [IMSDKManager toolCheckMyFriendWith:message.fromID];
                if (friendModel) {
                    sessionID = friendModel.friendUserUID;
                    sessionName = friendModel.nickname;
                    sessionAvatar = friendModel.avatar;
                }else {
                    //本地查询不到好友信息，调用接口查询
                    [self privateGetFriendInfoWithReceiveMessage:message userUid:message.fromID];
                }
            }
            
        }else if (message.netCallChatType == 2) {
            //群聊音视频
            sessionType = CIMSessionTypeGroup;
            
            LingIMGroupModel *groupModel = [IMSDKManager toolCheckMyGroupWith:message.toID];
            if (groupModel) {
                sessionID = groupModel.groupId;
                sessionName = groupModel.groupName;
                sessionAvatar = groupModel.groupAvatar;
            }else {
                //本地查询不到群聊信息，调用接口查询
                [self privateGetGroupInfoWithReceiveMessage:message groupID:message.toID];
            }
            
        }
        
    } else if (message.chatType == CIMChatType_SignInReminder) {
        //系统消息(签到提醒)
        sessionType = CIMSessionTypeSignInReminder;
        
        // 统一映射为固定会话ID，避免因为不同来源字段导致重复会话
        sessionID = kSignInSessionID;
        sessionName = message.serverMessage.nick.length > 0 ? message.serverMessage.nick : @"签到助手";
        sessionAvatar = @"";
    } else {
        CIMLog(@"EEE消息解析未实现的chatType类型:%ld",message.chatType);
    }
    
    if (sessionID.length > 0) {
        //判断本地是否已有该会话
        LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
        
        if (sessionModel) {
            //本地已有该会话
            //1更新会话列表最新消息
            sessionModel.sessionUnreadCount += message.chatMessageReaded ? 0 : 1;
            //sessionModel.sessionLatestMessage = message;
            //sessionModel.sessionLatestTime = message.sendTime;
            //sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
            sessionModel.sessionStatus = 1;
            [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
            
            //2更新会话表里聊天信息
            //[DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionModel.sessionTableName];
            
            //3.更新未读消息总数
            NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
            [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
            
            //4.更新到UI层
            [self.sessionDelegate cimToolSessionUpdateWith:sessionModel];
            
            return YES;
        }else {
            //本地没有该会话
            //存储消息的表名称
            NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],sessionID];
            CIMLog(@"sessionTableName = %@",sessionTableName);

            //1.创建某一会话表
            [DBTOOL createTableWithName:sessionTableName model:NoaIMChatMessageModel.class];
            
            //2.会话列表新增数据
            sessionModel = [LingIMSessionModel new];
            
            sessionModel.sessionID = sessionID;
            sessionModel.sessionName = sessionName;
            sessionModel.sessionAvatar = sessionAvatar;
            sessionModel.sessionType = sessionType;
            sessionModel.sessionGroupType = groupType;
            sessionModel.sessionTableName = sessionTableName;
            sessionModel.sessionUnreadCount = message.chatMessageReaded ? 0 : 1;
            //sessionModel.sessionLatestMessage = message;
            sessionModel.sessionLatestTime = message.sendTime;
            //sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
            sessionModel.sessionStatus = 1;
            [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
            
            //3.消息存储到表
            //[DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionTableName];
            
            //4.更新未读消息总数
            NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
            [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
            
            //5.更新到UI层
            [self.sessionDelegate cimToolSessionReceiveWith:sessionModel];
            
            return YES;
        }
        
    }
    
    return NO;
}

#pragma mark - 更新会话列表，某会话信息
- (BOOL)toolUpdateSessionWith:(LingIMSessionModel *)sessionModel {
    BOOL result = [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
    if (result) {
        [self.sessionDelegate cimToolSessionUpdateWith:sessionModel];
        
        NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
        [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
    }
    return result;
}

#pragma mark - 删除我的某个回话
- (BOOL)toolDeleteMySessionWith:(NSString *)sessionID deleteAllChatMessage:(BOOL)deleteAll {
    
    //查询本地是否有该会话
    LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
    
    if (sessionModel) {
        
        BOOL result;
        
        if (deleteAll) {
            result = [DBTOOL deleteSessionModelWith:sessionModel.sessionID sessionTableName:sessionModel.sessionTableName];
            [self.messageDelegate cimToolMessageDeleteAll:sessionModel.sessionID];
        }else {
            result = [DBTOOL deleteSessionModelWith:sessionModel.sessionID sessionTableName:nil];
        }
        
        if (result) {
            if (sessionModel.sessionUnreadCount > 0) {
                NSInteger totalUnread = [self toolGetAllSessionUnreadCount];
                [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
            }
            [self.sessionDelegate cimToolSessionDeleteWith:sessionModel];
        }
        
        return result;
        
    }else {
        return YES;
    }
}

#pragma mark - 获取我的会话列表数据
- (NSArray *)toolGetMySessionListExcept:(NSString *)sessionId {
    return [DBTOOL getMySessionListExcept:sessionId];
}

#pragma mark - 获取我的会话列表置顶会话 分页数据
- (NSArray *)toolGetMyTopSessionListWithOffset:(NSInteger)offset limit:(NSInteger)limit {
    return [DBTOOL getMyTopSessionListWithOffset:offset limit:limit];
}

#pragma mark - 获取我的会话列表中前50个单聊的会话信息
- (NSArray *)toolGetMySessionListFromSignlChat {
    return [DBTOOL getMySessionListFromSignlChat];
}

#pragma mark - 获取我的会话列表数据，剔除掉 群助手、群发助手、系统通知等
- (NSArray *)toolGetMySessionListWithOffServer {
    return [DBTOOL getMySessionListWithOffServer];
}

#pragma mark - 获取我的会话列表单聊数据，剔除掉 群、群助手、群发助手、系统通知等
- (NSArray *)toolGetMySessionListFromSignlChatWithOffServer {
    return [DBTOOL getMySessionListFromSignlChatWithOffServer];
}

#pragma mark - 获取我置顶的会话列表
- (NSArray *)toolGetMyTopSessionListExcept:(NSString *)sessionId {
    return [DBTOOL getMyTopSessionListExcept:sessionId];
}

#pragma mark - 根据会话ID查询是否存在该会话
- (LingIMSessionModel *)toolCheckMySessionWith:(NSString *)sessionID {
    LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
    //由于没有存储会话的最新聊天消息，所以此处需要查询一下该会话的最新聊天消息
    sessionModel.sessionLatestMessage = [self toolGetLatestChatMessageWithSessionID:sessionID];
    return sessionModel;
}

/// 根据会话类型查询是否存在该会话
/// @param sessionType 会话类型
- (LingIMSessionModel *)toolCheckMySessionWithType:(CIMSessionType)sessionType {
    LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWithType:sessionType];
    //由于没有存储会话的最新聊天消息，所以此处需要查询一下该会话的最新聊天消息
    sessionModel.sessionLatestMessage = [self toolGetLatestChatMessageWithSessionID:sessionModel.sessionID];
    return sessionModel;
}

#pragma mark - 某个会话消息已读
- (BOOL)toolOneSessionAllReadWith:(LingIMSessionModel *)model {
    return [IMSDKManager toolMessageHaveReadAllWith:model.sessionID];
}

#pragma mark - 会话消息全部已读
- (void)toolSessionListAllRead {
    NSArray<LingIMSessionModel *> *unreadSessionList = [DBTOOL getAllSessionUnreadList];
    CIMWeakSelf
    [unreadSessionList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        LingIMSessionModel *model = (LingIMSessionModel *)obj;
        [weakSelf toolOneSessionAllReadWith:model];
    }];
}

#pragma mark - 获取会话全部未读消息数量
- (NSInteger)toolGetAllSessionUnreadCount {
    
    NSInteger totalUnread = [DBTOOL getAllSessionUnreadCount];
    
    return totalUnread;
}

#pragma mark - 删除会话model，以及是否清空会话内容
- (BOOL)toolDeleteSessionModelWith:(LingIMSessionModel *)model andDeleteAllChatModel:(BOOL)deleteAll {
    BOOL result;
    
    if (deleteAll) {
        result = [DBTOOL deleteSessionModelWith:model.sessionID sessionTableName:model.sessionTableName];
        [self.messageDelegate cimToolMessageDeleteAll:model.sessionID];
    }else {
        result = [DBTOOL deleteSessionModelWith:model.sessionID sessionTableName:nil];
    }
    
    if (result) {
        
        if (model.sessionUnreadCount > 0) {
            NSInteger totalUnread = [self toolGetAllSessionUnreadCount];
            [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
        }
        
        [self.sessionDelegate cimToolSessionDeleteWith:model];
    }
    return result;
}

#pragma mark - 清空我的会话列表信息
- (BOOL)toolDeleteAllMySession {
    return [DBTOOL deleteAllObjectWithName:NoaChatDBSessionTableName];
}

#pragma mark - 统一修改我的会话列表sessionStatus的值
- (BOOL)toolUpdateAllMySessionStatusWith:(NSInteger)sessionStatus {
    return [DBTOOL updateAllSessionStatusWith:sessionStatus];
}

#pragma mark - 更新会话列表中某个会话的头像
- (BOOL)toolUpdateSessionAvatarWithSessionId:(NSString *)sessionId withAvatar:(NSString *)avatar {
    return [DBTOOL updateSessionAvatarWithSessionId:sessionId withAvatar:avatar];
}

#pragma mark - 统一删除我的会话列表某个sessionStatus状态数据
- (BOOL)toolDeleteAllMySessionStatusWith:(NSInteger)sessionStatus {
    return [DBTOOL deleteAllSessionStatusWith:sessionStatus];
}

#pragma mark - ****** 私有方法 ******
#pragma mark - 查询不到本地好友时，根据接收到的消息，获取好友用户的信息
- (void)privateGetFriendInfoWithReceiveMessage:(NoaIMChatMessageModel *)message userUid:(NSString *)userUid {
    if (userUid.length > 0) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setValue:[self myUserID] forKey:@"userUid"];
        [params setValue:userUid forKey:@"friendUserUid"];
        [self getFriendInfoWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            if ([data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = (NSDictionary *)data;

                //执行了这个方法，说明本地没有该好友的信息，更新本地好友信息
                LingIMFriendModel *friendModel = [LingIMFriendModel mj_objectWithKeyValues:dataDict];
                friendModel.showName = friendModel.remarks.length > 0 ? friendModel.remarks : friendModel.nickname;
                [DBTOOL insertModelToTable:NoaChatDBFriendTableName model:friendModel];
                 
                
                //判断本地是否已有该会话
                LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:userUid];
                
                if (sessionModel) {
                    //本地已有该会话
                    //更新会话列表最新消息
                    sessionModel.sessionLatestTime = message.sendTime;
                    if (message.messageType == CIMChatMessageType_TextMessage && message.textContent.length <= 0) {
                        //过滤掉打招呼的空白消息
                        sessionModel.sessionLatestMessage = nil;
                        sessionModel.sessionLatestServerMsgID = @"";
                        sessionModel.sessionUnreadCount += 0;
                        [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                    
                    } else {
                        sessionModel.sessionLatestMessage = message;
                        sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
                        sessionModel.sessionUnreadCount += message.chatMessageReaded ? 0 : 1;
                        [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                        //2更新会话表里聊天信息
                        [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionModel.sessionTableName];
                    }
                    
                    //更新未读消息总数
                    NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                    [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
                    
                    //更新到UI层
                    [self.sessionDelegate cimToolSessionUpdateWith:sessionModel];
                    
                }else {
                    //本地没有该会话，则创建
                    //存储消息的表名称
                    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],userUid];
                    CIMLog(@"sessionTableName = %@",sessionTableName);

                    //创建某一会话表
                    [DBTOOL createTableWithName:sessionTableName model:NoaIMChatMessageModel.class];
                    
                    //会话列表新增数据
                    sessionModel = [LingIMSessionModel new];
                    
                    sessionModel.sessionID = userUid;
                    sessionModel.sessionName = friendModel.showName;
                    sessionModel.sessionAvatar = friendModel.avatar;
                    sessionModel.sessionType = CIMSessionTypeSingle;
                    sessionModel.sessionGroupType = CIMGroupTypeDefault;
                    sessionModel.sessionTop = friendModel.msgTop;
                    sessionModel.sessionNoDisturb = friendModel.msgNoPromt;
                    sessionModel.sessionTableName = sessionTableName;
                    sessionModel.sessionLatestTime = message.sendTime;
                    sessionModel.sessionStatus = 1;
                    
                    if (message.messageType == CIMChatMessageType_TextMessage && message.textContent.length <= 0) {
                        //过滤掉打招呼的空白消息
                        sessionModel.sessionLatestMessage = nil;
                        sessionModel.sessionLatestServerMsgID = @"";
                        sessionModel.sessionUnreadCount = 0;
                        [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                    
                    } else {
                        sessionModel.sessionLatestMessage = message;
                        sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
                        sessionModel.sessionUnreadCount = message.chatMessageReaded ? 0 : 1;
                        [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                        //2更新会话表里聊天信息
                        [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionModel.sessionTableName];
                    }
                    //更新未读消息总数
                    NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                    [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
                    
                    //更新到UI层
                    [self.sessionDelegate cimToolSessionReceiveWith:sessionModel];
                    
                    [self toolAddMyFriendWith:friendModel];
                }
                
                
                //我发送的消息 - 调用SDK的发送
                if (message.messageSendType == CIMChatMessageSendTypeSending) {
                    //数据库消息，转换为发送消息
                    IMChatMessage *chatMessage = [[LingIMModelTool sharedTool] getChatMessageModelFromLingIMChatMessageModel:message];
                    IMMessage *messageModel = [[IMMessage alloc] init];
                    messageModel.dataType = IMMessage_DataType_ImchatMessage;
                    messageModel.chatMessage = chatMessage;
                    cim_function_sendChatMessage(messageModel);
                }
                
                //我接收到到的消息 - 消息提醒+更新到UI
                if (message.messageSendType == CIMChatMessageSendTypeSuccess) {
                    //更新到UI
                    [self.messageDelegate cimToolChatMessageReceive:message];
                    //消息提醒
                    [self toolMessageReceiveRemindWithChatMessage:message];
                }
                
            }
            
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {}];
        
    }
}

#pragma mark - 查询不到本地群组时，根据接收到的消息，获取群组的信息
- (void)privateGetGroupInfoWithReceiveMessage:(NoaIMChatMessageModel *)message groupID:(NSString *)groupID {
    if (groupID.length > 0) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setValue:groupID forKey:@"groupId"];
        [params setValue:[self myUserID] forKey:@"userUid"];
        [self getGroupInfoWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
            if ([data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = (NSDictionary *)data;
                NSInteger userInGroup = [[dataDict objectForKey:@"userInGroup"] integerValue];
                if (userInGroup == 0) {
                    return;
                }

                //群名称
                NSString *sessionName = [NSString stringWithFormat:@"%@",[dataDict objectForKey:@"groupName"]];
                //群头像
                NSString *sessionAvatar = [NSString stringWithFormat:@"%@",[dataDict objectForKey:@"groupAvatar"]];
                //群聊置顶
                BOOL groupTop = [[dataDict objectForKey:@"msgTop"] boolValue];
                //群聊免打扰
                BOOL groupNoDisturb = [[dataDict objectForKey:@"msgNoPromt"] boolValue];
                //全群是否禁言
                BOOL groupGroupChat = [[dataDict objectForKey:@"isGroupChat"] boolValue];
                //进群是否需要验证
                BOOL groupNeedVerify = [[dataDict objectForKey:@"isNeedVerify"] boolValue];
                //全群是否禁止私聊
                BOOL groupPrivateChat = [[dataDict objectForKey:@"isPrivateChat"] boolValue];
                
                //执行了这个方法，说明本地没有该群的信息，更新本地群组信息
                LingIMGroupModel *groupModel = [LingIMGroupModel new];
                groupModel.groupId = groupID;
                groupModel.groupAvatar = sessionAvatar;
                groupModel.groupName = sessionName;
                groupModel.msgTop = groupTop;
                groupModel.msgNoPromt = groupNoDisturb;
                groupModel.isGroupChat = groupGroupChat;
                groupModel.isNeedVerify = groupNeedVerify;
                groupModel.isPrivateChat = groupPrivateChat;
                [DBTOOL insertOrUpdateGroupModelWith:groupModel];
                
                //判断本地是否已有该会话
                LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:groupID];
                
                if (sessionModel) {
                    //本地已有该会话
                    //更新会话列表最新消息
                    sessionModel.sessionUnreadCount += message.chatMessageReaded ? 0 : 1;
                    sessionModel.sessionLatestMessage = message;
                    sessionModel.sessionLatestTime = message.sendTime;
                    sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
                    [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                    
                    //更新会话表里聊天信息
                    [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionModel.sessionTableName];
                    
                    if (!message.chatMessageReaded) {
                        //更新未读消息总数
                        NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                        [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
                    }
                    
                    //更新到UI层 会话列表
                    [self.sessionDelegate cimToolSessionUpdateWith:sessionModel];
                    
                } else {
                    //本地没有该会话，则创建
                    //存储消息的表名称
                    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],groupID];
                    CIMLog(@"sessionTableName = %@",sessionTableName);

                    //创建某一会话表
                    [DBTOOL createTableWithName:sessionTableName model:NoaIMChatMessageModel.class];
                    
                    //会话列表新增数据
                    sessionModel = [LingIMSessionModel new];
        
                    sessionModel.sessionID = groupID;
                    sessionModel.sessionName = sessionName;
                    sessionModel.sessionAvatar = sessionAvatar;
                    sessionModel.sessionType = CIMSessionTypeGroup;
                    sessionModel.sessionGroupType = CIMGroupTypeNormal;
                    sessionModel.sessionTop = groupTop;
                    sessionModel.sessionNoDisturb = groupNoDisturb;
                    sessionModel.sessionTableName = sessionTableName;
                    sessionModel.sessionUnreadCount = message.chatMessageReaded ? 0 : 1;
                    sessionModel.sessionLatestMessage = message;
                    sessionModel.sessionLatestTime = message.sendTime;
                    sessionModel.sessionLatestServerMsgID = message.serviceMsgID;
                    sessionModel.sessionStatus = 1;
                    [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                    
                    //更新会话表里聊天信息
                    [DBTOOL insertOrUpdateChatMessageWith:message tableName:sessionModel.sessionTableName];
                    
                    if (!message.chatMessageReaded) {
                        //更新未读消息总数
                        NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                        [self.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
                    }
                    
                    //更新到UI层 会话列表
                    [self.sessionDelegate cimToolSessionReceiveWith:sessionModel];
                    
                }
                

                //我发送的消息 - 调用SDK的发送
                if (message.messageSendType == CIMChatMessageSendTypeSending) {
                    //数据库消息，转换为发送消息
                    IMChatMessage *chatMessage = [[LingIMModelTool sharedTool] getChatMessageModelFromLingIMChatMessageModel:message];
                    IMMessage *messageModel = [[IMMessage alloc] init];
                    messageModel.dataType = IMMessage_DataType_ImchatMessage;
                    messageModel.chatMessage = chatMessage;
                    cim_function_sendChatMessage(messageModel);
                }
                
                //我接收到到的消息 - 消息提醒+更新到UI
                if (message.messageSendType == CIMChatMessageSendTypeSuccess) {
                    //更新到UI
                    [self.messageDelegate cimToolChatMessageReceive:message];
                    //消息提醒
                    [self toolMessageReceiveRemindWithChatMessage:message];
                }
                
                
            }
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
            
        }];
    }
}

@end
