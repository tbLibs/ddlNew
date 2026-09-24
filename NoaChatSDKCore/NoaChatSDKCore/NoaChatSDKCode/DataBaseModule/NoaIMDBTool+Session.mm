//
//  NoaIMDBTool+Session.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/26.
//

#import "NoaIMDBTool+Session.h"
#import <WCDBObjc/WCDBObjc.h>

//好友信息
#import "LingIMSessionModel+WCTTableCoding.h"
#import "NoaIMDBTool+Friend.h"
//聊天信息
#import "NoaIMChatMessageModel+WCTTableCoding.h"
#import "NoaIMDBTool+ChatMessage.h"

@implementation NoaIMDBTool (Session)

#pragma mark - 获取我的 会话列表 数据
- (NSArray<LingIMSessionModel *> *)getMySessionListExcept:(NSString *)sessionId {
    if (sessionId.length > 0) {
        NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionID != sessionId orders:{LingIMSessionModel.sessionLatestTime.asOrder(WCTOrderedDescending)}];
        return sessionList;
    } else {
        NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName orders:{LingIMSessionModel.sessionLatestTime.asOrder(WCTOrderedDescending)}];
        return sessionList;
    }
}

#pragma mark - 获取我的 会话列表中前50条单聊 数据
- (NSArray<LingIMSessionModel *> *)getMySessionListFromSignlChat {
    NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionType == CIMSessionTypeSingle orders:{LingIMSessionModel.sessionLatestTime.asOrder(WCTOrderedDescending)} limit:50 offset:0];
    return sessionList;
}

#pragma mark - 获取我的会话列表单聊数据50条，剔除掉 群、群助手、群发助手、系统通知等
- (NSArray<LingIMSessionModel *> *)getMySessionListFromSignlChatWithOffServer {
    NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where: {LingIMSessionModel.sessionType == CIMSessionTypeSingle } orders:{LingIMSessionModel.sessionLatestTime.asOrder(WCTOrderedDescending),LingIMSessionModel.sessionTop.asOrder(WCTOrderedDescending)}];
    
    return sessionList;
}

#pragma mark - 获取我的会话列表数据，剔除掉 群助手、群发助手、系统通知等
- (NSArray<LingIMSessionModel *> *)getMySessionListWithOffServer {
    NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where: {LingIMSessionModel.sessionType == CIMSessionTypeSingle || LingIMSessionModel.sessionType == CIMSessionTypeGroup } orders:{LingIMSessionModel.sessionLatestTime.asOrder(WCTOrderedDescending),LingIMSessionModel.sessionTop.asOrder(WCTOrderedDescending)}];
    
    return sessionList;
}

#pragma mark - #pragma mark - 获取我的 置顶会话列表 数据
- (NSArray<LingIMSessionModel *> *)getMyTopSessionListExcept:(NSString *)sessionId {
    if (sessionId.length > 0) {
        NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionTop == YES && LingIMSessionModel.sessionID != sessionId orders:LingIMSessionModel.sessionTopTime.asOrder(WCTOrderedAscending)];
        return sessionList;
    } else {
        NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionTop == YES orders:LingIMSessionModel.sessionTopTime.asOrder(WCTOrderedAscending)];
        return sessionList;
    }
}

#pragma mark - 获取我的会话列表置顶会话 分页数据
- (NSArray<LingIMSessionModel *> *)getMyTopSessionListWithOffset:(NSInteger)offset limit:(NSInteger)limit {
    NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionTop == YES orders:LingIMSessionModel.sessionTopTime.asOrder(WCTOrderedAscending) limit:limit offset:offset];
    
    [sessionList enumerateObjectsUsingBlock:^(LingIMSessionModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *sessionTableName = obj.sessionTableName;
        NoaIMChatMessageModel *latestMessage = [DBTOOL getLatestChatMessageWithTableName:sessionTableName];
        obj.sessionLatestMessage = latestMessage;//用于和服务端数据对比
    }];
    
    return sessionList;
}

#pragma mark - 获取会话列表中全部未读会话
- (NSArray<LingIMSessionModel *> *)getAllSessionUnreadList{
    NSArray *sessionList = [self.noaChatDB getObjectsOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionUnreadCount > 0 || LingIMSessionModel.readTag > 0];
    return sessionList;
}

#pragma mark - 根据会话ID查询是否存在该会话

- (LingIMSessionModel *)checkMySessionWith:(NSString *)sessionID {
    return [self.noaChatDB getObjectOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionID == sessionID];

}


#pragma mark - 根据会话类型查询是否存在该会话
- (LingIMSessionModel *)checkMySessionWithType:(CIMSessionType)sessionType {
    return [self.noaChatDB getObjectOfClass:LingIMSessionModel.class fromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionType == CIMSessionTypeSystemMessage];

}

#pragma mark - 更新或新增会话到表
- (BOOL)insertOrUpdateSessionModelWith:(LingIMSessionModel *)model {
    return [DBTOOL insertModelToTable:NoaChatDBSessionTableName model:model];
}

#pragma mark - 批量-更新或新增会话到表
- (BOOL)insertOrUpdateSessionModelListWith:(NSArray<LingIMSessionModel *> *)list {
    return [DBTOOL insertMulitModelToTable:NoaChatDBSessionTableName modelClass:LingIMSessionModel.class list:list];
}

