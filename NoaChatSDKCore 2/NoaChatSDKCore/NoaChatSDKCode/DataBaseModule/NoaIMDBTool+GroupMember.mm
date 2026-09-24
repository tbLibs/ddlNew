//
//  NoaIMDBTool+Group.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "NoaIMDBTool+GroupMember.h"
//群组信息
#import "LingIMGroupMemberModel+WCTTableCoding.h"
#import "NoaIMSDKManager+Group.h"
#import "LingIMGroupActiviteScoreModel.h"

@implementation NoaIMDBTool (GroupMember)
/// 创建群成员表并且缓存群成员数据
/// @param groupId 群id
/// @param userId 当前登录用户Id
- (void)creatGroupMemberTableAndCacheGroupMemberWithGroupId:(NSString *)groupId userId:(NSString *)userId syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule {
    NSLog(@"whlog-----creatGroupMemberTableAndCacheGroupMemberWithGroupId");

    //针对每一个群列表创建一个单独的群组成表 表命名规则：CIMSDKDB_sessionid_GroupMemberTable
    NSString * groupMemberTabName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable",groupId];
    [DBTOOL createTableWithName:groupMemberTabName model:LingIMGroupMemberModel.class];
    
    LingIMGroupModel *groupInfoModel = [IMSDKManager toolCheckMyGroupWith:groupId];
    if (groupInfoModel.lastSyncMemberTime != 0) {
        //增量不分页
        [self syncGroupMemberListWithGroupId:groupId userId:userId groupMemberTabName:groupMemberTabName groupInfoModel:groupInfoModel syncGroupMemberSuccess:^{
            if(syncGroupMemberSuccess){
                syncGroupMemberSuccess();
            }
        } syncGroupMemberFaiule:^{
            if(syncGroupMemberFaiule){
                syncGroupMemberFaiule();
            }
        }];
    } else {
        NSMutableArray *tempMemberList = [NSMutableArray array];
        //全量分页
        [self requestGroupListReqWithPage:1 withGroupId:groupId withUserId:userId groupMemberTabName:groupMemberTabName tempMemberList:tempMemberList syncGroupMemberSuccess:^{
            if(syncGroupMemberSuccess){
                syncGroupMemberSuccess();
            }
        } syncGroupMemberFaiule:^{
            if(syncGroupMemberFaiule){
                syncGroupMemberFaiule();
            }
        }];
    }
}

//增量不分页同步群成员列表数据
- (void)syncGroupMemberListWithGroupId:(NSString *)groupId userId:(NSString *)userId groupMemberTabName:(NSString *)groupMemberTabName groupInfoModel:(LingIMGroupModel *)groupInfoModel syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule {

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:groupId forKey:@"groupId"];
    [dict setValue:userId forKey:@"userUid"];
    [dict setValue:@(groupInfoModel.lastSyncMemberTime) forKey:@"lastSyncTime"];
    
    CIMWeakSelf
    [IMSDKManager syncGroupMemberListWith:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSArray class]]) {
            NSArray *groupMemberDicArr = (NSArray *)data;
            
            for (NSDictionary *groupMemberDic in groupMemberDicArr) {
                LingIMGroupMemberModel *groupMemberModel = [LingIMGroupMemberModel mj_objectWithKeyValues:groupMemberDic];
                if (groupMemberModel.isDel) {
                    dispatch_async(weakSelf.groupMemberUpdateQueue, ^{
                        [DBTOOL deleteGroupMemberWithTabName:groupMemberTabName memberId:groupMemberModel.userUid];
                    });
                } else {
                    if(groupMemberModel.remarks == nil || [groupMemberModel.remarks isEqualToString:@""]){
                        if(![groupMemberModel.nicknameInGroup isEqualToString:@""] && groupMemberModel.nicknameInGroup){
                            groupMemberModel.showName = groupMemberModel.nicknameInGroup;
                        } else {
                            groupMemberModel.showName = groupMemberModel.userNickname;
                        }
                    } else{
                        groupMemberModel.showName = groupMemberModel.remarks;
                    }
                    if ( groupMemberModel.showName.length <= 0) {
                        groupMemberModel.showName = groupMemberModel.userNickname;
                    }
                    dispatch_async(weakSelf.groupMemberUpdateQueue, ^{
                        [DBTOOL insertOrUpdateGroupMemberModelWithTabName:groupMemberTabName memberModel:groupMemberModel];
                    });
                }
            }
            
            if (groupMemberDicArr.count > 0) {
                NSDictionary *groupMemberDic = (NSDictionary *)[groupMemberDicArr firstObject];
                long long latestUpdateTime = [[groupMemberDic objectForKey:@"latestUpdateTime"] longLongValue];
                groupInfoModel.lastSyncMemberTime = latestUpdateTime;
                [IMSDKManager toolInsertOrUpdateGroupModelWith:groupInfoModel];
            }
        
            if(syncGroupMemberSuccess){
                syncGroupMemberSuccess();
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        if(syncGroupMemberFaiule){
            syncGroupMemberFaiule();
        }
    }];
}

