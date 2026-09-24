//
//  NoaIMHttpManager+Team.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

// 团队

//首页团队(旧)
#define Team_Home_Url                @"/biz/team/home"

//首页团队(新)
#define Team_HomeV2_Url                @"/biz/team/home/v2"

//创建团队
#define Team_Create_Url              @"/biz/team/createTeam"
//编辑团队
#define Team_Edit_Url                @"/biz/team/update"
//删除团队
#define Team_Delete_Url                @"/biz/team/delete"
//团队列表
#define Team_List_Url                @"/biz/team/teamList"
//团队详情
#define Team_Detail_Url                @"/biz/team/info"
//团队成员列表
#define Team_MemberList_Url                @"/biz/team/memberList"
//踢出团队
#define Team_kickTeam_Url                @"/biz/team/kickTeam"
//一键建群
#define Team_CreateGroup_Url                @"/biz/team/createGroup"
//团队分享
#define Team_Share_Url                @"/biz/team/share"
//默认团队分享(仅在个人中心分享使用)
#define Team_DefaultShare_Url                @"/biz/team/defaultShare"
//随机邀请码
#define Team_GetRandomCoe               @"/biz/team/getRandomCode"

#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (Team)

/// 首页团队信息
/// @param params {userUid:操作用户ID}
- (void)teamHomeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 首页团队信息V2版本(新版本团队邀请2.1.8)
/// @param params {userUid:操作用户ID}
- (void)teamHomeV2With:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 创建团队
/// @param params {teamName:团队名称, isDefaultTeam:是否默认团队(0否1是)}
- (void)teamCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 编辑团队
/// @param params {teamId:团队ID, teamName:团队名称, isDefaultTeam:是否默认团队(0否1是)}
- (void)teamEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除团队
/// @param params {teamIds:[被删除的团队列表]}
- (void)teamDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取团队列表
/// @param params {pageNumber:分页(1开始), pageSize:每页数据大小, pageStart:起始索引(0开始)}
- (void)teamListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取团队详情
/// @param params {teamId:团队ID}
- (void)teamDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取团队成员列表
/// @param params {teamId:团队ID, pageNumber:分页(1开始), pageSize:每页数据大小, pageStart:起始索引(0开始)}
- (void)teamMemberListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 踢出团队
/// @param params {teamId:团队ID, userUid:被踢出团队用户id}
- (void)teamKickTeamWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 一键建群
/// @param params {teamId:团队ID}
- (void)teamCreateGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 团队分享
/// @param params {teamId:团队ID}
- (void)teamShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 默认团队分享
/// @param params {userUid:操作用户ID}
- (void)teamDefaultShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/// 随机邀请码
- (void)teamGetRandomCodeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