#pragma mark - 获取会话全部未读消息数量
- (NSInteger)getAllSessionUnreadCount {
    //真实未读总数
    NSNumber *totalUnreadCountNum = [[self.noaChatDB getValueOnResultColumn:LingIMSessionModel.sessionUnreadCount.sum()
                                                              fromTable:NoaChatDBSessionTableName
                                                                 where:LingIMSessionModel.sessionNoDisturb == NO] numberValue];
    
    NSInteger totalUnreadCount = totalUnreadCountNum.integerValue;
    
    //真实标记未读总数
    NSNumber *totalReadTagCountNum = [[self.noaChatDB getValueOnResultColumn:LingIMSessionModel.readTag.sum()
                                                               fromTable:NoaChatDBSessionTableName
                                                                  where:LingIMSessionModel.sessionNoDisturb == NO] numberValue];
    
    NSInteger totalReadTagCount = totalReadTagCountNum.integerValue;
    
    NSInteger total = totalUnreadCount + totalReadTagCount;
    return total > 0 ? total : 0;
}


#pragma mark - 获取某个会话的全部未读消息数量
- (NSInteger)getOneSessionUnreadCountWith:(NSString *)sessionTableName {
    return [[[self.noaChatDB getValueOnResultColumn:NoaIMChatMessageModel.chatMessageReaded.count() fromTable:sessionTableName where:NoaIMChatMessageModel.chatMessageReaded == NO] numberValue] integerValue];
}

#pragma mark - 根据聊天消息，获取存储消息的回话表名称
- (NSString *)getSessionTableNameWith:(NoaIMChatMessageModel *)message {
    NSString *sessionID;//会话ID
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
    } else if (message.chatType == CIMChatType_SingleChat) {
        //单聊消息
        if ([message.fromID isEqualToString:[DBTOOL myUserID]]) {
            //我发的消息
            sessionID = message.toID;
        }else {
            //对方发的消息
            sessionID = message.fromID;
        }
    } else if (message.chatType == CIMChatType_GroupChat) {
        //群聊消息
        sessionID = message.toID;
    } else {
        CIMLog(@"GGG消息解析未实现的chatType类型:%ld",message.chatType);
    }
    
    NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[DBTOOL myUserID],sessionID];
    
    CIMLog(@"sessionTableName = %@",sessionTableName);
    return sessionTableName;
}

#pragma mark - 根据聊天消息，获取会话ID
- (NSString *)getSessionIDWith:(NoaIMChatMessageModel *)message {
    NSString *sessionID;//会话ID
    if (message.chatType == CIMChatType_SingleChat) {
        //单聊消息
        if ([message.fromID isEqualToString:[DBTOOL myUserID]]) {
            //我发的消息
            LingIMFriendModel *friendModel = [DBTOOL checkMyFriendWith:message.toID];
            sessionID = friendModel.friendUserUID;
        }else {
            //对方发的消息
            sessionID = message.fromID;
        }
    } else if (message.chatType == CIMChatType_GroupChat) {
        //群聊消息
        sessionID = message.toID;
    } else {
        CIMLog(@"HHH消息解析未实现的chatType类型:%ld",message.chatType);
    }
    
    return sessionID;
}

#pragma mark - 删除会话model，以及是否清空会话内容
- (BOOL)deleteSessionModelWith:(NSString *)sessionID sessionTableName:(NSString * _Nullable)sessionTableName {
    if (sessionTableName.length > 0) {
        __block BOOL success = YES;
        __block BOOL deleteChatSuccess = YES;
        
        [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
            // 1. 删除会话
            success = [self.noaChatDB deleteFromTable:NoaChatDBSessionTableName
                                            where:LingIMSessionModel.sessionID == sessionID];
            
            if (!success) {
                return NO; // 会话删除失败，回滚事务
            }
            
            // 2. 清空本地和该会话相关的聊天信息
            deleteChatSuccess = [DBTOOL dropTableWithName:sessionTableName];
            
            if (!deleteChatSuccess) {
                return NO; // 会话删除失败，回滚事务
            }
            
            return success && deleteChatSuccess;
        }];
        
        return success && deleteChatSuccess;
        
    } else {
        // 只删除会话，单条操作，不需要事务
        return [self.noaChatDB deleteFromTable:NoaChatDBSessionTableName
                                     where:LingIMSessionModel.sessionID == sessionID];
    }
}

#pragma mark - 更新会话列表的全部sessionStatus值
- (BOOL)updateAllSessionStatusWith:(NSInteger)sessionStatus {
    __block BOOL result = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        result = [self.noaChatDB updateTable:NoaChatDBSessionTableName setProperty:LingIMSessionModel.sessionStatus toValue:@(sessionStatus) where:LingIMSessionModel.sessionType != CIMSessionTypeSignInReminder];
        return result;
    }];
    return result;
}

#pragma mark - 更新会话列表中某个会话的头像
- (BOOL)updateSessionAvatarWithSessionId:(NSString *)sessionId withAvatar:(NSString *)avatar {
    return [self.noaChatDB updateTable:NoaChatDBSessionTableName setProperty:LingIMSessionModel.sessionAvatar toValue:avatar where:LingIMSessionModel.sessionID == sessionId];

}


#pragma mark - 删除会话列表里某个状态的全部数据
- (BOOL)deleteAllSessionStatusWith:(NSInteger)sessionStatus {
    // 使用事务：可能删除多个会话，性能提升 5-10 倍
    __block BOOL result = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        result = [self.noaChatDB deleteFromTable:NoaChatDBSessionTableName where:LingIMSessionModel.sessionStatus == sessionStatus];
        return result;
    }];
    return result;
}
@end