//全量分页请求群成员列表(用于第一次请求该群的群成员数据)
- (void)requestGroupListReqWithPage:(NSInteger)page withGroupId:(NSString *)groupId withUserId:(NSString *)userId groupMemberTabName:(NSString *)groupMemberTabName tempMemberList:(NSMutableArray *)tempMemberList syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:groupId forKey:@"groupId"];
    [dict setValue:@(page) forKey:@"pageNumber"];
    [dict setValue:@(100) forKey:@"pageSize"];
    [dict setValue:@(0) forKey:@"pageStart"];
    [dict setValue:userId forKey:@"userUid"];
    
    CIMWeakSelf
    [IMSDKManager getGroupMemberListWith:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataDic = (NSDictionary *)data;
            NSArray * groupMemberDicArr = dataDic[@"items"];
            
            for (NSDictionary *groupMemberDic in groupMemberDicArr) {
                LingIMGroupMemberModel *groupMemberModel = [LingIMGroupMemberModel mj_objectWithKeyValues:groupMemberDic];
                if(groupMemberModel.remarks == nil || [groupMemberModel.remarks isEqualToString:@""]){
                    if(groupMemberModel.nicknameInGroup && ![groupMemberModel.nicknameInGroup isEqualToString:@""]){
                        groupMemberModel.showName = groupMemberModel.nicknameInGroup;
                    }else{
                        groupMemberModel.showName = groupMemberModel.userNickname;
                    }
                }else{
                    groupMemberModel.showName = groupMemberModel.remarks;
                }
                if ( groupMemberModel.showName.length <= 0) {
                    groupMemberModel.showName = groupMemberModel.userNickname;
                }
                groupMemberModel.memberIsInGroup = YES;
                
                [tempMemberList addObject:groupMemberModel];
            }
            
            NSInteger totalPage = [[dataDic objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dataDic objectForKey:@"currentPage"] integerValue];
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf requestGroupListReqWithPage:currentPage + 1 withGroupId:groupId withUserId:userId groupMemberTabName:groupMemberTabName tempMemberList:tempMemberList syncGroupMemberSuccess:syncGroupMemberSuccess syncGroupMemberFaiule:syncGroupMemberFaiule];
            } else {
                dispatch_async(weakSelf.groupMemberUpdateQueue, ^{
                    [DBTOOL insertOrUpdateMultiGroupMemberModelWithTabName:groupMemberTabName memberList:tempMemberList];
                });
                
                if(syncGroupMemberSuccess){
                    syncGroupMemberSuccess();
                }
            }
            if (page == 1 && groupMemberDicArr.count > 0) {
                //保存本次拉取群成员列表的时间戳
                NSDictionary *groupMemberDic = (NSDictionary *)[groupMemberDicArr firstObject];
                long long latestUpdateTime = [[groupMemberDic objectForKey:@"latestUpdateTime"] longLongValue];
                
                LingIMGroupModel *groupInfoModel = [IMSDKManager toolCheckMyGroupWith:groupId];
                groupInfoModel.lastSyncMemberTime = latestUpdateTime;
                [IMSDKManager toolInsertOrUpdateGroupModelWith:groupInfoModel];
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        if(syncGroupMemberFaiule){
            syncGroupMemberFaiule();
        }
    }];
}

