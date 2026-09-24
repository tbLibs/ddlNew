//
//  NoaIMSDKManager+Team.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Team)

/// 首页团队信息
/// @param params {userUid:操作用户ID}
- (void)imTeamHomeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 首页团队信息V2版本(新版本团队邀请2.1.8)
/// @param params {userUid:操作用户ID}
- (void)imTeamHomeV2With:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 创建团队
/// @param params {teamName:团队名称, isDefaultTeam:是否默认团队(0否1是)}
- (void)imTeamCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 编辑团队
/// @param params {teamId:团队ID, teamName:团队名称, isDefaultTeam:是否默认团队(0否1是)}
- (void)imTeamEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除团队
/// @param params {teamIds:[被删除的团队列表]}
- (void)imTeamDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取团队列表
/// @param params {pageNumber:分页(1开始), pageSize:每页数据大小, pageStart:起始索引(0开始)}
- (void)imTeamListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取团队详情
/// @param params {teamId:团队ID}
- (void)imTeamDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取团队成员列表
/// @param params {teamId:团队ID, pageNumber:分页(1开始), pageSize:每页数据大小, pageStart:起始索引(0开始)}
- (void)imTeamMemberListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 踢出团队
/// @param params {teamId:团队ID, userUid:被踢出团队用户id}
- (void)imTeamKickTeamWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 一键建群
/// @param params {teamId:团队ID}
- (void)imTeamCreateGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 团队分享
/// @param params {teamId:团队ID}
- (void)imTeamShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 默认团队分享
/// @param params {userUid:操作用户ID}
- (void)imTeamDefaultShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/// 随机邀请码
- (void)imTeamGetRandomCodeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
@end

NS_ASSUME_NONNULL_END
