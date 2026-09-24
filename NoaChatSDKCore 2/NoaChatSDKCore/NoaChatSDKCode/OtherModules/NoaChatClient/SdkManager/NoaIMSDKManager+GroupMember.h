//
//  NoaIMSDKManager+GroupMember.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/21.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (GroupMember)

/// 创建群成员表并且缓存群成员数据
/// @param groupID 群id
- (void)imSdkCreatSaveGroupMemberTableWith:(NSString *)groupID syncGroupMemberSuccess:(syncGroupMemberSuccess)syncGroupMemberSuccess syncGroupMemberFaiule:(syncGroupMemberFaiule)syncGroupMemberFaiule;

////群成员活跃积分分页列表-增量
/// @param groupID 群id
- (void)imSdkGetGroupMemberActiviteScoreTableWith:(NSString *)groupID syncMemberActiviteScoreSuccess:(syncGroupMemberActiviteScoreSuccess)syncGroupMemberSuccess syncMemberActiviteScoreFaiule:(syncGroupMemberActiviteScoreFaiule)syncGroupMemberFaiule;

/// 查询当前群中 所有的 群成员 数据
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetAllGroupMemberWith:(NSString *)groupID;

/// 查询当前群中 所有的 群成员里 群主和管理的数据
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupOwnerAndManagerWith:(NSString *)groupID;

/// 查询当前群中 所有的 群成员里 去除掉群主
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupMemberExceptOwnerWith:(NSString *)groupID;

/// 查询当前群中  群成员里群主
/// @param groupID 群ID
- (LingIMGroupMemberModel *)imSdkGetGroupOwnerWith:(NSString *)groupID exceptUserId:(NSString *)exceptUserId;

/// 查询当前群中  群成员里管理员
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGrouManagerWith:(NSString *)groupID exceptUserId:(NSString *)exceptUserId;

/// 查询当前群中  群成员里普通群成员(去除掉群主和管理员)
/// @param groupID 群ID
- (NSArray <LingIMGroupMemberModel *> *)imSdkGetGroupNomalMemberWith:(NSString *)groupID exceptUserId:(NSString *)exceptUserId;
   
/// 根据 群成员ID 查询群成员
/// @param memberID 群成员ID
/// @param groupID 群ID
- (LingIMGroupMemberModel *)imSdkCheckGroupMemberWith:(NSString *)memberID groupID:(NSString *)groupID;

/// 新增或更新 某个群的 群成员信息
/// @param memberModel 群成员
/// @param groupID 群ID
- (BOOL)imSdkInsertOrUpdateGroupMember:(LingIMGroupMemberModel *)memberModel groupID:(NSString *)groupID;

/// 删除某个群的群成员
/// @param memberID 群成员ID
/// @param groupID 群ID
- (BOOL)imSdkDeleteGroupMemberWith:(NSString *)memberID groupID:(NSString *)groupID;

@end

NS_ASSUME_NONNULL_END
