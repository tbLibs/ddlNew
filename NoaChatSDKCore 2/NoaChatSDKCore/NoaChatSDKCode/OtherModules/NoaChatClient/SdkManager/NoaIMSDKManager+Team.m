//
//  NoaIMSDKManager+Team.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMSDKManager+Team.h"
#import "NoaIMHttpManager+Team.h"

@implementation NoaIMSDKManager (Team)

#pragma mark - 首页团队信息
- (void)imTeamHomeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamHomeWith:params onSuccess:onSuccess onFailure:onFailure];
}

- (void)imTeamHomeV2With:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamHomeV2With:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 创建团队
- (void)imTeamCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamCreateWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 编辑团队
- (void)imTeamEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamEditWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 删除团队
- (void)imTeamDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamDeleteWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取团队列表
- (void)imTeamListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取团队详情
- (void)imTeamDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamDetailWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取团队成员列表
- (void)imTeamMemberListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamMemberListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 踢出团队
- (void)imTeamKickTeamWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] teamKickTeamWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 一键建群
- (void)imTeamCreateGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamCreateGroupWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 团队分享
- (void)imTeamShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamShareWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 默认团队分享
- (void)imTeamDefaultShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] teamDefaultShareWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 随机邀请码
- (void)imTeamGetRandomCodeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] teamGetRandomCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}
@end
