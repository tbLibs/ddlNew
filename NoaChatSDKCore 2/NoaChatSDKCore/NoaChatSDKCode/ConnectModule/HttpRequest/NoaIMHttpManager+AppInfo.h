//
//  NoaIMHttpManager+AppInfo.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/4/4.
//

//App获取版本更新信息
#define App_Get_Update_Info_Url         @"/biz/system/v2/getLatestVersion"
//获取连接设置
#define App_Get_Sso_Connect_Url         @"/biz/sso/connect"
//敏感词更新接口（v2对返回的内容进行了加密，需要进行解密）
//#define App_Sensitive_Update_Url        @"/biz/sensitive/update"
#define App_Sensitive_Update_Url        @"/biz/sensitive/v2/update"
//上报设备数据
#define Push_ReportDevice_Url           @"/biz/server/reportDevice"
//删除设备数据
#define Push_DeleteDevice_Url           @"/biz/server/delDevice"
//获取角色配置
#define App_GetRoleConfig_Url           @"/biz/system/getRoleConfig"
//DNS上报信息
#define App_DNS_Info_Upload_Url         @"/biz/dns/report"


#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (AppInfo)

#pragma mark - 竞速
/// 获取App系统设置接口
- (void)AppGetSystemConfigInfoWithBaseUrl:(NSString *)baseUrl
                                     Path:(NSString *)path
                                  IsLogin:(BOOL)isLogin
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure;

/// ip/域名直连时获取Tcp的域名或者ip
- (void)AppNetworkGetConnectListWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// http节点择优
- (void)AppHttpNodfePreferWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

#pragma mark - 业务
/// App获取版本更新信息
/// @param params 操作参数 {platform:平台(1 iOS,2Android,3 H5,4 Web,5 PC) userUid:用户ID}
- (void)AppGetUpdateInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// App获取连接设置
/// @param params 操作参数 {}
- (void)AppGetSsoConnect:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 敏感词跟新接口
/// @param params 操作参数 {pageNumber:0, pageSize:0, pageStart:0, updateTime: "2023-07-05 11:16:37"}
- (void)AppUpdateSensitiveInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//上报设备数据
- (void)UpDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//删除设备数据
- (void)DeleteDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//获取角色配置
- (void)GetRoleConfigInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//上报DNS信息
- (void)UploadDNSinfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
