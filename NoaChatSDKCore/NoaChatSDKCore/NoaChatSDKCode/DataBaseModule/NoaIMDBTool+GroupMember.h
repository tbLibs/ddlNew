//
//  NoaIMDBTool+Group.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "NoaIMDBTool.h"
#import "LingIMGroupMemberModel.h"
NS_ASSUME_NONNULL_BEGIN

//群成员接口同步成功回调
typedef void(^syncGroupMemberSuccess)(void);
//群成员接口同步失败回调
typedef void(^syncGroupMemberFaiule) (void);

//群成员活跃等级积分同步成功回调
typedef void(^syncGroupMemberActiviteScoreSuccess)(void);
//群成员活跃等级积分同步失败回调
typedef void(^syncGroupMemberActiviteScoreFaiule) (void);

@interface NoaIMDBTool (GroupMember)
/// 创建群成员表并且缓存群成员数据
/// @param groupId 群id
/// @param userId 当前登录用户Id
- (void)creatGroupMemberTableAndCacheGroupMemberWithGroupId:(NSString *)groupId userId:(NSString *)userId syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule;

/// 同步群成员活跃积分并且缓存群成员数据表里
/// @param groupId 群id
- (void)syncGroupMemberActiviteScoreAndCacheScoreWithGroupId:(NSString *)groupId lastSyncTime:(long long)lastSyncTime page:(NSInteger)page tempDataList:(NSMutableArray *)tempDataList syncActiviteScoreSuccess:(syncGroupMemberActiviteScoreSuccess)syncActiviteScoreSuccess syncActiviteScoreFaiule:(syncGroupMemberActiviteScoreFaiule)syncActiviteScoreFaiule;

//增量不分页同步群成员列表数据
- (void)syncGroupMemberListWithGroupId:(NSString *)groupId userId:(NSString *)userId groupMemberTabName:(NSString *)groupMemberTabName groupInfoModel:(LingIMGroupModel *)groupInfoModel syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule ;

/// 查询当前表中所有的群成员数据
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getAllMemberWithTabName:(NSString *)tabName;

/// 查询当前表里群成员中 群主和管理员 信息
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getGroupOwnerAndManagerWithTabName:(NSString *)tabName;

/// 查询当前表里群成员 除了群主
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupMemberExceptOwnerWith:(NSString *)tabName;

/// 查询当前表里群成员中 群主信息
/// @param tabName 群名称
- (LingIMGroupMemberModel *)getGroupOwnerWithTabName:(NSString *)tabName exceptUserId:(NSString *)exceptUserId;

/// 查询当前表里群成员中 群管理 信息  role: 1管理员
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getGroupManagerWithTabName:(NSString *)tabName exceptUserId:(NSString *)exceptUserId;

/// 查询当前表里群成员中 普通群成员 信息  role: 0普通群成员 筛出掉群机器人
/// @param tabName 群名称
- (NSArray <LingIMGroupMemberModel *> *)getGroupNomalMemberWithTabName:(NSString *)tabName exceptUserId:(NSString *)exceptUserId;

/// 根据群成员ID查询群成员
/// @param tabName 群名称
/// @param memberId 群成员ID
- (LingIMGroupMemberModel *)checkGroupMemberWithTabName:(NSString *)tabName memberId:(NSString *)memberId;

/// 根据表名称、群成员id更新或新增群成员
/// @param tabName 群名称
/// @param memberModel 群成员
- (BOOL)insertOrUpdateGroupMemberModelWithTabName:(NSString *)tabName memberModel:(LingIMGroupMemberModel *)memberModel;

/// 删除群成员表中所有数据
/// @param tabName 群名称
- (BOOL)deleteAllGroupMemberWithTabName:(NSString *)tabName;

/// 批量 更新或新增群成员
/// @param tabName 群名称
/// @param memberList 新的群成员list
- (BOOL)insertOrUpdateMultiGroupMemberModelWithTabName:(NSString *)tabName memberList:(NSArray <LingIMGroupMemberModel *> *)memberList;


/// 根据群组ID删除数据库内容
/// @param memberId 群组ID
- (BOOL)deleteGroupMemberWithTabName:(NSString *)tabName memberId:(NSString *)memberId;

/// 根据表名称+ 群成员UserId / nickName / nickNameInGroup / remark 查询群成员
/// @param tabName 群名称
/// @param searchContent 搜索内容
- (NSArray <LingIMGroupMemberModel *> *)checkGroupMemberWithTabName:(NSString *)tabName searchContent:(NSString *)searchContent exceptUserId:(NSString *)exceptUserId;


@end

NS_ASSUME_NONNULL_END
