//
//  NoaIMDBTool+ChatMessage.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/24.
//

#import "NoaIMDBTool+ChatMessage.h"
#import <WCDBObjc/WCDBObjc.h>
#import "NoaIMDBTool+Friend.h"
#import "NoaIMDBTool+Group.h"

//聊天信息
#import "NoaIMChatMessageModel+WCTTableCoding.h"

@implementation NoaIMDBTool (ChatMessage)
#pragma mark - 更新 或 新增 消息到 消息表

/// 单个插入聊天信息
/// - Parameters:
///   - message: 聊天信息
///   - tableName: 表名
- (BOOL)insertOrUpdateChatMessageWith:(NoaIMChatMessageModel *)message tableName:(NSString *)tableName {
    return [DBTOOL insertModelToTable:tableName model:message];
}

/// 批量插入聊天信息
/// - Parameters:
///   - messageList: 聊天信息列表
///   - tableName: 表名
- (BOOL)insertOrUpdateChatMessagesWith:(NSArray<NoaIMChatMessageModel *> *)messageList tableName:(NSString *)tableName {
    return [DBTOOL insertMulitModelToTable:tableName modelClass:NoaIMChatMessageModel.class list:messageList];
}

#pragma mark - 获取某个会话的聊天历史消息
- (NSArray<NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName limit:(NSInteger)limit offset:(NSInteger)offset {
    
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    
    return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:NoaIMChatMessageModel.messageStatus == 1 orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
}

#pragma mark - 获取某个会话的聊天历史最新的一条消息
- (NoaIMChatMessageModel *)getChatMessageHistoryFirstMsgWith:(NSString *)sessionTableName {
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    NSArray<NoaIMChatMessageModel *> *messageArr = [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:NoaIMChatMessageModel.messageStatus == 1 orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:1 offset:0];
    if (messageArr.count > 0) {
        return [messageArr firstObject];
    } else {
        return nil;
    }
}

#pragma mark - 获取某类型的聊天历史记录
- (NSArray<NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName limit:(NSInteger)limit offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString *)likeStr {
    
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    
    if (likeStr.length > 0) {
        //文本消息检索
        likeStr = [[NoaIMManagerTool sharedManager] stringReplaceSpecialCharacterWith:likeStr];
        
        if (likeStr.length > 0) {
            NSString *like = [NSString stringWithFormat:@"%%%@%%",likeStr];
            return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:{
                (NoaIMChatMessageModel.textContent.like(like) || NoaIMChatMessageModel.showContent.like(like)) && NoaIMChatMessageModel.messageStatus == 1
            } orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
        }else {
            return nil;
        }
    }else {
        return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:NoaIMChatMessageModel.messageType.in(messageType) && NoaIMChatMessageModel.messageStatus == 1 orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
    }
}

/// 获取某类型的聊天历史记录
/// @param sessionTableName 会话表名称
/// @param messageType 消息类型
/// @param likeStr 文本搜索内容
/// @param userIdList 发送者uid数组
- (NSArray <NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName limit:(NSInteger)limit offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString *)likeStr userIdList:(NSArray *)userIdList {
    //自检
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];

    if (likeStr.length > 0) {
        //文本消息检索
        likeStr = [[NoaIMManagerTool sharedManager] stringReplaceSpecialCharacterWith:likeStr];
        
        if (likeStr.length > 0) {
            NSString *like = [NSString stringWithFormat:@"%%%@%%",likeStr];
            if (userIdList.count <= 0) {
                return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:{
                    (NoaIMChatMessageModel.textContent.like(like) || NoaIMChatMessageModel.showContent.like(like) || NoaIMChatMessageModel.showFileName.like(like))  && NoaIMChatMessageModel.messageStatus == 1 && NoaIMChatMessageModel.messageType.in(messageType)
                } orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
            } else {
                return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:{
                    (NoaIMChatMessageModel.textContent.like(like) || NoaIMChatMessageModel.showContent.like(like) || NoaIMChatMessageModel.showFileName.like(like)) && NoaIMChatMessageModel.messageStatus == 1 && NoaIMChatMessageModel.messageType.in(messageType) && NoaIMChatMessageModel.fromID.in(userIdList)
                } orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
            }
        }else {
            return nil;
        }
    }else {
        if (userIdList.count <= 0) {
            return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:NoaIMChatMessageModel.messageType.in(messageType) && NoaIMChatMessageModel.messageStatus == 1 orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
        } else {
            return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:NoaIMChatMessageModel.messageType.in(messageType) && NoaIMChatMessageModel.fromID.in(userIdList) && NoaIMChatMessageModel.messageStatus == 1 orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:limit offset:offset];
        }
    }
}

