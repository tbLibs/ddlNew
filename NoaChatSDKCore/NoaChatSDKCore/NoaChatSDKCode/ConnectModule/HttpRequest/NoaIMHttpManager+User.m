//
//  NoaIMHttpManager+User.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/20.
//

#import "NoaIMHttpManager+User.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (User)

#pragma mark - 用户搜索
- (void)userSearchWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Search_1_0_11_By_UserName_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:User_Search_1_0_11_By_UserName_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取用户是否拥有某些操作的权限
- (void)userGetUserAuthorityWith:(NSMutableDictionary *)params
                       onSuccess:(LingIMSuccessCallback)onSuccess
                       onFailure:(LingIMFailureCallback)onFailure
{
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Get_User_Authority_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Get_User_Authority_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取STS TOKEN
- (void)userGetFileUploadTokenWithOnSuccess:(LingIMSuccessCallback)onSuccess
                                  onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:@{} Url:User_Get_File_Upload_Tolen_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Get_File_Upload_Tolen_Url parameters:@{} onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 更新用户的头像
- (void)userUpdateAvatarWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Update_Avatar_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Update_Avatar_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 更新用户的昵称
- (void)userUpdateNicknameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Update_Nickname_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Update_Nickname_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}


#pragma mark - 更新用户的账号
- (void)userUpdateUserNameWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Update_UserName_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Update_UserName_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}


#pragma mark - 获取某个用户信息
- (void)userGetUserInfoWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Get_UserInfo_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Get_UserInfo_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获取某个用户信息
- (void)userGetMessageRemindInfoWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Get_Message_Remind_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Get_Message_Remind_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 用户消息提醒方式设置
- (void)userMessageRemindSetWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Message_Remind_Set_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Message_Remind_Set_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获取 我的收藏 列表
- (void)userGetMyCollectionListtWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Get_MyCollection_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Get_MyCollection_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}


#pragma mark - 删除 我的收藏 列表中某条收藏
- (void)userDeleteCollectionMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Delete_Single_Collection_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Delete_Single_Collection_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 校验密码是否一致
- (void)userCheckUserPasswordWith:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Check_User_Password_url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Check_User_Password_url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 更新密码
- (void)userResetPasswordWith:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Reset_Password_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Reset_Password_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}


#pragma mark - 反馈与支持
- (void)userAddFeedBackWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Feedback_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Feedback_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

- (void)ssoAddFeedBackWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sso_Feedback_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sso_Feedback_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取用户角色权限
- (void)getRoleAuthorityListWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_Role_AuthorityList_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_Role_AuthorityList_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 设置离线时长
- (void)setShowOffLineStatusWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_setShowOffLineStatus_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_setShowOffLineStatus_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取当前用户默认设置
/**
 @brief 获取当前用户默认设置
 userUid 用户ID
*/
- (void)userTranslateDefaultWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_TranslateDefault_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_TranslateDefault_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 上传用户翻译默认设置
/**
 @brief 上传用户翻译默认设置
 userUid 用户ID
*/
- (void)userTranslateDefaultUploadWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:User_TranslateDefault_upload_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:User_TranslateDefault_upload_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

@end
