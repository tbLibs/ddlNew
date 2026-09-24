//
//  NoaIMHttpManager+Group.h
//  NoaChatSDKCore
//
//  Created by Apple on 2026/12/20.
//

#import <Foundation/Foundation.h>
#import "NoaIMHttpManager.h"
NS_ASSUME_NONNULL_BEGIN
//查询群组详情
#define Get_Group_Info                  @"/biz/group/getGroupInfo"
//创建群聊
#define Create_Group_Url                @"/biz/group/createGroup"
//群聊列表
#define Group_List_Url                  @"/biz/group/list"
//修改群组名称
#define Group_Change_Group_Name         @"/biz/group/groupName"
//修改群组头像
#define Group_Change_Group_Avatar       @"/biz/group/updateGroupAvatar"
//获取群成员列表(全量分页)
#define Group_Get_Group_MemberList      @"/biz/groupMember/queryListByGroupId"
//同步群成员列表(增量不分页)
#define Group_Sync_Group_MemberList     @"/biz/groupMember/syncGroupMembers"
//清空群聊 聊天记录
#define Group_Clear_Group_Msg_Url       @"/biz/group/clearGroupMsg"
//退出群聊
#define Group_Quit_Group_Url            @"/biz/group/quitGroup"
//我在本群的昵称
#define Group_My_Nickname_Url           @"/biz/group/groupNickName"
//移除群成员
#define Group_Remove_Group_Member       @"/biz/group/kickGroupMember"
//创建群公告
#define Group_Create_Group_Notice       @"/biz/group/createGroupNotice"
//修改群公告
#define Group_Change_Group_Notice       @"/biz/group/updateGroupNotice"
//删除群公告
#define Group_Delete_Group_Notice       @"/biz/group/delGroupNotice"
//查询群公告
#define Group_Check_Group_Notice        @"/biz/group/groupNotice"
//查询单条群公告
#define Group_Check_One_Group_Notice    @"/biz/group/groupNoticeOne"
//群公告已读上报(目前仅在点击群公告置顶控件的关闭按钮时使用)
#define Group_Read_Group_Notice         @"/biz/group/groupNoticeRead"
//邀请好友进群
#define Group_Invite_Friend             @"/biz/group/groupMemberInviteJoin"
//查询群禁言详情
#define Group_Get_Notalk_State          @"/biz/group/getGroupForbidState"
//群组单人禁言
#define Group_Set_Notalk_Member         @"/biz/group/saveGroupMemberForbidV2"
//是否开启全员禁言
#define Group_Set_Notalk_All            @"/biz/group/groupForbidSendMsg"
// 群组删除消息
#define Group_Delete_User_Message       @"/biz/group/deleteGroupMemberHistory"
//转让群主
#define Group_Change_Group_Owner        @"/biz/group/groupTransferOwner"
//设置/取消群管理员
#define Group_Set_Group_Manager         @"/biz/group/groupAdminMember"
//解散群组
#define Group_Dissolution_Group         @"/biz/group/dissolutionGroup"
//查询群组禁言名单列表
#define Group_Get_Notalk_List           @"/biz/group/findAllForbid"
//查询群组管理员列表
#define Group_Get_Manager_List          @"/biz/groupMember/listGroupManager"
//查询群组机器人列表
#define Group_Get_Robots_List          @"/biz/robots/list"
//查询群组机器人数量
#define Group_Get_Robots_Count          @"/biz/robots/count"
//查询当前用户在群组中禁言状态
#define Group_Get_User_Notalk_State     @"/biz/group/groupForbid"
//查询群成员在本群昵称
#define Group_Get_User_NickName         @"/biz/groupMember/getMemberByGidUid"
//获取生成二维码是的内容，然后由App端根据内容生产二维码
#define Group_Creat_Qrcode_Content_Url  @"/biz/scan/createScanContent/v2"
//识别扫一扫二维码内容信息
#define Transform_Qrcode_Content_Url    @"biz/scan/group/readScanContent"
//申请加入群聊
#define Apply_Join_Group_Url            @"/biz/group/groupMemberApplyJoin"
//获取申请进群列表-群管理
#define Group_Manager_Apply_Join_List_Url   @"/biz/group/groupMemberReqUserId"
//获取申请进群列表-群通知
#define Group_Notification_Apply_Join_List_Url  @"/biz/group/groupMemberReqUserId"
//批量(单条)审核入群申请
#define Group_Apply_Join_Handle_Url     @"/biz/group/groupMemberReqVerifyBatch"
//群内禁止私聊
#define Group_Private_Chat_Status_Url   @"/biz/group/groupPrivateChatStatus"
//群聊邀请确认
#define Group_Join_Group_Status_Url     @"/biz/group/joinGroupStatus"
//修改全员禁止音视频状态
#define Group_Update_Audio_Video_Call_Url     @"/biz/group/updateGroupNetCallStatus"
//修改 关闭群提示 开关状态
#define Group_Update_Group_Remind_Swich_Url    @"/biz/group/updateGroupMessageInformStatus"
//修改 群二维码
#define Group_Update_Is_ShowQrCode_Url       @"/biz/group/groupQrcodeShow"
//新人查看群聊天历史
#define Group_isShowHistory_Url    @"/biz/group/isShowHistory"
//获取群活跃配置
#define Group_Get_Activity_Config_Url    @"/biz/group/activity/config/get"
//修改群活跃展示开关
#define Group_Update_Activity_Enable_Status_Url         @"/biz/group/groupActivityShow"
//群成员活跃积分分页列表-增量
#define Group_Get_Member_Activite_Score_Url             @"/biz/groupMember/activity/page"
//设置/取消 消息置顶
#define Group_Set_Msg_Top_Url             @"/biz/group/setMsgTop"

