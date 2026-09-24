//
//  NoaIMSDKManager+AppInfo.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/4/4.
//

#import "NoaIMSDKManager.h"
#import "LingIMSensitiveRecordsModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (AppInfo)

#pragma mark - ******数据库处理******
#pragma mark - 保存的 敏感词 数据
- (BOOL)toolSaveLocalSensitiveDataWithSensitiveList:(NSArray <LingIMSensitiveRecordsModel *> *)sensitiveList;
#pragma mark - 返回本地 敏感词 数据列表
- (NSArray<LingIMSensitiveRecordsModel *> *)toolGetSensitiveList;


#pragma mark - ******接口逻辑处理******
//******* 竞速 **********
/// 获取App系统设置接口
- (void)appGetSystemConfigInfoWithBaseUrl:(NSString *)baseUrl
                                     Path:(NSString *)path
                                  IsLogin:(BOOL)isLogin
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure;

/// ip/域名直连时获取Tcp的域名或者ip
- (void)appNetworkGetConnectListWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;


/// http节点择优
- (void)appHttpNodfePreferWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

// ******App Info 相关接口******

/// App获取版本更新信息
/// @param params 操作参数 {platform:平台(1 iOS,2Android,3 H5,4 Web,5 PC) userUid:用户ID}
- (void)imSdkGetAppUpdateInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// App获取连接设置
/// @param params 操作参数 {}
- (void)imSdkGetAppSsoContectWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// App敏感词更新
/// @param params 操作参数 {pageNumber:0, pageSize:0, pageStart:0, updateTime: "2023-07-05 11:16:37"}
- (void)imSdkUpdateAppSensitiveWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//上报设备数据
- (void)imSdkUpDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//删除设备数据
- (void)imSdkdeleteDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//获取角色配置
- (void)imGetRoleConfigInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//上报DNS信息
- (void)imSdkUploadDNSinfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 全局翻译开关（由上层应用注入；默认开启）
- (BOOL)toolIsTranslateEnabled;

/// 设置全局翻译开关（上层在开关变更时调用）
- (void)toolSetGlobalTranslateEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