/// 同步群成员活跃积分并且缓存群成员数据表里
/// @param groupId 群id
- (void)syncGroupMemberActiviteScoreAndCacheScoreWithGroupId:(NSString *)groupId lastSyncTime:(long long)lastSyncTime page:(NSInteger)page tempDataList:(NSMutableArray *)tempDataList syncActiviteScoreSuccess:(syncGroupMemberActiviteScoreSuccess)syncActiviteScoreSuccess syncActiviteScoreFaiule:(syncGroupMemberActiviteScoreFaiule)syncActiviteScoreFaiule {
    
    CIMWeakSelf
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:groupId forKey:@"groupId"];
    [dict setValue:@(page) forKey:@"pageNumber"];
    [dict setValue:@(100) forKey:@"pageSize"];
    [dict setValue:@(0) forKey:@"pageStart"];
    [dict setValue:@(lastSyncTime) forKey:@"lastSyncTime"];
    
    [IMSDKManager groupGetMemberActiviteScoreWith:dict onSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataDic = (NSDictionary *)data;
            NSArray *recordsList = dataDic[@"records"];
            
            for (NSDictionary *scoreDic in recordsList) {
                LingIMGroupActiviteScoreModel *scoreModel = [LingIMGroupActiviteScoreModel mj_objectWithKeyValues:scoreDic];
                [tempDataList addObject:scoreModel];
            }
            
            NSInteger totalPage = [[dataDic objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dataDic objectForKey:@"current"] integerValue];
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf syncGroupMemberActiviteScoreAndCacheScoreWithGroupId:groupId lastSyncTime:lastSyncTime page:page+1 tempDataList:tempDataList syncActiviteScoreSuccess:syncActiviteScoreSuccess syncActiviteScoreFaiule:syncActiviteScoreFaiule];
            } else {
                dispatch_async(weakSelf.groupMemberUpdateQueue, ^{
                    NSString * groupMemberTabName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable",groupId];
                    [DBTOOL insertOrUpdateMultiActiviteScoreWithTabName:groupMemberTabName scoreList:tempDataList];
                });
                
                if(syncActiviteScoreSuccess){
                    syncActiviteScoreSuccess();
                }
            }
            if (page == 1 && recordsList.count > 0) {
                //保存本次拉取群成员活跃积分的时间戳
                LingIMGroupModel *groupInfoModel = [IMSDKManager toolCheckMyGroupWith:groupId];
                groupInfoModel.lastSyncActiviteScoreime = [NSDate getCurrentServerMillisecondTime];
                [IMSDKManager toolInsertOrUpdateGroupModelWith:groupInfoModel];
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        if(syncActiviteScoreFaiule){
            syncActiviteScoreFaiule();
        }
    }];
}

/// 查询当前表中所有的群成员数据 (不包括role == 3的机器人)
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getAllMemberWithTabName:(NSString *)tabName {
    return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role != 3];
}

/// 查询当前表里群成员中 群主和管理员 信息  role: 1管理员  2群主
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getGroupOwnerAndManagerWithTabName:(NSString *)tabName {
    return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 1 || LingIMGroupMemberModel.role == 2];
}

/// 查询当前表里群成员 除了群主和群机器人
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupMemberExceptOwnerWith:(NSString *)tabName {
    return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role != 2 && LingIMGroupMemberModel.role != 3];
}

/// 查询当前表里群成员中 群主 信息  role: 2群主
/// @param tabName 群名称
- (LingIMGroupMemberModel *)getGroupOwnerWithTabName:(NSString *)tabName exceptUserId:(NSString *)exceptUserId {
    if (exceptUserId.length > 0) {
        return [self.noaChatDB getObjectOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 2 && LingIMGroupMemberModel.userUid != exceptUserId];

    } else {
        return [self.noaChatDB getObjectOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 2];
    }
}

/// 查询当前表里群成员中 群管理 信息  role: 1管理员
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getGroupManagerWithTabName:(NSString *)tabName exceptUserId:(NSString *)exceptUserId {
    if (exceptUserId.length > 0) {
        return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 1 && LingIMGroupMemberModel.userUid != exceptUserId];
    } else {
        return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 1];
    }
}

