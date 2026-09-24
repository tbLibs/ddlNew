//
//  NoaIMHttpManager+Friend.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/20
//

#import "NoaIMHttpManager+Friend.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Friend)

#pragma mark - 获取黑名单列表
- (void)friendGetBlackListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Friend_Black_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Friend_Black_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 将用户加入黑名单
- (void)friendAddBlackWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Friend_Black_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Friend_Black_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}
#pragma mark - 将用户移除黑名单
- (void)friendRemoveBlackWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Friend_Black_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Friend_Black_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 好友拉黑状态
- (void)friendCheckBlackStateWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Black_State_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Black_State_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}


#pragma mark - 获取好友通讯录列表
- (void)friendGetListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 好友验证(是否是我的好友)
- (void)friendCheckWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Check_Friend_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Check_Friend_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获取好友申请列表
- (void)friendGetApplyListWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Friend_Req_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Friend_Req_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 好友邀请信息增量列表查询
- (void)friendSyncReqListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Sync_Req_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Sync_Req_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 添加好友，发起好友申请
- (void)friendAddContactWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Add_Friend_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Add_Friend_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 同意好友申请
- (void)friendApplyConfirmWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Friend_Req_Verify_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Friend_Req_Verify_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 移除好友
- (void)friendDeleteContactWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Delete_Friend_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Delete_Friend_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获取某个好友信息
- (void)friendGetFriendInfoWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Detail_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Detail_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 修改好友备注描述
- (void)friendSetFriendRemarkAndDesWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure{
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Set_RemarkDes_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Set_RemarkDes_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - <<<<<<通讯录 - 好友分组模块>>>>>>
#pragma mark - 查询好友分组列表数据
- (void)friendGroupListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Group_GroupList_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Group_GroupList_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 创建好友分组
- (void)friendGroupCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Group_CreateGroup_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Group_CreateGroup_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 修改好友分组(好友分组名称/排序)
- (void)friendGroupUpdateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Group_UpdateGroup_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Group_UpdateGroup_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 删除好友分组
- (void)friendGroupDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Group_DeleteGroup_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Group_DeleteGroup_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 修改 我的好友 所在 好友分组
- (void)friendGroupUpdateFriendGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Group_UpdateFriendGroup_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Group_UpdateFriendGroup_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获取分享邀请信息
- (void)friendGetShareInviteInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Get_Share_Invite_Info_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Get_Share_Invite_Info_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获取当前在线好友标识集合
- (void)friendGetOnlineStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Friend_Get_Online_Status_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Friend_Get_Online_Status_Url parameters:params onSuccess:onSuccess onFailure:onFailure];            
        }
    }
}
@end
