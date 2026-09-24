//
//  NoaIMSDKManager+User.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/21.
//

#import "NoaIMSDKManager+User.h"
#import "NoaIMHttpManager+User.h"
#import "NoaIMSDKManager+MessageRemind.h"

@implementation NoaIMSDKManager (User)
#pragma mark - 查询用户
- (void)userSearchWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userSearchWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取用户是否拥有某些操作的权限
- (void)userGetUserAuthorityWith:(NSMutableDictionary *)params
                       onSuccess:(LingIMSuccessCallback)onSuccess
                       onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userGetUserAuthorityWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取STS TOKEN
- (void)userGetFileUploadTokenWithOnSuccess:(LingIMSuccessCallback)onSuccess
                                  onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userGetFileUploadTokenWithOnSuccess:onSuccess onFailure:onFailure];
}


#pragma mark - 更新用户的头像
- (void)userAvatarChangeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userUpdateAvatarWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 更新用户的昵称
- (void)userNicknameChangeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userUpdateNicknameWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 更新用户的账号
- (void)userAccountChangeWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userUpdateUserNameWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取某个用户信息
- (void)getUserInfoWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userGetUserInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取用户的消息提醒方式
- (void)userGetMessageRemindWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userGetMessageRemindInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户消息提醒方式设置
- (void)userMessageRemindSetWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    __weak typeof(self) weakSelf = self;
    
    [[NoaIMHttpManager sharedManager] userMessageRemindSetWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if (onSuccess) {
            onSuccess(data, traceId);
        }
        
        BOOL result = [data boolValue];
        if (result) {
            //操作成功
            NSInteger messageRemind = [[params objectForKey:@"isNewMsgNotify"] integerValue];
            NSInteger messageVoiceRemind = [[params objectForKey:@"isVoiceNotice"] integerValue];
            NSInteger messageVibrationRemind = [[params objectForKey:@"isShakeNotice"] integerValue];
            [weakSelf toolMessageReceiveRemindOpen:messageRemind == 1];
            [weakSelf toolMessageReceiveRemindVoiceOpen:messageVoiceRemind == 1];
            [weakSelf toolMessageReceiveRemindVibrationOpen:messageVibrationRemind == 1];
        }
        
    } onFailure:onFailure];
}

#pragma mark - 获取 我的收藏 列表
- (void)userMyCollectionListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userGetMyCollectionListtWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 删除 我的收藏 列表中某条收藏
- (void)userCollectionMsgDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userDeleteCollectionMessageWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 校验密码是否一致
- (void)userCheckUserPasswordWith:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userCheckUserPasswordWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 更新密码
- (void)userResetPasswordWith:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userResetPasswordWith:params onSuccess:onSuccess onFailure:onFailure];
}


#pragma mark - 反馈与支持
- (void)userAddFeedBackWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] userAddFeedBackWith:params onSuccess:onSuccess onFailure:onFailure];
}

- (void)ssoFeedBackWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] ssoAddFeedBackWith:params onSuccess:onSuccess onFailure:onFailure];
}

/// 获取用户角色权限
///  userUid 用户账号
- (void)userGetRoleAuthorityListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] getRoleAuthorityListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 设置离线时长
- (void)userSetShowOffLineStatusWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
                           onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] setShowOffLineStatusWith:params onSuccess:onSuccess onFailure:onFailure];
}

/// 获取当前用户默认设置
///  userUid 用户账号
- (void)userTranslateDefaultWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
                       onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userTranslateDefaultWith:params onSuccess:onSuccess onFailure:onFailure];
}

/// 上传用户翻译默认设置
///  userUid 用户账号
- (void)userTranslateDefaultUpload:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
                         onFailure:(LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] userTranslateDefaultUploadWith:params onSuccess:onSuccess onFailure:onFailure];
}

@end
