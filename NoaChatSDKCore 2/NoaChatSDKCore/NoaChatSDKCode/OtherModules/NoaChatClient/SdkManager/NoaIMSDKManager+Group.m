//
//  NoaIMSDKManager+Group.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "NoaIMSDKManager+Group.h"
#import "NoaIMSDKManager+Session.h"
#import "NoaIMSDKManager+ChatMessage.h"

@implementation NoaIMSDKManager (Group)

#pragma mark - 查询群组详情
- (void)getGroupInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] getGroupInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 创建群聊
- (void)createGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] createGroupWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 群聊列表
- (void)groupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupListWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 修改群组名称
- (void)changeGroupNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] changeGroupNameWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //修改群名称,操作成功
            NSString *groupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群ID
            NSString *groupNameNew = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupName"]];//修改成功的群名称
            
            //修改 会话 名称
            LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:groupID];
            sessionModel.sessionName = groupNameNew;
            [self toolUpdateSessionWith:sessionModel];
            
            //修改 群组 名称
            LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupID];
            groupModel.groupName = groupNameNew;
            [self toolInsertOrUpdateGroupModelWith:groupModel];
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
        }
        
    } onFailure:onFailure];
    
}
#pragma mark - 修改群组头像
- (void)changeGroupAvatarWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] changeGroupAvatarWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //修改群组头像,操作成功
            
            NSString *groupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群ID
            NSString *groupAvatarNew = [NSString stringWithFormat:@"%@", [params objectForKey:@"avatar"]];//修改成功的群头像
            
            //修改 会话 头像
            LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:groupID];
            sessionModel.sessionAvatar = groupAvatarNew;
            [self toolUpdateSessionWith:sessionModel];
            
            //修改 群组 头像
            LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupID];
            groupModel.groupAvatar = groupAvatarNew;
            [self toolInsertOrUpdateGroupModelWith:groupModel];
            [self.groupDelegate cimToolGroupUpdateWith:groupModel];
            
        }
        
    } onFailure:onFailure];
}
#pragma mark - 获取群成员列表(全量分页获取)
- (void)getGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] getGroupMemberListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 同步群成员列表(增量不分页获取)
- (void)syncGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] syncGroupMemberListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 同步群成员列表(增量不分页获取)
- (void)groupGetMemberActiviteScoreWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupGetMemberActiviteScoreWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 清空群聊 聊天记录
- (void)groupClearAllChatMessageWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupClearAllChatMessageWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //清空群聊聊天记录成功
            NSString *groupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群组ID
            //删除本地聊天消息
            [self toolDeleteAllChatMessageWith:groupID];
        }
        
    } onFailure:onFailure];
}

#pragma mark - 退出群聊
- (void)groupQuitWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupQuitWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //退出群组 成功
            NSString *groupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群ID
            
            LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupID];
            if (groupModel) {
                //删除群组信息
                [self toolDeleteMyGroupWith:groupID];
                [self.groupDelegate cimToolGroupDeleteWith:groupModel];
            }
            
            //删除本地存储聊天消息
            
        }
        
    } onFailure:onFailure];
    
}

#pragma mark - 我在本群的昵称

- (void)groupMyNicknameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupMyNicknameWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 移除群成员
- (void)groupRemoveMemberWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupRemoveMemberWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark -创建群公告
- (void)groupCreateGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupCreateGroupNoticeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark -移除群公告
- (void)groupDeleteGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupDeleteGroupNoticeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 修改群公告
- (void)groupChangeGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupChangeGroupNoticeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询群公告
- (void)groupCheckGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupCheckGroupNoticeWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 查询单条群公告
- (void)groupCheckOneGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupCheckOneGroupNoticeWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 群公告已读上报(关闭置顶群公告展示)
- (void)groupReadGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupReadGroupNoticeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 邀请好友进群
- (void)groupInviteFriendWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupInviteFriendWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询群禁言详情
- (void)groupGetNotalkStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupGetNotalkStateWith:params onSuccess:onSuccess onFailure:onFailure];
}

/// 查询群禁言成员列表
/// 传参:{groupId:群组ID,userUid:操作用户ID}
- (void)groupGetNotalkListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupGetNotalkListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群组单人禁言
- (void)groupSetNotalkMemberWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupSetNotalkMemberWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 设置全员禁言
- (void)groupSetNotalkAllWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupSetNotalkAllWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 删除用户历史消息
- (void)groupDeleteMemberHistoryMessageWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupDeleteMemberHistoryMessageWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 转让群主
- (void)groupChangeGroupOwnerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupChangeGroupOwnerWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 设置/取消群管理员
- (void)groupSetGroupManagerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupSetGroupManagerWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 解散群组
- (void)groupDissolutionGroupWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupDissolutionGroupWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            //解散群组成功
            NSString *groupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"groupId"]];//群ID
            
            LingIMGroupModel *groupModel = [self toolCheckMyGroupWith:groupID];
            if (groupModel) {
                //删除群组信息
                [self toolDeleteMyGroupWith:groupID];
                [self.groupDelegate cimToolGroupDeleteWith:groupModel];
            }
            
            //删除本地群组聊天
            
        }
    } onFailure:onFailure];
}

