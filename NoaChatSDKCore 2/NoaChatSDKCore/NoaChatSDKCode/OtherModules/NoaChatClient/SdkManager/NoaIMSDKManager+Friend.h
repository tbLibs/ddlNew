//
//  NoaIMSDKManager+Friend.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "NoaIMSDKManager.h"

@class LingIMFriendModel;

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Friend)

/// 获取我的好友列表数据
- (NSArray <LingIMFriendModel *> *)toolGetMyFriendList;

/// 获取我的好友列表数据（不包含已注销账号）
- (NSArray<LingIMFriendModel *> *)toolGetMyFriendListOffLogout;

/// 根据用的ID查询是否是我的好友
/// @param userID 用户ID
- (LingIMFriendModel *)toolCheckMyFriendWith:(NSString *)userID;

/// 根据用的ID查询是否是我的好友（不包含已注销账号）
/// @param userID 用户ID
- (LingIMFriendModel *)toolCheckMyFriendWithOffLogout:(NSString *)userID;

/// 根据好友ID删除数据库内容
/// @param myFriendID 好友ID
- (BOOL)toolDeleteMyFriendWith:(NSString *)myFriendID;

/// 新增好友信息，此方法会有代理回调
/// @param model 好友信息
- (BOOL)toolAddMyFriendWith:(LingIMFriendModel *)model;

/// 新增好友信息，此方法不会触发代理回调
/// @param model 好友信息
- (BOOL)toolAddMyFriendOnlyWith:(LingIMFriendModel *)model;

/// 更新好友信息
/// @param model 好友信息
- (BOOL)toolUpdateMyFriendWith:(LingIMFriendModel *)model;

/// 批量 更新好友信息(只更新数据库)
/// @param model 好友信息
- (BOOL)toolBacthDBUpdateMyFriendWith:(NSArray <LingIMFriendModel *> *)list;

/// 根据搜索内容，查询好友
/// @param searchStr 搜索内容
- (NSArray *)toolSearchMyFriendWith:(NSString *)searchStr;

/// 更新好友申请红点个数
/// @param friendApplyCount 红点个数
- (void)toolUpdateFriendApplyCount:(NSInteger)friendApplyCount;

/// 获取好友申请红点个数
- (NSInteger)toolFriendApplyCount;

/// 清空我的好友列表信息
- (BOOL)toolDeleteAllMyFriend;

#pragma mark - 好友分组模块
/// 好友分组数据 新增
/// @param friendGroupModel 好友分组信息
- (BOOL)toolAddMyFriendGroupWith:(LingIMFriendGroupModel *)friendGroupModel;
/// 好友分组数据 更新
/// @param friendGroupModel 好友分组信息
- (BOOL)toolUpdateMyFriendGroupWith:(LingIMFriendGroupModel *)friendGroupModel;

/// 删除好友分组
/// @param friendGroupID 好友分组ID
- (BOOL)toolDeleteMyFriendGroupWith:(NSString *)friendGroupID;

/// 获取某个好友分组信息
/// @param friendGroupID 好友分组ID
- (LingIMFriendGroupModel *)toolCheckMyFriendGroupWith:(NSString *)friendGroupID;

/// 获取我的 好友分组 列表
- (NSArray <LingIMFriendGroupModel *> *)toolGetMyFriendGroupList;

/// 获取我的 某个类型的 好友分组 列表
/// - Parameter friendGroupType: 好友分组类型
- (NSArray <LingIMFriendGroupModel *> *)toolGetMyFriendGroupTypeList:(NSInteger)friendGroupType;

/// 删除我的全部 好友分组 列表
- (BOOL)toolDeleteAllMyFriendGroup;

/// 获取某个 好友分组 下的 好友列表(所有的，包含已注销账号)
/// @param friendGroupID 好友分组ID
- (NSArray <LingIMFriendModel *> *)toolGetMyFriendGroupFriendsWith:(NSString *)friendGroupID;

/// 获取某个 好友分组 下的 好友列表(所有的，不包含已注销账号)
/// @param friendGroupID 好友分组ID
- (NSArray <LingIMFriendModel *> *)toolGetMyFriendGroupFriendsOffLogoutWith:(NSString *)friendGroupID;

#pragma mark - ------ 接口操作 ------
/// 从服务器获取黑名单列表
/// @param params 操作参数 {userUid:当前用户uid}
- (void)getBlackListFromServerWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 将用户加入黑名单
/// @param params 操作参数 {userUid:当前用户uid status:1加入黑名单 friendUserUid:被加入黑名单用户uid }
- (void)addUserToBlackListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 将用户移出黑名单
/// @param params 操作参数 {userUid:当前用户uid status:0移出黑名单 friendUserUid:被加入黑名单用户uid }
- (void)removeUserFromBlackListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取用户的拉黑状态
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:好友uid }
- (void)getUserBlackStateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 从服务端获取好友通讯录列表
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageStart:起始位置0 pageSize:每页返回个数100}
- (void)getContactsFromServerWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 好友验证(是否是我的好友)
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:需要验证的用户uid}
- (void)checkMyFriendWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 从服务端获取好友申请列表
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageSize:每页返回个数100 pageStart:起始位置0}
- (void)getFriendApplyListFromServerWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 好友邀请信息增量列表查询
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageSize:每页返回个数100 pageStart:起始位置0}
- (void)getFriendSyncReqListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 添加好友，发起好友申请
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:被添加好友uid}
- (void)addContactWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 移除好友，删除我的某个好友
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:被删除好友uid}
- (void)deleteContactWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 同意确认对方发来的好友申请
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:发起好友申请用户uid}
- (void)confirmFriendApplyWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


/// 根据好友的uid获取好友的信息
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:好友uid}
- (void)getFriendInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改好友备注描述
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:好友uid remark:备注 descRemark:描述}
- (void)friendSetFriendRemarkAndDesWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

#pragma mark - 通讯录 - 好友分组模块
/// 查询好友分组列表数据
/// @param params 操作参数 {userUid:当前用户uid}
- (void)getFriendGroupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 创建好友分组
/// @param params 操作参数 {userUid:当前用户uid ugName:好友分组名称 ugOrder:好友分组排序位置}
- (void)createFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改好友分组(好友分组名称/排序)
/// @param params 操作参数 {userUid:当前用户uid ugUuid:好友分组ID ugName:好友分组名称 ugOrder:好友分组排序位置}
- (void)updateFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除好友分组
/// @param params 操作参数 {userUid:当前用户uid ugUuid:好友分组ID}
- (void)deleteFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改 我的好友 所在 好友分组
/// @param params 操作参数 {userUid:当前用户uid uguUgUuid:好友分组ID uguUserUid:好友ID}
- (void)updateFriendForFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 更新好友分组列表
- (void)requestUpdateFriendGroupListFromServiceOnSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取 分享邀请 相关数据信息
/// @param params 操作参数 {userUid:当前用户uid}
- (void)getFriendShareInviteInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取当前在线好友标识集合
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageSize:每页返回个数100 pageStart:起始位置0}
- (void)getFriendGetOnlineStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
