//
//  NoaIMHttpManager+MiniApp.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

// 小程序 快应用

//获取快应用列表
#define MiniApp_List_Url                @"/biz/quickApps/selectQuickApps"
//创建快应用
#define MiniApp_Create_Url              @"/biz/quickApps/createQuickApp"
//编辑快应用
#define MiniApp_Edit_Url                @"/biz/quickApps/updateQuickApp"
//删除快应用
#define MiniApp_Delete_Url              @"/biz/quickApps/deleteQuickApp"
//获取快应用详情
#define MiniApp_Detail_Url              @"/biz/quickApps/getQuickAppById"
//验证快应用访问密码
#define MiniApp_Password_Verify_Url     @"/biz/quickApps/selectEncryptQuickAppsUrl"


#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (MiniApp)

/// 获取快应用列表
/// @param params {pageNumber:起始页(从1开始, pageSize:每页数据大小, pageStart:起始索引(从0开始))}
- (void)miniAppListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 创建快应用
/// @param params {qaAppPic:图片logo, qaAppUrl:地址, qaName:名称, qaPwd:密码, qaPwdOpen:开启快应用密码(0否1是)}
- (void)miniAppCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 编辑快应用
/// @param params {qaAppPic:图片logo, qaAppUrl:地址, qaName:名称, qaPwd:密码, qaPwdOpen:开启快应用密码(0否1是), qaPwdBefore:应用旧密码, qaPwd:应用密码, qaUuid:快应用唯一标识}
- (void)miniAppEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除快应用
/// @param params {qaUuid:快应用唯一标识}
- (void)miniAppDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取快应用详情
/// @param params {qaUuid:快应用唯一标识, qaPwd:应用密码}
- (void)miniAppDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 验证快应用访问密码
/// @param params {qaUuid:快应用唯一标识, qaPwd:密码}
- (void)miniAppPasswordVerifyWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
