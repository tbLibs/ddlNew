//
//  NoaIMSDKManager+Group.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "NoaIMSDKManager.h"
#import "NoaIMHttpManager+Group.h"
NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Group)

/*
 * 查询群组详情
 * @param params 请求参数{groupId:群组ID,userUid:查询用户ID}
 */
- (void)getGroupInfoWith:(NSDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
 * 创建群聊
 * @param params 创建群聊参数{ownerUid:群主ID ownerNickname:群主昵称 groupMemberParams:[{userUid,nickName}]群成员}
 */
- (void)createGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
 * 群聊列表
 * @param params 请求参数{userUid:查询用户ID,pageNumber:分页(1开头),pageSize:每页数据大小,pageStart:起始索引(0开头)}
 */

- (void)groupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
 * 修改群组名称
 * @param params 请求参数{groupId:群组ID，userUid:操作用户ID,groupName:群名称}
 */

- (void)changeGroupNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
 * 修改群组头像
 * @param params 请求参数{groupId:群组ID，avatar:群头像,userUid:操作用户ID}
 */
- (void)changeGroupAvatarWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
 * 获取群成员列表(全量分页)
 * @param params 请求参数{groupId:群组ID，pageNumber:每页个数,pageSize:页数，pageStart:群头像,userUid:操作用户ID}
 */
- (void)getGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
 * 同步群成员列表(增量不分页获取)
 * @param params 请求参数{groupId:群组ID, lastSyncTime:上传同步数据时间戳, userUid:操作用户ID}
 */
- (void)syncGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 清空群聊 聊天记录
*  @param params 操作参数{groupId:群组ID，userUid:操作用户ID}
*/
- (void)groupClearAllChatMessageWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 退出群聊
*  @param params 操作参数{groupId:群组ID，userUid:操作用户ID}
*/
- (void)groupQuitWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 我在本群的昵称
*  @param params 操作参数{groupId:群组ID，userUid:操作用户ID，groupNickname:用户群内昵称}
*/
- (void)groupMyNicknameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 移除群成员
*  @param params 请求参数{groupId:群组ID，groupMemberUidList:[]移除ID集合,userUid:操作用户ID}
*/
- (void)groupRemoveMemberWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 创建群公告
*  @param params 请求参数:{groupId:群组ID，userUid:创建/修改用户ID,noticeContent:群公告内容,status:公告是否置顶,1:置顶0：取消置顶(默认为0)}
*/
- (void)groupCreateGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改群公告
*  @param params 请求参数:{groupId:群组ID，userUid:创建/修改用户ID,noticeContent:群公告内容,status:公告是否置顶,1:置顶0：取消置顶(默认为0)}
*/
- (void)groupChangeGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 移除群公告
*  @param params 请求参数:{groupId:群组ID，userUid:创建/修改用户ID,noticeContent:群公告内容,status:公告是否置顶,1:置顶0：取消置顶(默认为0)}
*/
- (void)groupDeleteGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 查询群公告
*  @param params 请求参数:{groupId:群组ID，userUid:群成员ID, pageNumber:分页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始)}
*/
- (void)groupCheckGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 查询单条群公告
*  @param params 请求参数:{groupId:群组ID，userUid:群成员ID,noticeId:群公告ID}
*/
- (void)groupCheckOneGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 群公告已读上报(关闭置顶群公告展示)
*  @param params 请求参数:{groupId:群组ID，userUid:群成员ID,noticeId:群公告ID}
*/
- (void)groupReadGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 邀请好友进群
*  @param params 请求参数:{groupId:群组ID，userUid:操作用户ID,inviteDesc:邀请内容,groupMemberParams:[{userUid:被邀请人ID,nickName:被邀请人昵称}]}
*/
- (void)groupInviteFriendWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 查询群禁言详情
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupGetNotalkStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 查询群禁言成员列表
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupGetNotalkListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 群组单人禁言
*  @param params 请求参数:{expireTime:禁言时间,forbidUidList:禁言用户列表，operationType:操作类型0解除禁言1禁言，groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupSetNotalkMemberWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 设置全员禁言
*  @param params 请求参数:{operationType:操作类型0解除禁言1禁言，groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupSetNotalkAllWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 删除群组用户历史消息
* @param params 请求参数:{targetUidList:要删除历史消息的用户ID列表，groupId:群组ID，userUid:操作用户ID，reason`: 删除原因（可选）}
*/
- (void)groupDeleteMemberHistoryMessageWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 转让群主
*  @param params 请求参数:{ownerUid:转让给某人ID，groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupChangeGroupOwnerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 设置/取消群管理员
*  @param params 请求参数:{groupMemberUidList:设置管理员ID，operationType:1设置管理员2取消设置管理员,groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupSetGroupManagerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 解散群组
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupDissolutionGroupWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取群组管理员列表
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupGetManagerListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取当前用户的禁言状态
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupGetUserNotalkStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 查询群成员在本群昵称
*  @param params 请求参数:{groupId:群组ID,userUid:要查询的用户ID}
*/
- (void)groupGetUserNicKNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取生成二维码所需要的内容
*  @param params 请求参数:{content:1:好友可为空2:群组{"groupId":"2323"},type:生成二维码类型1:添加好友二维码2:群组二维码, userUid:用户id}
*/
- (void)UserGetCreatQrcodeContentWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取生成二维码所需要的内容
*  @param params 请求参数:{content:1:好友可为空2:群组{"groupId":"2323"},type:生成二维码类型1:添加好友二维码2:群组二维码, userUid:用户id}
*/
- (void)UserGetTransformQrcodeContentWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 申请加入群聊
*  @param params 请求参数:{adviceStatus:会话是否免打扰,1:开启免打扰0：取消免打扰(默认为1)", applyDesc:申请理由, groupId:群组ID, inviteType:邀请进群类型(4:二维码邀请,2:链接邀请,3:邀请入群,1:面对面入群), inviteUserId:邀请进群用户ID, topStatus:会话是否置顶,1:置顶0：取消置顶(默认为1), userUid:操作用户ID}
*/
- (void)UserApplyJoinGroupWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
* 获取申请进群列表-群管理
*  @param params 请求参数:{ groupId:群组ID, beStatus:审核状态  1：申请 2：通过  4:已进群 5:已经拒绝, userUid:当前用户ID, pageSize:每页数据量, pageNumber:分页-页数}
*/
- (void)groupManagerApplyJoinGroupListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取申请进群列表-群通知
*  @param params 请求参数:{ beStatus:审核状态  1：申请 2：通过  4:已进群 5:已经拒绝, userUid:当前用户ID, pageSize:每页数据量, pageNumber:分页-页数}
*/
- (void)groupNotificationApplyJoinGroupListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 批量(单条)审核入群申请
*  @param params 请求参数:{ verfiyStatus:1:通过 2：拒绝，verfiyUserId:当前用户id, memreqParams:审核用户列表}
 @param memreqParams 请求参数:{ groupId:群id，memreqUuid:申请的唯一标识}
*/
- (void)groupJoinGroupApplyHandleWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 群内禁止私聊
*  @param params 请求参数:{groupId:群组ID,status:是否开启全员禁止私聊(1开启0关闭), userUid:操作用户ID}
*/
- (void)groupSetPrivateChatStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 群内禁止私聊
*  @param params 请求参数:{groupId:群组ID,status:进群验证开关(1开启0关闭), userUid:操作用户ID}
*/
- (void)groupSetJoinGroupStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改全员禁止音视频状态
*  @param params 请求参数:{groupId:群组ID, status:是否开启全员禁止拨打音视频(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupUpdateAudioAndVideoCallStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改 关闭群提示 开关状态
*  @param params 请求参数:{groupId:群组ID, status:是否开启全员禁止拨打音视频(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupUpdateGroupRemindSwitchStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改 群二维码 开关状态
*  @param params 请求参数:{groupId:群组ID, status:群二维码(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupUpdateIsShowQrCodeWith:(NSMutableDictionary *)params
                               onSuccess:(LingIMSuccessCallback)onSuccess
                          onFailure:(LingIMFailureCallback)onFailure;

/*
* 新人查看群历史记录
*  @param params 请求参数:{groupId:群组ID, status:新人查看群历史记录(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupNewMemberCheckHistoryStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取群活跃配置
* @param params 请求参数:{gId:群组ID}
*/
- (void)groupGetActivityLevelConfigWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


/// 获取我的群组列表数据
- (NSArray<LingIMGroupModel *> *)toolGetMyGroupList;

/// 根据群组ID查询群组信息
/// @param groupID 群组ID
- (LingIMGroupModel *)toolCheckMyGroupWith:(NSString *)groupID;

/// 根据群组ID删除数据库内容
/// @param groupID 群组ID
- (BOOL)toolDeleteMyGroupWith:(NSString *)groupID;

/// 更新或新增群组到表
/// @param model 群组信息
- (BOOL)toolInsertOrUpdateGroupModelWith:(LingIMGroupModel *)model;

#pragma mark - 批量 新增/更新群组信息
/// @param list 批量群组信息数组
- (BOOL)toolBatchInsertOrUpdateGroupModelWith:(NSArray <LingIMGroupModel *> *)list;

/// 根据搜索内容查询群组数据
/// @param searchStr 搜索内容
- (NSArray <LingIMGroupModel *> *)toolSearchMyGroupWith:(NSString *)searchStr;

/// 清空我的群组列表信息
- (BOOL)toolDeleteAllMyGroup;

/*
* 获取群组机器人
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupGetRobotListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
* 获取群组机器人数量
*  @param params 请求参数:{groupId:群组ID,userUid:操作用户ID}
*/
- (void)groupGetRobotCountWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改群活跃展示开关
* @param params 请求参数:{groupId:群组ID, isActiveEnabled:是否启用群活跃功能（0：关闭，1：开启）, userUid:用户ID不可为空}
*/
- (void)groupUpdateActivityLevelEnableStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 群成员活跃积分分页列表-增量
* @param params 请求参数:{groupId:群组ID, "userUid":"",  设置消息置顶的用户ID, pageNumber:起始页(从1开始), pageSize:每页数据大小}
*/
- (void)groupGetMemberActiviteScoreWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 设置/取消 消息置顶
* @param params 请求参数:{groupId:群组ID, smsgId:需要置顶的服务端消息ID, msgStatus:1 必传 消息状态 1 全局置顶，2用户个人置顶，3取消全局置顶，4取消个人置顶, userUid:操作用户ID}
*/
- (void)groupSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


@end

NS_ASSUME_NONNULL_END
