//
//  NoaIMSDKManager+Auth.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMSDKManager+Auth.h"
#import "NoaIMHttpManager+Auth.h"

@implementation NoaIMSDKManager (Auth)

#pragma mark - 获取图形验证码
- (void)authGetImgVerCodeWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthGetImgVerCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取短信/邮箱验证码
- (void)authGetPhoneEmailVerCodeWith:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    
    if (self.captchaChannel == 2) {
        //图形验证码验证
        [[NoaIMHttpManager sharedManager] AuthGetPhoneEmailVerCodeV2With:params onSuccess:onSuccess onFailure:onFailure];

    }
    if (self.captchaChannel == 3 || self.captchaChannel == 4 || self.captchaChannel == 1) {
        //阿里云无痕验证
        [[NoaIMHttpManager sharedManager] AuthGetPhoneEmailVerCodeV3With:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 校验 短信/邮箱验证码
- (void)authCheckPhoneEmailVerCodeWith:(NSMutableDictionary * _Nullable)params
                             onSuccess:(nullable LingIMSuccessCallback)onSuccess
                             onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthCheckPhoneEmailVerCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取加密密钥
- (void)authGetEncryptKeySuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthGetEncryptKeySuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 注册新用户
- (void)authRegisterWith:(NSMutableDictionary * _Nullable)params
               onSuccess:(nullable LingIMSuccessCallback)onSuccess
               onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthRegisterWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户登录
- (void)authUserLoginWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (self.captchaChannel == 3 || self.captchaChannel == 4 || self.captchaChannel == 1) {
        [[NoaIMHttpManager sharedManager] AuthUserLoginV5With:params onSuccess:onSuccess onFailure:onFailure];
    } else {
        [[NoaIMHttpManager sharedManager] AuthUserLoginV4With:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 用户退出登录
- (void)authUserLogoutWith:(NSMutableDictionary * _Nullable)params
                 onSuccess:(nullable LingIMSuccessCallback)onSuccess
                 onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthUserLogoutWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 用户是否存在
- (void)authUserExistWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthUserExistWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 检查用户是否存在以及是否设置密码
- (void)authUserExistAndHasPwdWith:(NSMutableDictionary * _Nullable)params
                         onSuccess:(nullable LingIMSuccessCallback)onSuccess
                         onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthUserExistAndHasPwdWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 验证码验证是否正确
- (void)authUserVerCodeWith:(NSMutableDictionary * _Nullable)params
                  onSuccess:(nullable LingIMSuccessCallback)onSuccess
                  onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthUserVerCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 找回密码(重置密码)
- (void)authResetPasswordWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthResetPasswordWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 账号注销
- (void)authDeleteAccountWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthDeleteAccountWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 扫码授权PC端登录
- (void)authScanQrCodeForPCLoginWith:(NSMutableDictionary * _Nullable)params
                           onSuccess:(nullable LingIMSuccessCallback)onSuccess
                           onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthScanQrCodeForPCLoginWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取登录注册方式
- (void)authGetLoginAndRegisterTypeOnSuccess:(nullable LingIMSuccessCallback)onSuccess
                                   onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthGetLoginAndRegisterTypeOnSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 申请解禁
- (void)authApplyUnBandWith:(NSMutableDictionary * _Nullable)params
                  onSuccess:(nullable LingIMSuccessCallback)onSuccess
                  onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthUserApplyUnBandWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 设置用户安全码
- (void)authSaveSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure {
 
    [[NoaIMHttpManager sharedManager] AuthSaveSecurityCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 修改用户安全码
- (void)authUpdatecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthUpdatecurityCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 关闭用户安全码
- (void)authCloseSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthCloseSecurityCodeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 安全码登录验证
- (void)authSecurityCodeLoginWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthSecurityCodeLoginWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 信任设备列表
/// 转发信任设备列表请求到 SDK HTTP 层。
- (void)authTrustedDeviceListWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] AuthTrustedDeviceListWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 剔除信任设备
/// 转发信任设备剔除请求到 SDK HTTP 层。
- (void)authTrustedDeviceRevokeWith:(NSMutableDictionary * _Nullable)params
                          onSuccess:(nullable LingIMSuccessCallback)onSuccess
                          onFailure:(nullable LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] AuthTrustedDeviceRevokeWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 清除信任设备异常标记
/// 转发信任设备异常标记清除请求到 SDK HTTP 层。
- (void)authTrustedDeviceClearAnomalyWith:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    [[NoaIMHttpManager sharedManager] AuthTrustedDeviceClearAnomalyWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 检测用户是否是弱密码
- (void)authCheckPasswordStrengthWith:(NSMutableDictionary * _Nullable)params
                              onSuccess:(nullable LingIMSuccessCallback)onSuccess
                              onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AuthCheckPasswordStrengthWith:params onSuccess:onSuccess onFailure:onFailure];
}


@end
