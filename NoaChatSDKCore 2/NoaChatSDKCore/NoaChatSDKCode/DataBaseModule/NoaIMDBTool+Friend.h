//
//  NoaIMDBTool+Friend.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "NoaIMDBTool.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (Friend)

/// 获取我的好友列表数据(所有的，包含已注销账号)
- (NSArray<LingIMFriendModel *> *)getMyFriendList;

/// 获取我的好友列表数据(所有的，不包含已注销账号)
- (NSArray<LingIMFriendModel *> *)getMyFriendListOffLogout;

/// 根据用户ID查询是否是我的好友
/// @param userID 用户ID
- (LingIMFriendModel *)checkMyFriendWith:(NSString *)userID;

/// 根据用的ID查询是否是我的好友(不包含已注销账号)
/// @param userID 用户ID
- (LingIMFriendModel *)checkMyFriendWithOffLogout:(NSString *)userID;

/// 根据好友ID删除数据库内容
/// @param myFriendID 好友ID
- (BOOL)deleteMyFriendWith:(NSString *)myFriendID;

/// 根据搜索内容查询好友数据
/// @param searchStr 搜索内容
- (NSArray <LingIMFriendModel *> *)searchMyFriendWith:(NSString *)searchStr;

/// 更新好友申请红点个数
/// @param friendApplyCount 红点个数
- (void)updateFriendApplyCount:(NSInteger)friendApplyCount;

/// 获取好友申请红点个数
- (NSInteger)friendApplyCount;

#pragma mark - 好友分组模块
/// 好友分组数据 新增/更新
/// - Parameter friendGroupModel: 好友分组数据
- (BOOL)insertFriendGroupWith:(LingIMFriendGroupModel *)friendGroupModel;

/// 删除好友分组
/// - Parameter friendGroupID: 好友分组ID
- (BOOL)deleteMyFriendGroupWith:(NSString *)friendGroupID;

/// 获取某个好友分组信息
/// - Parameter friendGroupID: 好友分组ID
- (LingIMFriendGroupModel *)checkMyFriendGroupWith:(NSString *)friendGroupID;

/// 获取我的 好友分组 列表
- (NSArray <LingIMFriendGroupModel *> *)getMyFriendGroupList;

/// 获取我的 某个好友分组类型的 好友分组 列表
/// - Parameter friendGroupType: 好友分组类型
- (NSArray <LingIMFriendGroupModel *> *)getMyFriendGroupTypeList:(NSInteger)friendGroupType;

/// 获取某个 好友分组 下的 好友列表(所有的，包含已注销账号)
/// - Parameter friendGroupID: 好友分组ID
- (NSArray<LingIMFriendModel *> *)getMyFriendGroupFriendsWith:(NSString *)friendGroupID;

/// 获取某个 好友分组 下的 好友列表(所有的，不包含已注销账号)
/// - Parameter friendGroupID: 好友分组ID
- (NSArray<LingIMFriendModel *> *)getMyFriendGroupFriendsOffLogoutWith:(NSString *)friendGroupID;
@end

NS_ASSUME_NONNULL_END
