//
//  NoaIMSDKManager+Friend.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "NoaIMSDKManager+Friend.h"
#import "NoaIMHttpManager+Friend.h"
#import "MMKV/MMKV.h"
@implementation NoaIMSDKManager (Friend)
#pragma mark - 获取我的好友列表数据
- (NSArray<LingIMFriendModel *> *)toolGetMyFriendList {
    return [DBTOOL getMyFriendList];
}

#pragma mark - 获取我的好友列表数据（不包含已注销账号）
- (NSArray<LingIMFriendModel *> *)toolGetMyFriendListOffLogout {
    return [DBTOOL getMyFriendListOffLogout];
}

#pragma mark - 根据用的ID查询是否是我的好友
- (LingIMFriendModel *)toolCheckMyFriendWith:(NSString *)userID {
    return [DBTOOL checkMyFriendWith:userID];
}

#pragma mark - 根据用的ID查询是否是我的好友
- (LingIMFriendModel *)toolCheckMyFriendWithOffLogout:(NSString *)userID {
    return [DBTOOL checkMyFriendWithOffLogout:userID];
}

#pragma mark - 根据好友ID删除数据库内容
- (BOOL)toolDeleteMyFriendWith:(NSString *)myFriendID {
    return [DBTOOL deleteMyFriendWith:myFriendID];
}
#pragma mark - 新增好友信息
- (BOOL)toolAddMyFriendWith:(LingIMFriendModel *)model {
    BOOL result = [DBTOOL insertModelToTable:NoaChatDBFriendTableName model:model];
    if (result) {
        [self.userDelegate imSdkUserFriendAdd:model];
        [self.userDelegate imSdkUserFriendGroupChange];
    }
    return result;
}

#pragma mark - 新增好友信息，此方法不会触发代理回调
- (BOOL)toolAddMyFriendOnlyWith:(LingIMFriendModel *)model {
    BOOL result = [DBTOOL insertModelToTable:NoaChatDBFriendTableName model:model];
    return result;
}

#pragma mark - 更新好友信息
- (BOOL)toolUpdateMyFriendWith:(LingIMFriendModel *)model {
    BOOL result = [DBTOOL insertModelToTable:NoaChatDBFriendTableName model:model];
    if (result) {
        [self.userDelegate cimToolUserFriendChange:model];
        [self.userDelegate imSdkUserFriendGroupChange];
    }
    return result;
}

#pragma mark - 批量 更新好友信息(只更新数据库)
/// @param list 批量好友信息数组
- (BOOL)toolBacthDBUpdateMyFriendWith:(NSArray <LingIMFriendModel *> *)list {
    BOOL result = [DBTOOL insertMulitModelToTable:NoaChatDBFriendTableName modelClass:LingIMFriendModel.class list:list];
    return result;
}

#pragma mark - 根据搜索内容，查询好友
- (NSArray *)toolSearchMyFriendWith:(NSString *)searchStr {
    return [DBTOOL searchMyFriendWith:searchStr];
}

#pragma mark - 更新好友申请红点个数
- (void)toolUpdateFriendApplyCount:(NSInteger)friendApplyCount {
    [DBTOOL updateFriendApplyCount:friendApplyCount];
    
    [self.userDelegate cimToolUserFriendInviteTotalUnreadCount:friendApplyCount];
}

#pragma mark - 获取好友申请红点个数
- (NSInteger)toolFriendApplyCount {
    return [DBTOOL friendApplyCount];
}
#pragma mark - 清空我的好友列表信息
- (BOOL)toolDeleteAllMyFriend {
    return [DBTOOL deleteAllObjectWithName:NoaChatDBFriendTableName];
}

#pragma mark - <<<<<<好友分组模块>>>>>>
#pragma mark - 好友分组数据 新增
- (BOOL)toolAddMyFriendGroupWith:(LingIMFriendGroupModel *)friendGroupModel {
    BOOL result = [DBTOOL insertFriendGroupWith:friendGroupModel];
    return result;
}

#pragma mark - 好友分组数据 更新
- (BOOL)toolUpdateMyFriendGroupWith:(LingIMFriendGroupModel *)friendGroupModel {
    return [DBTOOL insertFriendGroupWith:friendGroupModel];
}

#pragma mark - 删除好友分组
- (BOOL)toolDeleteMyFriendGroupWith:(NSString *)friendGroupID {
    return [DBTOOL deleteMyFriendGroupWith:friendGroupID];
}

