//
//  NoaIMHttpManager+Auth.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMHttpManager+Auth.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Auth)

#pragma mark - 信任设备列表
/// 获取当前用户的信任设备列表，支持按 SDK 配置选择 HTTP 或 HTTP 转 TCP 通道。
- (void)AuthTrustedDeviceListWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Trusted_Device_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    } else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Trusted_Device_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 剔除信任设备
/// 提交密码凭据并剔除指定信任设备，支持 HTTP 和 HTTP 转 TCP 通道。
- (void)AuthTrustedDeviceRevokeWith:(NSMutableDictionary * _Nullable)params
                          onSuccess:(nullable LingIMSuccessCallback)onSuccess
                          onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Trusted_Device_Revoke_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    } else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Trusted_Device_Revoke_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 清除信任设备异常标记
/// 提交设备标识和密码摘要并清除异常标记，支持 HTTP 和 HTTP 转 TCP 通道。
- (void)AuthTrustedDeviceClearAnomalyWith:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Trusted_Device_Clear_Anomaly_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    } else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Trusted_Device_Clear_Anomaly_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取图形验证码(POST)
- (void)AuthGetImgVerCodeWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Get_VerCode_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Get_VerCode_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -获取加密密钥
- (void)AuthGetEncryptKeySuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:@{} Url:Auth_Get_EncryptKey_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Auth_Get_EncryptKey_Url parameters:@{} onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 注册新用户(POST)
- (void)AuthRegisterWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Register_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Register_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 用户登录(POST) V2
- (void)AuthUserLoginV4With:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_User_Login_V4_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_User_Login_V4_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 用户登录(POST) V3
- (void)AuthUserLoginV5With:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_User_Login_V5_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_User_Login_V5_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 用户退出登录
- (void)AuthUserLogoutWith:(NSMutableDictionary * _Nullable)params
                 onSuccess:(nullable LingIMSuccessCallback)onSuccess
                 onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_User_Logout_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_User_Logout_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 用户是否存在(POST)
- (void)AuthUserExistWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_User_Exist_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_User_Exist_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 检查用户是否存在以及是否设置密码
- (void)AuthUserExistAndHasPwdWith:(NSMutableDictionary * _Nullable)params
                         onSuccess:(nullable LingIMSuccessCallback)onSuccess
                         onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_User_Exist_HasPwd_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_User_Exist_HasPwd_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 验证码验证是否正确(POST)
- (void)AuthUserVerCodeWith:(NSMutableDictionary * _Nullable)params
                  onSuccess:(nullable LingIMSuccessCallback)onSuccess
                  onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Ver_ImgCode_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Ver_ImgCode_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}


#pragma mark - 获取短信/邮箱验证码V2
- (void)AuthGetPhoneEmailVerCodeV2With:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Phone_Email_VerCode_V2_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Phone_Email_VerCode_V2_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取短信/邮箱验证码V3
- (void)AuthGetPhoneEmailVerCodeV3With:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Phone_Email_VerCode_V3_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Phone_Email_VerCode_V3_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 校验 短信/邮箱验证码
- (void)AuthCheckPhoneEmailVerCodeWith:(NSMutableDictionary * _Nullable)params
                             onSuccess:(nullable LingIMSuccessCallback)onSuccess
                             onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Check_VerCode_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Check_VerCode_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 找回密码(重置密码)
- (void)AuthResetPasswordWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Reset_Password_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Reset_Password_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 账号注销
- (void)AuthDeleteAccountWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Account_Remove_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Account_Remove_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 扫码授权PC端登录
- (void)AuthScanQrCodeForPCLoginWith:(NSMutableDictionary * _Nullable)params
                           onSuccess:(nullable LingIMSuccessCallback)onSuccess
                           onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Scan_QRcode_Login_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Scan_QRcode_Login_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取登录注册方式
- (void)AuthGetLoginAndRegisterTypeOnSuccess:(nullable LingIMSuccessCallback)onSuccess
                                   onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:@{} Url:Auth_Login_Register_Type_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Login_Register_Type_Url parameters:@{} onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 申请解禁
- (void)AuthUserApplyUnBandWith:(NSMutableDictionary * _Nullable)params
                      onSuccess:(nullable LingIMSuccessCallback)onSuccess
                      onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_User_Apply_Unban_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_User_Apply_Unban_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  设置用户安全码
- (void)AuthSaveSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Save_Security_Code_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Save_Security_Code_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  修改用户安全码
- (void)AuthUpdatecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Update_Security_Code_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Update_Security_Code_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  关闭用户安全码
- (void)AuthCloseSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Close_Security_Code_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Close_Security_Code_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark -  安全码登录验证
- (void)AuthSecurityCodeLoginWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Security_Code_Login_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Security_Code_Login_Url parameters:params onSuccess:onSuccess onFailure:onFailure];        
    }
}

#pragma mark -  检测用户是否是弱密码
- (void)AuthCheckPasswordStrengthWith:(NSMutableDictionary * _Nullable)params
                              onSuccess:(nullable LingIMSuccessCallback)onSuccess
                              onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Auth_Check_Password_Strength_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Check_Password_Strength_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}



@end