#pragma mark - 获取某个时间范围内容的聊天历史记录（带默认上限）
- (NSArray<NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName startTime:(long long)startTime endTime:(long long)endTime {
    return [self getChatMessageHistoryWith:sessionTableName startTime:startTime endTime:endTime limit:300];
}

#pragma mark - 获取某个时间范围内容的聊天历史记录（指定上限）
- (NSArray<NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName startTime:(long long)startTime endTime:(long long)endTime limit:(NSInteger)limit {
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    NSInteger safeLimit = (limit > 0 ? limit : 300);
    if (endTime > 0) {
        return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class
                                   fromTable:sessionTableName
                                       where:{NoaIMChatMessageModel.sendTime >= startTime && NoaIMChatMessageModel.sendTime < endTime && NoaIMChatMessageModel.messageStatus == 1}
                                       orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)}
                                        limit:safeLimit
                                       offset:0];
    } else {
        return [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class
                                   fromTable:sessionTableName
                                       where:NoaIMChatMessageModel.sendTime >= startTime && NoaIMChatMessageModel.messageStatus == 1
                                       orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)}
                                        limit:safeLimit
                                       offset:0];
    }
}

#pragma mark - 按中心消息ID获取前后各N条图片/视频
- (NSArray<NoaIMChatMessageModel *> *)getImageVideoAroundWith:(NSString *)sessionTableName centerMsgId:(NSString *)centerMsgId before:(NSInteger)beforeCount after:(NSInteger)afterCount {
    [DBTOOL isTableStateOkWithName:sessionTableName model:NoaIMChatMessageModel.class];
    // 查中心消息
    NoaIMChatMessageModel *center = [self.noaChatDB getObjectOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:NoaIMChatMessageModel.msgID == centerMsgId];
    if (!center) { return @[]; }

    // 仅图片/视频类型
    NSArray *mediaTypes = @[@(CIMChatMessageType_ImageMessage), @(CIMChatMessageType_VideoMessage)];

    // 取时间更早（小于中心sendTime）的 beforeCount 条，时间倒序
    NSArray *beforeListDesc = [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:{NoaIMChatMessageModel.sendTime < center.sendTime && NoaIMChatMessageModel.messageType.in(mediaTypes) && NoaIMChatMessageModel.messageStatus == 1} orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)} limit:beforeCount offset:0];
    // 反转为时间正序，便于拼接
    NSArray *beforeList = [[beforeListDesc reverseObjectEnumerator] allObjects];

    // 取时间不早于中心的更新方向（>=中心时间，排除中心本身） afterCount 条，时间正序
    NSArray *afterListAsc = [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:sessionTableName where:{NoaIMChatMessageModel.sendTime >= center.sendTime && NoaIMChatMessageModel.msgID != centerMsgId && NoaIMChatMessageModel.messageType.in(mediaTypes) && NoaIMChatMessageModel.messageStatus == 1} orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedAscending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedAscending)} limit:afterCount offset:0];

    NSMutableArray *result = [NSMutableArray array];
    if (beforeList.count > 0) [result addObjectsFromArray:beforeList];
    // 中心消息若是图片/视频，则插入到中间；否则不插
    if ([mediaTypes containsObject:@(center.messageType)]) {
        [result addObject:center];
    }
    if (afterListAsc.count > 0) [result addObjectsFromArray:afterListAsc];

    return result.copy;
}
#pragma mark - 删除 某消息
- (BOOL)deleteChatMessageWith:(NoaIMChatMessageModel *)message tableName:(NSString *)tableName {
    //删除消息，本地数据库不会删除，会修改消息状态 0删除 1正常 2撤回
    message.messageStatus = 0;
    return [DBTOOL insertOrUpdateChatMessageWith:message tableName:tableName];
    //return [self.cimDB deleteObjectsFromTable:tableName where:LingIMChatMessageModel.msgID == message.msgID];
}