#pragma mark - 获取某个好友分组信息
- (LingIMFriendGroupModel *)toolCheckMyFriendGroupWith:(NSString *)friendGroupID {
    return [DBTOOL checkMyFriendGroupWith:friendGroupID];
}

#pragma mark - 获取我的 好友分组 列表
- (NSArray <LingIMFriendGroupModel *> *)toolGetMyFriendGroupList {
    return [DBTOOL getMyFriendGroupList];
}

#pragma mark - 获取我的 某个类型的 好友分组 列表
- (NSArray <LingIMFriendGroupModel *> *)toolGetMyFriendGroupTypeList:(NSInteger)friendGroupType {
    return [DBTOOL getMyFriendGroupTypeList:friendGroupType];
}

#pragma mark - 删除我的全部 好友分组 列表
- (BOOL)toolDeleteAllMyFriendGroup {
    return [DBTOOL deleteAllObjectWithName:NoaChatDBFriendGroupTableName];
}

#pragma mark - 获取某个 好友分组 下的 好友列表(所有的，包含已注销账号)
- (NSArray<LingIMFriendModel *> *)toolGetMyFriendGroupFriendsWith:(NSString *)friendGroupID {
    return [DBTOOL getMyFriendGroupFriendsWith:friendGroupID];
}

#pragma mark - 获取某个 好友分组 下的 好友列表(所有的，不包含已注销账号)
- (NSArray<LingIMFriendModel *> *)toolGetMyFriendGroupFriendsOffLogoutWith:(NSString *)friendGroupID {
    return [DBTOOL getMyFriendGroupFriendsOffLogoutWith:friendGroupID];
}

#pragma mark - ------ 接口操作 ------
#pragma mark - 从服务器获取黑名单列表
- (void)getBlackListFromServerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendGetBlackListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 将用户加入黑名单
- (void)addUserToBlackListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendAddBlackWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 将用户移出黑名单
- (void)removeUserFromBlackListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendRemoveBlackWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取用户的拉黑状态
- (void)getUserBlackStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendCheckBlackStateWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 从服务端获取好友通讯录列表
- (void)getContactsFromServerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendGetListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 好友验证(是否是我的好友)
- (void)checkMyFriendWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendCheckWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 从服务端获取好友申请列表
- (void)getFriendApplyListFromServerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendGetApplyListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 好友邀请信息增量列表查询
- (void)getFriendSyncReqListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendSyncReqListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 添加好友，发起好友申请
- (void)addContactWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendAddContactWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 移除好友，删除我的某个好友
- (void)deleteContactWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendDeleteContactWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL dataResult = [data boolValue];
        if (dataResult) {
            
            //删除好友成功，删除本地数据库好友信息
            NSString *friendUid = [NSString stringWithFormat:@"%@",[params objectForKey:@"friendUserUid"]];
            LingIMFriendModel *friendModel = [self toolCheckMyFriendWith:friendUid];
            if (friendModel) {
                [self toolDeleteMyFriendWith:friendUid];
                [self.userDelegate imSdkUserFriendDelete:friendModel];
                [self.userDelegate imSdkUserFriendGroupChange];
            }
            
            
        }
        
    } onFailure:onFailure];
}

#pragma mark - 同意确认对方发来的好友申请
- (void)confirmFriendApplyWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendApplyConfirmWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 根据好友的uid获取好友的信息
- (void)getFriendInfoWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendGetFriendInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 修改好友备注描述
- (void)friendSetFriendRemarkAndDesWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    [[NoaIMHttpManager sharedManager] friendSetFriendRemarkAndDesWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 通讯录 - 好友分组模块
#pragma mark - 查询好友分组列表数据
- (void)getFriendGroupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] friendGroupListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 创建好友分组
- (void)createFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    __weak typeof(self) weakSelf = self;
    [[NoaIMHttpManager sharedManager] friendGroupCreateWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        [weakSelf requestUpdateFriendGroupListFromServiceOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        }];
        
    } onFailure:onFailure];
}

