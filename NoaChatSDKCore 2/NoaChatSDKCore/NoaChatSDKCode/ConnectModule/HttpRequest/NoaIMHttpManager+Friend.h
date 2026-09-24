//
//  NoaIMHttpManager+Friend.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/20.
//

//获取黑名单列表
#define Friend_Friend_Black_List_Url         @"/biz/friend/friendBlackList"
//加入、移除 黑名单
#define Friend_Friend_Black_Url              @"/biz/friend/friendBlack"
//获取好友拉黑状态
#define Friend_Black_State_Url               @"/biz/friend/blackState"
//好友列表
#define Friend_List_Url                      @"/biz/friend/list"
//校验是否是好友
#define Friend_Check_Friend_Url              @"/biz/friend/checkFriend"
//好友申请列表
#define Friend_Friend_Req_List_Url           @"/biz/friend/v2/friendReqList"
//好友邀请信息增量列表查询
#define Friend_Sync_Req_List_Url             @"/biz/friend/syncReqList"
//发送好友邀请
#define Friend_Add_Friend_Url                @"/biz/friend/addFriend"
//同意好友申请
#define Friend_Friend_Req_Verify_Url         @"/biz/friend/friendReqVerify"
//删除好友
#define Friend_Delete_Friend_Url             @"/biz/friend/deleteFriend"
//获取好友详情
#define Friend_Detail_Url                    @"/biz/friend/detailByUserUidAndFriendUserUid"
//修改好友备注描述
#define Friend_Set_RemarkDes_Url             @"/biz/friend/friendRemarkDesc"
//好友分组相关接口
//查询所有分组
#define Friend_Group_GroupList_Url           @"/biz/userGroup/selectUserGroup"
//创建好友分组
#define Friend_Group_CreateGroup_Url         @"/biz/userGroup/createUserGroup"
//修改好友分组
#define Friend_Group_UpdateGroup_Url         @"/biz/userGroup/updateUserGroup"
//删除好友分组
#define Friend_Group_DeleteGroup_Url         @"/biz/userGroup/deleteUserGroup"
//修改好友所在好友分组
#define Friend_Group_UpdateFriendGroup_Url   @"/biz/userGroupUser/updateUserGroupUser"
//分享邀请
#define Friend_Get_Share_Invite_Info_Url     @"/biz/invitation/userInfo"
//获取当前在线好友标识集合
#define Friend_Get_Online_Status_Url         @"/biz/friend/onlineFriendIds"


#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (Friend)

/// 获取黑名单列表
/// @param params 操作参数 {userUid:当前用户uid}
- (void)friendGetBlackListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 将用户加入黑名单
/// @param params 操作参数 {userUid:当前用户uid status:1加入黑名单 friendUserUid:被加入黑名单用户uid }
- (void)friendAddBlackWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 将用户移出黑名单
/// @param params 操作参数 {userUid:当前用户uid status:0移出黑名单 friendUserUid:被加入黑名单用户uid }
- (void)friendRemoveBlackWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 好友拉黑状态
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:好友uid }
- (void)friendCheckBlackStateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取好友通讯录列表
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageStart:起始位置0 pageSize:每页返回个数100}
- (void)friendGetListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 好友验证(是否是我的好友)
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:需要验证的用户uid}
- (void)friendCheckWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取好友申请列表
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageSize:每页返回个数100 pageStart:起始位置0}
- (void)friendGetApplyListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 好友邀请信息增量列表查询
/// @param params 操作参数 {userUid:当前用户uid}
- (void)friendSyncReqListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 添加好友，发起好友申请
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:被添加好友uid}
- (void)friendAddContactWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 同意好友申请
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:发起好友申请用户uid}
- (void)friendApplyConfirmWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 移除好友
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:被删除好友uid}
- (void)friendDeleteContactWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取某个好友的信息
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:好友uid}
- (void)friendGetFriendInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改好友备注描述
/// @param params 操作参数 {userUid:当前用户uid friendUserUid:好友uid remark:备注 descRemark:描述}
- (void)friendSetFriendRemarkAndDesWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

#pragma mark - 通讯录 - 好友分组模块
/// 查询好友分组列表数据
/// @param params 操作参数 {userUid:当前用户uid}
- (void)friendGroupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 创建好友分组
/// @param params 操作参数 {userUid:当前用户uid ugName:好友分组名称 ugOrder:好友分组排序位置}
- (void)friendGroupCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改好友分组(好友分组名称/排序)
/// @param params 操作参数 {userUid:当前用户uid ugUuid:好友分组ID ugName:好友分组名称 ugOrder:好友分组排序位置}
- (void)friendGroupUpdateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除好友分组
/// @param params 操作参数 {userUid:当前用户uid ugUuid:好友分组ID}
- (void)friendGroupDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改 我的好友 所在 好友分组
/// @param params 操作参数 {userUid:当前用户uid uguUgUuid:好友分组ID uguUserUid:好友ID}
- (void)friendGroupUpdateFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

///  获取分享邀请信息
/// @param params 操作参数 { userUid:当前用户uid }
- (void)friendGetShareInviteInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

///  获取当前在线好友标识集合
/// @param params 操作参数 {userUid:当前用户uid pageNumber:分页1开始 pageSize:每页返回个数100 pageStart:起始位置0}
- (void)friendGetOnlineStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
