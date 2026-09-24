//
//  NoaIMHttpManager+Team.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMHttpManager+Team.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Team)

#pragma mark - 首页团队信息
- (void)teamHomeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_Home_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_Home_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

- (void)teamHomeV2With:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_HomeV2_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_HomeV2_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 创建团队
- (void)teamCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_Create_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_Create_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 编辑团队
- (void)teamEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_Edit_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_Edit_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 删除团队
- (void)teamDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_Delete_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_Delete_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取团队列表
- (void)teamListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取团队详情
- (void)teamDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_Detail_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_Detail_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取团队成员列表
- (void)teamMemberListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_MemberList_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_MemberList_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 踢出团队
- (void)teamKickTeamWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_kickTeam_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_kickTeam_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 一键建群
- (void)teamCreateGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_CreateGroup_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_CreateGroup_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 团队分享
- (void)teamShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_Share_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_Share_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 默认团队分享
- (void)teamDefaultShareWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_DefaultShare_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_DefaultShare_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 随机邀请码
- (void)teamGetRandomCodeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Team_GetRandomCoe Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Team_GetRandomCoe parameters:params onSuccess:onSuccess onFailure:onFailure];        
    }
}

@end
