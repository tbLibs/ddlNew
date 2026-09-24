//
//  NoaIMHttpManager+AppInfo.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/4/4.
//

#import "NoaIMHttpManager+AppInfo.h"
#import "LingIMTcpRequestModel.h"
#import "NoaIMSocketManager.h"

@implementation NoaIMHttpManager (AppInfo)

#pragma mark - 获取App系统设置接口
- (void)AppGetSystemConfigInfoWithBaseUrl:(NSString *)baseUrl
                                     Path:(NSString *)path
                                  IsLogin:(BOOL)isLogin
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"" forKey:@"projectId"];
    
    NSString *hostIp = SOCKETMANAGER.socketHostValue;
    NSInteger part = SOCKETMANAGER.socketPortValue;
    
    BOOL isParamAvailable = hostIp != nil && hostIp.length > 0 && part > 0;
    
    if (isParamAvailable) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:path Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWorkCommonBaseUrl:baseUrl Path:path medth:LingIMHttpRequestTypePOST parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - ip/域名直连时获取Tcp的域名或者ip
- (void)AppNetworkGetConnectListWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [self netRequestWorkCommonBaseUrl:baseUrl Path:path medth:LingIMHttpRequestTypePOST parameters:params onSuccess:onSuccess onFailure:onFailure];
}


#pragma mark - http节点择优
- (void)AppHttpNodfePreferWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [self netRequestWorkCommonBaseUrl:baseUrl Path:path medth:LingIMHttpRequestTypeGET parameters:@{} onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - App获取版本更新信息
- (void)AppGetUpdateInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:App_Get_Update_Info_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:App_Get_Update_Info_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - App获取连接设置
- (void)AppGetSsoConnect:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:App_Get_Sso_Connect_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:App_Get_Sso_Connect_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 敏感词跟新接口
- (void)AppUpdateSensitiveInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:App_Sensitive_Update_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:App_Sensitive_Update_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

//上报设备数据
- (void)UpDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Push_ReportDevice_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Push_ReportDevice_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

//删除设备数据
- (void)DeleteDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Push_DeleteDevice_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Push_DeleteDevice_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

//获取角色配置
- (void)GetRoleConfigInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:App_GetRoleConfig_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:App_GetRoleConfig_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

//上报DNS信息
- (void)UploadDNSinfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:App_DNS_Info_Upload_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:App_DNS_Info_Upload_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

@end