/// 查询当前表里群成员中 普通群成员 信息  role: 0普通群成员 筛出掉群机器人
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getGroupNomalMemberWithTabName:(NSString *)tabName exceptUserId:(NSString *)exceptUserId {
    if (exceptUserId.length > 0) {
        return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 0 && LingIMGroupMemberModel.role != 3 && LingIMGroupMemberModel.userUid != exceptUserId];
    } else {
        return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.role == 0 && LingIMGroupMemberModel.role != 3];
    }
}

#pragma mark - 根据群成员ID查询群成员
- (LingIMGroupMemberModel *)checkGroupMemberWithTabName:(NSString *)tabName memberId:(NSString *)memberId{
    [DBTOOL isTableStateOkWithName:tabName model:LingIMGroupMemberModel.class];
    return [self.noaChatDB getObjectOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.userUid == memberId];
}

#pragma mark - 根据表名称、群成员id更新或新增群成员
- (BOOL)insertOrUpdateGroupMemberModelWithTabName:(NSString *)tabName memberModel:(LingIMGroupMemberModel *)memberModel{
    [DBTOOL isTableStateOkWithName:tabName model:LingIMGroupMemberModel.class];
    return [DBTOOL insertModelToTable:tabName model:memberModel];
}

#pragma mark -  删除群成员表中所有数据
- (BOOL)deleteAllGroupMemberWithTabName:(NSString *)tabName {
    BOOL result = [DBTOOL deleteAllObjectWithName:tabName];
    return result;
}

#pragma mark - 批量 更新或新增群成员
- (BOOL)insertOrUpdateMultiGroupMemberModelWithTabName:(NSString *)tabName memberList:(NSArray <LingIMGroupMemberModel *> *)memberList {
    BOOL result = [DBTOOL insertMulitModelToTable:tabName modelClass:LingIMGroupMemberModel.class list:memberList];
    return result;
}

#pragma mark - 批量 更新群成员活跃积分
- (BOOL)insertOrUpdateMultiActiviteScoreWithTabName:(NSString *)tabName scoreList:(NSArray <LingIMGroupActiviteScoreModel *> *)scoreList {
    for (LingIMGroupActiviteScoreModel *model in scoreList) {
        BOOL result = [self.noaChatDB updateTable:tabName setProperty:LingIMGroupMemberModel.activityScroe toValue:@(model.activityScore) where:LingIMGroupMemberModel.userUid == model.memberUid];
        
    }
    return YES;
}

#pragma mark - 根据群组ID删除数据库内容
- (BOOL)deleteGroupMemberWithTabName:(NSString *)tabName memberId:(NSString *)memberId{
    return [self.noaChatDB deleteFromTable:tabName where:LingIMGroupMemberModel.userUid == memberId];
}

#pragma mark - 根据表名称+ 群成员UserId / nickName / nickNameInGroup / remark 查询群成员
- (NSArray <LingIMGroupMemberModel *> *)checkGroupMemberWithTabName:(NSString *)tabName searchContent:(NSString *)searchContent exceptUserId:(NSString *)exceptUserId {
    [DBTOOL isTableStateOkWithName:tabName model:LingIMGroupMemberModel.class];
    
    searchContent = [[NoaIMManagerTool sharedManager] stringReplaceSpecialCharacterWith:searchContent];
    if (searchContent.length > 0) {
        NSString *likeStr = [NSString stringWithFormat:@"%%%@%%",searchContent];
        if (exceptUserId.length > 0) {
            return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:(LingIMGroupMemberModel.remarks.like(likeStr) || LingIMGroupMemberModel.nicknameInGroup.like(likeStr) || LingIMGroupMemberModel.userNickname.like(likeStr) || LingIMGroupMemberModel.userName.like(likeStr)) && LingIMGroupMemberModel.userUid != exceptUserId];
        } else {
            return [self.noaChatDB getObjectsOfClass:LingIMGroupMemberModel.class fromTable:tabName where:LingIMGroupMemberModel.remarks.like(likeStr) || LingIMGroupMemberModel.nicknameInGroup.like(likeStr) || LingIMGroupMemberModel.userNickname.like(likeStr) || LingIMGroupMemberModel.userName.like(likeStr)];
        }
    } else {
        return @[];
    }
}

@end
