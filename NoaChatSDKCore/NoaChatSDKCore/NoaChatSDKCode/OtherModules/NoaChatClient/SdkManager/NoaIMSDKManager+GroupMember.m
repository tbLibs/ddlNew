//
//  NoaIMSDKManager+GroupMember.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/21.
//

#import "NoaIMSDKManager+GroupMember.h"
#import "NoaIMSDKManager+Group.h"


@implementation NoaIMSDKManager (GroupMember)

#pragma mark - 创建群成员表并且缓存群成员数据
- (void)imSdkCreatSaveGroupMemberTableWith:(NSString *)groupID syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule {
    //NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupId];
    
    [DBTOOL creatGroupMemberTableAndCacheGroupMemberWithGroupId:groupID userId:[self myUserID] syncGroupMemberSuccess:syncGroupMemberSuccess syncGroupMemberFaiule:syncGroupMemberFaiule];
    
    //更新群机器人信息到本地群成员表
    [self imSdkSyncGrounpRootListWithGroupId:groupID];
}

////群成员活跃积分分页列表-增量
/// @param groupID 群id
- (void)imSdkGetGroupMemberActiviteScoreTableWith:(NSString *)groupID syncMemberActiviteScoreSuccess:(syncGroupMemberActiviteScoreSuccess)syncActiviteScoreSuccess syncMemberActiviteScoreFaiule:(syncGroupMemberActiviteScoreFaiule)syncActiviteScoreFaiule {
    
    LingIMGroupModel *groupInfoModel = [IMSDKManager toolCheckMyGroupWith:groupID];
    NSMutableArray *tempDataList = [NSMutableArray array];
    [DBTOOL syncGroupMemberActiviteScoreAndCacheScoreWithGroupId:groupID lastSyncTime:groupInfoModel.lastSyncActiviteScoreime page:1 tempDataList:tempDataList syncActiviteScoreSuccess:syncActiviteScoreSuccess syncActiviteScoreFaiule:syncActiviteScoreFaiule];
}

#pragma mark - 获取群机器人信息并将群机器人信息转成LingIMGrounpMemberModel存储到群成员表里
- (void)imSdkSyncGrounpRootListWithGroupId:(NSString *)groupId {
    NSString * groupMemberTabName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable",groupId];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:groupId forKey:@"groupId"];
    [self groupGetRobotListWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSArray class]]) {
            NSArray *robotArray = (NSArray *)data;
            NSMutableArray *rootMemberList = [[NSMutableArray alloc] init];
            for(NSDictionary * dic in robotArray){
                LingIMGroupMemberModel *rootMemberModel = [[LingIMGroupMemberModel alloc] init];
                rootMemberModel.userUid = (NSString *)[dic objectForKey:@"userUid"];
                rootMemberModel.userAvatar  = (NSString *)[dic objectForKey:@"headPhoto"];
                rootMemberModel.userNickname = (NSString *)[dic objectForKey:@"robotName"];
                rootMemberModel.nicknameInGroup = (NSString *)[dic objectForKey:@"robotName"];
                rootMemberModel.remarks = (NSString *)[dic objectForKey:@"robotName"];
                rootMemberModel.showName = (NSString *)[dic objectForKey:@"robotName"];
                rootMemberModel.role = 3;
                rootMemberModel.isGroupMember = YES;
                rootMemberModel.descRemark = (NSString *)[dic objectForKey:@"robotDesc"];
                rootMemberModel.memberIsInGroup = YES;
                rootMemberModel.isDel = NO;
                
                [rootMemberList addObject:rootMemberModel];
            }
            [DBTOOL insertOrUpdateMultiGroupMemberModelWithTabName:groupMemberTabName memberList:rootMemberList];
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
    }];
}

#pragma mark - 查询当前群中 所有的 群成员 数据 (不包括role == 3的机器人)
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetAllGroupMemberWith:(NSString *)groupID {
    
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    
    return [DBTOOL getAllMemberWithTabName:tableName];
}

/// 查询当前群中 所有的 群成员里 群主和管理的数据
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupOwnerAndManagerWith:(NSString *)groupID {
    
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL getGroupOwnerAndManagerWithTabName:tableName];
}

/// 查询当前群中 所有的 群成员里 去除掉群主
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupMemberExceptOwnerWith:(NSString *)groupID {
    
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL imSdkGetGroupMemberExceptOwnerWith:tableName];
}

/// 查询当前群中  群成员里群主
/// @param groupID 群ID
- (LingIMGroupMemberModel *)imSdkGetGroupOwnerWith:(NSString *)groupID exceptUserId:(NSString *)exceptUserId {
    
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL getGroupOwnerWithTabName:tableName exceptUserId:exceptUserId];
}

/// 查询当前群中  群成员里管理员
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGrouManagerWith:(NSString *)groupID exceptUserId:(NSString *)exceptUserId {
    
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL getGroupManagerWithTabName:tableName exceptUserId:exceptUserId];
}

/// 查询当前群中  群成员里普通群成员(去除掉群主和管理员)
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupNomalMemberWith:(NSString *)groupID exceptUserId:(NSString *)exceptUserId {
    
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL getGroupNomalMemberWithTabName:tableName exceptUserId:exceptUserId];
}

#pragma mark - 群成员ID 查询群成员
/// @param memberID 群成员ID
- (LingIMGroupMemberModel *)imSdkCheckGroupMemberWith:(NSString *)memberID groupID:(nonnull NSString *)groupID {
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    
    LingIMGroupMemberModel *groupMemberModel = [DBTOOL checkGroupMemberWithTabName:tableName memberId:memberID];
    groupMemberModel.showName = (groupMemberModel.showName.length > 0 ? groupMemberModel.showName : groupMemberModel.userNickname);
    return groupMemberModel;
}

#pragma mark - 新增或更新 某个群的 群成员信息
- (BOOL)imSdkInsertOrUpdateGroupMember:(LingIMGroupMemberModel *)memberModel groupID:(nonnull NSString *)groupID {
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL insertOrUpdateGroupMemberModelWithTabName:tableName memberModel:memberModel];
}

#pragma mark - 删除某个群的群成员
- (BOOL)imSdkDeleteGroupMemberWith:(NSString *)memberID groupID:(nonnull NSString *)groupID {
    NSString *tableName = [NSString stringWithFormat:@"CIMSDKDB_%@_GroupMemberTable", groupID];
    return [DBTOOL deleteGroupMemberWithTabName:tableName memberId:memberID];
}

@end
