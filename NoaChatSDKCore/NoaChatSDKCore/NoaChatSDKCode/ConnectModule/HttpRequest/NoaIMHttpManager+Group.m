//
//  NoaIMHttpManager+Group.m
//  NoaChatSDKCore
//
//  Created by Apple on 2026/12/20.
//

#import "NoaIMHttpManager+Group.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Group)

#pragma mark - 查询群组详情
- (void)getGroupInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Get_Group_Info Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Get_Group_Info parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 创建群聊
- (void)createGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Create_Group_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Create_Group_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 群聊列表
- (void)groupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 修改群组名称
- (void)changeGroupNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Change_Group_Name Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Change_Group_Name parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 修改群组头像
- (void)changeGroupAvatarWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Change_Group_Avatar Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Change_Group_Avatar parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 获取群成员列表(全量分页)
- (void)getGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Group_MemberList Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_Group_MemberList parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 同步群成员列表(增量不分页)
- (void)syncGroupMemberListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Sync_Group_MemberList Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Sync_Group_MemberList parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 清空群聊 聊天记录
- (void)groupClearAllChatMessageWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Clear_Group_Msg_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Clear_Group_Msg_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 退出群聊
- (void)groupQuitWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Quit_Group_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Quit_Group_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 我在本群的昵称

- (void)groupMyNicknameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_My_Nickname_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_My_Nickname_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 移除群成员
- (void)groupRemoveMemberWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Remove_Group_Member Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Remove_Group_Member parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -创建群公告
- (void)groupCreateGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Create_Group_Notice Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Create_Group_Notice parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -移除群公告
- (void)groupDeleteGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Delete_Group_Notice Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Delete_Group_Notice parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 修改群公告
- (void)groupChangeGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Change_Group_Notice Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Change_Group_Notice parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询群公告
- (void)groupCheckGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Check_Group_Notice Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Check_Group_Notice parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询单条群公告
- (void)groupCheckOneGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Check_One_Group_Notice Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Check_One_Group_Notice parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群公告已读上报(关闭置顶群公告展示)
- (void)groupReadGroupNoticeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Read_Group_Notice Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Read_Group_Notice parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 邀请好友进群
- (void)groupInviteFriendWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Invite_Friend Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Invite_Friend parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询群禁言详情
- (void)groupGetNotalkStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Notalk_State Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_Notalk_State parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

/// 查询群禁言成员列表
/// 传参:{groupId:群组ID,userUid:操作用户ID}
- (void)groupGetNotalkListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Notalk_List Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_Notalk_List parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群组单人禁言
- (void)groupSetNotalkMemberWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Set_Notalk_Member Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Set_Notalk_Member parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 删除用户历史消息
- (void)groupDeleteMemberHistoryMessageWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Delete_User_Message Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Delete_User_Message parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 设置全员禁言
- (void)groupSetNotalkAllWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Set_Notalk_All Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Set_Notalk_All parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 转让群主
- (void)groupChangeGroupOwnerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Change_Group_Owner Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Change_Group_Owner parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 设置/取消群管理员
- (void)groupSetGroupManagerWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Set_Group_Manager Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Set_Group_Manager parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 解散群组
- (void)groupDissolutionGroupWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Dissolution_Group Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Dissolution_Group parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取群组管理员列表
- (void)groupGetManagerListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Manager_List Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_Manager_List parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 获取群机器人列表
-(void)groupGetRobotListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Robots_List Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Group_Get_Robots_List parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 获取群机器人数量
-(void)groupGetRobotCountWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Robots_Count Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Group_Get_Robots_Count parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 获取当前用户的禁言状态
- (void)groupGetUserNotalkStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_User_Notalk_State Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_User_Notalk_State parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询群成员在本群昵称
- (void)groupGetUserNickNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_User_NickName Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_User_NickName parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取生成二维码的内容(拿到该内容后，由App端生成对应的二维码)
- (void)getCreatQrCodeContent:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Creat_Qrcode_Content_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Creat_Qrcode_Content_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 通过扫码获取到的字符串向后台获取扫码后跳转的真实数据
- (void)getScanQrContentTransformData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Transform_Qrcode_Content_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Transform_Qrcode_Content_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 申请加入群聊
- (void)groupApplyJoinWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Apply_Join_Group_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Apply_Join_Group_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取申请进群列表-群管理
- (void)groupManagerApplyJoinListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Manager_Apply_Join_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Manager_Apply_Join_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取申请进群列表-群通知
- (void)groupNotificationApplyJoinListWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Notification_Apply_Join_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Notification_Apply_Join_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 批量(单条)审核入群申请
- (void)groupGroupJoinApplyHandleWithData:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Apply_Join_Handle_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Apply_Join_Handle_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  群内禁止私聊
- (void)groupPrivateChatStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Private_Chat_Status_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Private_Chat_Status_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 进群验证开关
- (void)groupJoinGroupStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Join_Group_Status_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Join_Group_Status_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 修改全员禁止音视频状态
- (void)groupUpdateAudioVideoCallStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Update_Audio_Video_Call_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Update_Audio_Video_Call_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 修改 关闭群提示 开关状态
- (void)groupUpdateGroupRemindSwitchStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Update_Group_Remind_Swich_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Update_Group_Remind_Swich_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

/// 修改是否展示群二维码
- (void)groupUpdateIsShowQrCodeWith:(NSMutableDictionary *)params
                               onSuccess:(LingIMSuccessCallback)onSuccess
                               onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Update_Is_ShowQrCode_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Update_Is_ShowQrCode_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 新人查看群聊天历史
- (void)groupNewMemberCheckHistoryStatusWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_isShowHistory_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_isShowHistory_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  获取群活跃配置
- (void)groupGetActivityLevelConfigWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Activity_Config_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Group_Get_Activity_Config_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  修改群活跃展示开关
- (void)groupUpdateActivityLevelEnableStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Update_Activity_Enable_Status_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Update_Activity_Enable_Status_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  群成员活跃积分分页列表-增量
- (void)groupGetMemberActiviteScoreWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Get_Member_Activite_Score_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Get_Member_Activite_Score_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 设置/取消 消息置顶
- (void)groupSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Set_Msg_Top_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Set_Msg_Top_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

@end