#pragma mark - 获取群组管理员列表
- (void)groupGetManagerListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupGetManagerListWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 获取群组机器人列表
- (void)groupGetRobotListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupGetRobotListWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 获取群组机器人数量
- (void)groupGetRobotCountWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupGetRobotCountWith:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 获取当前用户的禁言状态
- (void)groupGetUserNotalkStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] groupGetUserNotalkStateWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 查询群成员在本群昵称
- (void)groupGetUserNicKNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupGetUserNickNameWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取生成二维码所需要的内容
- (void)UserGetCreatQrcodeContentWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] getCreatQrCodeContent:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取生成二维码所需要的内容
- (void)UserGetTransformQrcodeContentWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] getScanQrContentTransformData:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 申请加入群聊
- (void)UserApplyJoinGroupWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupApplyJoinWithData:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取申请进群列表-群管理
- (void)groupManagerApplyJoinGroupListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupManagerApplyJoinListWithData:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取申请进群列表-群通知
- (void)groupNotificationApplyJoinGroupListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupNotificationApplyJoinListWithData:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 批量(单条)审核入群申请
- (void)groupJoinGroupApplyHandleWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupGroupJoinApplyHandleWithData:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 群内禁止私聊
- (void)groupSetPrivateChatStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupPrivateChatStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 进群验证开关
- (void)groupSetJoinGroupStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupJoinGroupStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 修改全员禁止音视频状态
- (void)groupUpdateAudioAndVideoCallStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupUpdateAudioVideoCallStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 修改 关闭群提示 开关状态
- (void)groupUpdateGroupRemindSwitchStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupUpdateGroupRemindSwitchStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

/*
* 修改 群二维码 开关状态
*  @param params 请求参数:{groupId:群组ID, status:群二维码(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupUpdateIsShowQrCodeWith:(NSMutableDictionary *)params
                               onSuccess:(LingIMSuccessCallback)onSuccess
                          onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupUpdateIsShowQrCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 新人查看群历史记录
- (void)groupNewMemberCheckHistoryStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupNewMemberCheckHistoryStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取群活跃配置
- (void)groupGetActivityLevelConfigWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] groupGetActivityLevelConfigWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 修改群活跃展示开关
- (void)groupUpdateActivityLevelEnableStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] groupUpdateActivityLevelEnableStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取我的群组列表数据
- (NSArray<LingIMGroupModel *> *)toolGetMyGroupList {
    return [DBTOOL getMyGroupList];
}

#pragma mark - 根据群组ID查询群组信息
- (LingIMGroupModel *)toolCheckMyGroupWith:(NSString *)groupID {
    return [DBTOOL checkMyGroupWith:groupID];
}

#pragma mark - 根据群组ID删除数据库内容
- (BOOL)toolDeleteMyGroupWith:(NSString *)groupID {
    return [DBTOOL deleteMyGroupWith:groupID];
}
#pragma mark - 新增群组信息
- (BOOL)toolInsertOrUpdateGroupModelWith:(LingIMGroupModel *)model {
    BOOL result = [DBTOOL insertOrUpdateGroupModelWith:model];
    return result;
}

#pragma mark - 批量 新增/更新群组信息
- (BOOL)toolBatchInsertOrUpdateGroupModelWith:(NSArray <LingIMGroupModel *> *)list {
    BOOL result = [DBTOOL  batchInsertOrUpdateGroupModelWithList:list];
    return result;
}

#pragma mark - 根据搜索内容查询群组数据
- (NSArray <LingIMGroupModel *> *)toolSearchMyGroupWith:(NSString *)searchStr {
    return [DBTOOL searchMyGroupWith:searchStr];
}

#pragma mark - 设置/取消 消息置顶
- (void)groupSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] groupSetMsgTopWith:params onSuccess:onSuccess onFailure:onFailure];
}


#pragma mark - 清空我的群组列表信息
- (BOOL)toolDeleteAllMyGroup {
    return [DBTOOL deleteAllObjectWithName:NoaChatDBGroupTableName];
}

@end