#pragma mark - 修改好友分组(好友分组名称/排序)
- (void)updateFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    __weak typeof(self) weakSelf = self;
    [[NoaIMHttpManager sharedManager] friendGroupUpdateWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        NSString *friendGroupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"ugUuid"]];
        LingIMFriendGroupModel *friendGroupModel = [self toolCheckMyFriendGroupWith:friendGroupID];
        if (friendGroupModel) {
            if ([params.allKeys containsObject:@"ugName"]) {
                //更新了好友分组名称
                NSString *friendGroupName = [NSString stringWithFormat:@"%@", [params objectForKey:@"ugName"]];
                friendGroupModel.ugName = friendGroupName;
            }
            if ([params.allKeys containsObject:@"ugOrder"]) {
                //更新了好友分组排序
                NSInteger friendGroupOrder = [[params objectForKey:@"ugOrder"] integerValue];
                friendGroupModel.ugOrder = friendGroupOrder;
            }
        }
        //接口更新 好友分组 数据
        [weakSelf requestUpdateFriendGroupListFromServiceOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        }];
        
        
    } onFailure:onFailure];
}

#pragma mark - 删除好友分组
- (void)deleteFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    __weak typeof(self) weakSelf = self;
    [[NoaIMHttpManager sharedManager] friendGroupDeleteWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        //接口请求成功
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        //好友分组删除成功后，将该分组下的好友，更新到默认分组下
        NSString *friendGroupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"ugUuid"]];
        NSArray *friendList = [self toolGetMyFriendGroupFriendsWith:friendGroupID];
        LingIMFriendGroupModel *defaultFriendGroupModel = [self toolGetMyFriendGroupTypeList:-1].firstObject;
        if (defaultFriendGroupModel && friendList.count > 0) {
            [friendList enumerateObjectsUsingBlock:^(LingIMFriendModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj.ugUuid = defaultFriendGroupModel.ugUuid;
                //仅仅更新好友分组的信息
                [weakSelf toolAddMyFriendOnlyWith:obj];
            }];
        }
        
        //接口更新 好友分组 数据
        [weakSelf requestUpdateFriendGroupListFromServiceOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        }];
        
    } onFailure:onFailure];
}

#pragma mark - 修改 我的好友 所在 好友分组
- (void)updateFriendForFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    __weak typeof(self) weakSelf = self;
    [[NoaIMHttpManager sharedManager] friendGroupUpdateFriendGroupWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        
        NSString *friendID = [NSString stringWithFormat:@"%@", [params objectForKey:@"uguUserUid"]];
        NSString *friendGroupID = [NSString stringWithFormat:@"%@", [params objectForKey:@"uguUgUuid"]];
        LingIMFriendModel *friendModel = [self toolCheckMyFriendWith:friendID];
        if (friendModel) {
            friendModel.ugUuid = friendGroupID;
            //更新好友信息(根据目前的需求暂时使用这个方法，不进行通讯录的更新)
            [weakSelf toolAddMyFriendOnlyWith:friendModel];
            
            //告知 好友分组 发生变化
            [weakSelf.userDelegate imSdkUserFriendGroupChange];
        }
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
    } onFailure:onFailure];
}

#pragma mark - 更新好友分组列表
- (void)requestUpdateFriendGroupListFromServiceOnSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    NSArray *localSectionArr = [self toolGetMyFriendGroupList];
    
    __weak typeof(self) weakSelf = self;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[self myUserID] forKey:@"userUid"];
    if (localSectionArr != nil && localSectionArr.count > 0) {
        [dict setValue:@(self.lastSyncSectionTime) forKey:@"lastSyncTime"];
    }
    [self getFriendGroupListWith:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSArray class]]) {
            //清空本地数据
            NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_SECTION_TIME_KEY, weakSelf.myUserID];
            [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];
            
            //更新好友分组数据
            NSArray *friendGroupArray = (NSArray *)data;
            [friendGroupArray enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                LingIMFriendGroupModel *friendGroupModel = [LingIMFriendGroupModel mj_objectWithKeyValues:obj];
                //delFlag删除标识 0正常；1删除
                if (friendGroupModel.delFlag == 0) {
                    [weakSelf toolUpdateMyFriendGroupWith:friendGroupModel];
                } else {
                    [weakSelf toolDeleteMyFriendGroupWith:friendGroupModel.ugUuid];
                }
              
                //数据处理完毕
                if (idx == friendGroupArray.count - 1) {
                    //告知 好友分组 发生变化
                    [weakSelf.userDelegate imSdkUserFriendGroupChange];
                    if (onSuccess) {
                        onSuccess(data, traceId);
                    }
                }
            }];
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        
        if (onFailure) {
            onFailure(code, msg,traceId);
        }
        
    }];
}

#pragma mark - 获取 分享邀请 相关数据信息
- (void)getFriendShareInviteInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] friendGetShareInviteInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取当前在线好友标识集合
- (void)getFriendGetOnlineStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] friendGetOnlineStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}


@end