@interface NoaIMHttpManager (Group)

/*
 * 查询群组详情
 * @param params 请求参数{groupId:群组ID,userUid:查询用户ID}
 */
- (void)getGroupInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
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
 * @param params 请求参数{groupId:群组ID，pageNumber:每页个数,pageSize:页数(传-1默认获取全部成员)，pageStart:群头像,userUid:操作用户ID}
 */
- (void)getGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
 * 同步群成员列表(增量不分页)
 * @param params 请求参数{groupId:群组ID, lastSyncTime:上传同步时间戳, userUid:操作用户ID}
 */
- (void)syncGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
 * 获取群机器人列表
 * @param params 请求参数{groupId:群组ID，pageNumber:每页个数,pageSize:页数(传-1默认获取全部成员)，pageStart:群头像,userUid:操作用户ID}
 */
-(void)groupGetRobotListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
 * 获取群机器人数量
 * @param params 请求参数{groupId:群组ID，pageNumber:每页个数,pageSize:页数(传-1默认获取全部成员)，pageStart:群头像,userUid:操作用户ID}
 */
-(void)groupGetRobotCountWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

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
*  @param params 请求参数:{groupId:群组ID，userUid:群成员ID, noticeId:群公告ID}
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
* 解散群组
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
- (void)groupGetUserNickNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取生成二维码的内容(拿到该内容后，由App端生成对应的二维码)
*  @param params 请求参数:{content:1:好友可为空2:群组{"groupId":"2323"},type:生成二维码类型1:添加好友二维码2:群组二维码, userUid:用户id}
*/
- (void)getCreatQrCodeContent:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 通过扫码获取到的字符串向后台获取扫码后跳转的真实数据
*  @param params 请求参数:{content:二维码扫描结果的字符串", userUid:用户id}
*/
- (void)getScanQrContentTransformData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 申请加入群聊
*  @param params 请求参数:{adviceStatus:会话是否免打扰,1:开启免打扰0：取消免打扰(默认为1)", applyDesc:申请理由, groupId:群组ID, inviteType:邀请进群类型(4:二维码邀请,2:链接邀请,3:邀请入群,1:面对面入群), inviteUserId:邀请进群用户ID, topStatus:会话是否置顶,1:置顶0：取消置顶(默认为1), userUid:操作用户ID}
*/
- (void)groupApplyJoinWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取申请进群列表-群管理
*  @param params 请求参数:{ groupId:群组ID, beStatus:审核状态  1：申请 2：通过  4:已进群 5:已经拒绝, userUid:当前用户ID, pageSize:每页数据量, pageNumber:分页-页数}
*/
- (void)groupManagerApplyJoinListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取申请进群列表-群通知
*  @param params 请求参数:{ beStatus:审核状态  1：申请 2：通过  4:已进群 5:已经拒绝, userUid:当前用户ID, pageSize:每页数据量, pageNumber:分页-页数}
 */
- (void)groupNotificationApplyJoinListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 批量(单条)审核入群申请
*  @param params 请求参数:{ verfiyStatus:1:通过 2：拒绝，verfiyUserId:当前用户id, memreqParams:审核用户列表}
 @param memreqParams 请求参数:{ groupId:群id，memreqUuid:申请的唯一标识}
*/
- (void)groupGroupJoinApplyHandleWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


/*
* 群内禁止私聊
*  @param params 请求参数:{groupId:群组ID, status:是否开启全员禁止私聊(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupPrivateChatStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 进群验证开关
*  @param params 请求参数:{groupId:群组ID, status:进群验证开关(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupJoinGroupStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改全员禁止音视频状态
*  @param params 请求参数:{groupId:群组ID, status:是否开启全员禁止拨打音视频(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupUpdateAudioVideoCallStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改 关闭群提示 开关状态
*  @param params 请求参数:{groupId:群组ID, status:是否开启全员禁止拨打音视频(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupUpdateGroupRemindSwitchStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 修改是否展示群二维码
/*
/// @param groupId 群组id
/// @param isShowQrCode 是否展示群二维码
/// @param userUid 用户id
 */
- (void)groupUpdateIsShowQrCodeWith:(NSMutableDictionary *)params
                               onSuccess:(LingIMSuccessCallback)onSuccess
                               onFailure:(LingIMFailureCallback)onFailure;

/*
* 新人查看群聊天历史
*  @param params 请求参数:{groupId:群组ID, status:新人查看群聊天历史(1开启，0关闭), userUid:操作用户ID}
*/
- (void)groupNewMemberCheckHistoryStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 获取群活跃配置
* @param params 请求参数:{gId:群组ID}
*/
- (void)groupGetActivityLevelConfigWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 修改群活跃展示开关
* @param params 请求参数:{groupId:群组ID, isActiveEnabled:是否启用群活跃功能（0：关闭，1：开启）, userUid:用户ID不可为空}
*/
- (void)groupUpdateActivityLevelEnableStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/*
* 群成员活跃积分分页列表-增量
* @param params 请求参数:{groupId:群组ID, lastSyncTime:最后一次同步时间, pageNumber:起始页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始)}
*/
- (void)groupGetMemberActiviteScoreWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/*
* 设置/取消 消息置顶
* @param params 请求参数:{groupId:群组ID, msgId:消息ID, status:置顶状态(1:置顶,0:取消置顶), userUid:操作用户ID}
*/
- (void)groupSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


@end

NS_ASSUME_NONNULL_END

