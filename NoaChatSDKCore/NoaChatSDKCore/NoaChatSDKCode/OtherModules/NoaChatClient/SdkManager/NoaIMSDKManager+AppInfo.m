//
//  NoaIMSDKManager+AppInfo.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/4/4.
//

#import "NoaIMSDKManager+AppInfo.h"
#import "NoaIMHttpManager+AppInfo.h"
#import "NoaIMDBTool+AppInfo.h"

@implementation NoaIMSDKManager (AppInfo)

#pragma mark - ******数据库处理******
#pragma mark - 批量 保存的 敏感词 数据
- (BOOL)toolSaveLocalSensitiveDataWithSensitiveList:(NSArray <LingIMSensitiveRecordsModel *> *)sensitiveList {
    BOOL result = [DBTOOL insertMulitModelToTable:[IMSDKManager getTableNameForSensitive] modelClass:LingIMSensitiveRecordsModel.class list:sensitiveList];
    //NSLog(@"======== 【批量】保存敏感词：%@", (result == YES ? @"YES" : @"NO"));
    return result;
}

#pragma mark - 返回本地 敏感词 数据列表
- (NSArray<LingIMSensitiveRecordsModel *> *)toolGetSensitiveList {
    return [DBTOOL getLocalSensitiveWithTableName:[IMSDKManager getTableNameForSensitive]];
}

#pragma mark - ******接口逻辑处理******
// ****** 竞速 相关接口******
/// 获取App系统设置接口
- (void)appGetSystemConfigInfoWithBaseUrl:(NSString *)baseUrl
                                     Path:(NSString *)path
                                  IsLogin:(BOOL)isLogin
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AppGetSystemConfigInfoWithBaseUrl:baseUrl
                                                                    Path:path
                                                                 IsLogin:isLogin
                                                               onSuccess:onSuccess
                                                               onFailure:onFailure];
}

/// ip/域名直连时获取Tcp的域名或者ip
- (void)appNetworkGetConnectListWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AppNetworkGetConnectListWithBaseUrl:baseUrl Path:path onSuccess:onSuccess onFailure:onFailure];
}

/// http节点择优
- (void)appHttpNodfePreferWithBaseUrl:(NSString *)baseUrl Path:(NSString *)path onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AppHttpNodfePreferWithBaseUrl:baseUrl Path:path onSuccess:onSuccess onFailure:onFailure];
}


// ******App Info 相关接口******
#pragma mark - App获取版本更新信息
- (void)imSdkGetAppUpdateInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AppGetUpdateInfo:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - App获取连接设置
- (void)imSdkGetAppSsoContectWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AppGetSsoConnect:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - App敏感词更新
- (void)imSdkUpdateAppSensitiveWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] AppUpdateSensitiveInfo:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 上报设备数据
- (void)imSdkUpDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] UpDeviceTokenWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 删除设备数据
- (void)imSdkdeleteDeviceTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] DeleteDeviceTokenWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取角色配置
- (void)imGetRoleConfigInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] GetRoleConfigInfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 上报DNS信息
- (void)imSdkUploadDNSinfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] UploadDNSinfoWith:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 全局翻译开关（默认开启）
- (BOOL)toolIsTranslateEnabled {
    // 默认开启；上层可通过 toolSetGlobalTranslateEnabled 设置覆盖
    NSNumber *flag = [[NSUserDefaults standardUserDefaults] objectForKey:@"CIM_Global_Translate_Enabled"];
    if (flag == nil) { return YES; }
    return flag.boolValue;
}

- (void)toolSetGlobalTranslateEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setObject:@(enabled) forKey:@"CIM_Global_Translate_Enabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