#pragma mark - 撤回 某消息
- (BOOL)backDeleteChatMessageWith:(NoaIMChatMessageModel *)message tableName:(NSString *)tableName {
    //撤回消息，本地数据库不会删除，会修改消息状态 0删除 1正常 2撤回
    message.messageStatus = 2;
    return [DBTOOL insertOrUpdateChatMessageWith:message tableName:tableName];
    
}

#pragma mark - 清空某个会话的全部聊天数据
- (BOOL)deleteAllChatMessageWith:(NSString *)tableName {
    __block BOOL result = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        result = [self.noaChatDB deleteFromTable:tableName];
        return result;
    }];
    return result;
}

#pragma mark - 删除群里某个群成员在本群发过的所有本地缓存的消息
- (BOOL)deleteGroupMemberAllSendChatMessageWith:(NSString *)tableName withMemberId:(NSString *)memberId {
    __block BOOL result = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        result = [self.noaChatDB deleteFromTable:tableName where:NoaIMChatMessageModel.fromID == memberId];
        return result;
    }];
    return result;
}

#pragma mark - 根据某个消息ID获取消息
- (NoaIMChatMessageModel *)getOneChatMessageWithMessageID:(NSString *)msgID withTableName:(NSString *)tableName {
    [DBTOOL isTableStateOkWithName:tableName model:NoaIMChatMessageModel.class];
    return [self.noaChatDB getObjectOfClass:NoaIMChatMessageModel.class fromTable:tableName where:NoaIMChatMessageModel.msgID == msgID];
}

#pragma mark - 根据某个服务端消息ID获取消息
- (NoaIMChatMessageModel *)getOneChatMessageWithServiceMessageID:(NSString *)smsgID withTableName:(NSString *)tableName {
    [DBTOOL isTableStateOkWithName:tableName model:NoaIMChatMessageModel.class];
    return [self.noaChatDB getObjectOfClass:NoaIMChatMessageModel.class fromTable:tableName where:NoaIMChatMessageModel.serviceMsgID == smsgID];
}
#pragma mark - 根据某个服务端消息ID获取消息（排除删除和撤回的消息）
- (NoaIMChatMessageModel *)getOneChatMessageWithServiceMessageIDExcludeDeleted:(NSString *)smsgID withTableName:(NSString *)tableName {
    [DBTOOL isTableStateOkWithName:tableName model:NoaIMChatMessageModel.class];
    // 过滤条件：messageStatus == 1 (正常消息，排除删除 status=0 和撤回 status=2)
    // 同时排除双向删除类型的消息
    return [self.noaChatDB getObjectOfClass:NoaIMChatMessageModel.class fromTable:tableName where:NoaIMChatMessageModel.serviceMsgID == smsgID && NoaIMChatMessageModel.messageStatus == 1 && NoaIMChatMessageModel.messageType != CIMChatMessageType_BilateralDel];
}


#pragma mark - 获取某个会话的最新消息
- (NoaIMChatMessageModel *)getLatestChatMessageWithTableName:(NSString *)tableName {
    
    [DBTOOL isTableStateOkWithName:tableName model:NoaIMChatMessageModel.class];
    return [self.noaChatDB getObjectOfClass:NoaIMChatMessageModel.class fromTable:tableName where:NoaIMChatMessageModel.messageStatus == 1 && NoaIMChatMessageModel.messageType != CIMChatMessageType_BilateralDel orders:{NoaIMChatMessageModel.sendTime.asOrder(WCTOrderedDescending), NoaIMChatMessageModel.serviceMsgID.asOrder(WCTOrderedDescending)}];
}

#pragma mark - 全部已读某个会话表的消息
- (BOOL)messageHaveReadAllWith:(NSString *)tableName {
    __block BOOL result = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        result = [self.noaChatDB updateTable:tableName setProperty:NoaIMChatMessageModel.chatMessageReaded toValue:@(YES)];
        return result;
    }];
    return result;
}

#pragma mark - 根据搜索内容查询聊天记录
- (NSArray<NoaIMChatMessageModel *> *)searchChatMessageWith:(NSString *)searchStr {
    //%搜索%，检索任意位置包含有 搜索 字段的内容
    searchStr = [[NoaIMManagerTool sharedManager] stringReplaceSpecialCharacterWith:searchStr];
    
    if (searchStr.length > 0) {
        
        NSString *likeStr = [NSString stringWithFormat:@"%%%@%%",searchStr];
        
        //先获取所有 好友和群聊
        NSArray *friendList = [DBTOOL getMyFriendList];
        NSArray *groupList = [DBTOOL getMyGroupList];
        //合并列表查询
        NSMutableArray *totalTableList = [NSMutableArray array];
        [totalTableList addObjectsFromArray:friendList];
        [totalTableList addObjectsFromArray:groupList];
        
        __block NSMutableArray *resultMessageArr = [[NSMutableArray alloc] init];
        [totalTableList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            //消息表名称
            NSString *messageTableName;
            if ([obj isKindOfClass:[LingIMFriendModel class]]) {
                LingIMFriendModel *friendModel = (LingIMFriendModel *)obj;
                messageTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",self.myUserID,friendModel.friendUserUID];
            }else if ([obj isKindOfClass:[LingIMGroupModel class]]) {
                LingIMGroupModel *groupModel = (LingIMGroupModel *)obj;
                messageTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",self.myUserID,groupModel.groupId];
            }
            CIMLog(@"sessionTableName = %@",messageTableName);

            
            //搜索检索
            NSArray *searchMessageList = [self.noaChatDB getObjectsOfClass:NoaIMChatMessageModel.class fromTable:messageTableName where:NoaIMChatMessageModel.textContent.like(likeStr) || NoaIMChatMessageModel.showFileName.like(likeStr)];
            
            [resultMessageArr addObjectsFromArray:searchMessageList];
        }];
        
        //查询单聊里的消息
//        if (friendList.count > 0) {
//            for (LingIMFriendModel *friendModel in friendList) {
//                NSString *friendSessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",self.myUserID,friendModel.friendUserUID];
//                NSArray *msgArr = [self.cimDB getObjectsOfClass:LingIMChatMessageModel.class fromTable:friendSessionTableName where:LingIMChatMessageModel.textContent.like(likeStr) || LingIMChatMessageModel.showFileName.like(likeStr)];
//                if (msgArr.count > 0) {
//                    [resultMessageArr addObjectsFromArray:msgArr];
//                }
//            }
//        }
        
        //查询群聊里的消息
//        if (groupList.count > 0) {
//            for (LingIMGroupModel *groupModel in groupList) {
//                NSString *groupSessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",self.myUserID,groupModel.groupId];
//                NSArray *msgArr = [self.cimDB getObjectsOfClass:LingIMChatMessageModel.class fromTable:groupSessionTableName where:LingIMChatMessageModel.textContent.like(likeStr) || LingIMChatMessageModel.showFileName.like(likeStr)];
//                if (msgArr.count > 0) {
//                    [resultMessageArr addObjectsFromArray:msgArr];
//                }
//            }
//        }
        return resultMessageArr;
    }else {
        return nil;
    }
}

#pragma mark - 删除某个时间戳之前的所有消息(eg:timeValue为2023年1月1日10:01，则类似2023年1月1日10:00这样的消息都被删除)
- (BOOL)messageDeleteBeforTime:(long long)timeValue withTableName:(NSString *)tableName {
    __block BOOL deleteResult = YES;
    [self.noaChatDB runTransaction:^BOOL(WCTHandle * _Nonnull) {
        deleteResult = [self.noaChatDB deleteFromTable:tableName where:NoaIMChatMessageModel.sendTime <= timeValue];
        return deleteResult;
    }];
    return deleteResult;
}

@end
