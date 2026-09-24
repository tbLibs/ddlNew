//
//  NoaIMSDKManager+MiniApp.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/21.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (MiniApp)




/// 获取我的 浮窗小程序 列表
- (NSArray <NoaFloatMiniAppModel *> *)imSdkGetMyFloatMiniAppList;

/// 浮窗小程序 新增/更新
/// - Parameter miniAppModel: 小程序快应用
- (BOOL)imSdkInsertFloatMiniAppWith:(NoaFloatMiniAppModel *)miniAppModel;

/// 删除浮窗小程序
/// - Parameter miniAppID: 小程序快应用唯一标识
- (BOOL)imSdkDeleteFloatMiniAppWith:(NSString *)miniAppID;

/// 删除全部浮窗小程序
- (BOOL)imSdkDeleteAllFloatMiniApp;

#pragma mark - 相关接口
/// 获取快应用列表
/// @param params {pageNumber:起始页(从1开始, pageSize:每页数据大小, pageStart:起始索引(从0开始))}
- (void)imMiniAppListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 创建快应用
/// @param params {qaAppPic:图片logo, qaAppUrl:地址, qaName:名称, qaPwd:密码, qaPwdOpen:开启快应用密码(0否1是)}
- (void)imMiniAppCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 编辑快应用
/// @param params {qaAppPic:图片logo, qaAppUrl:地址, qaName:名称, qaPwd:密码, qaPwdOpen:开启快应用密码(0否1是), qaPwdBefore:应用旧密码, qaPwd:应用密码, qaUuid:快应用唯一标识}
- (void)imMiniAppEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除快应用
/// @param params {qaUuid:快应用唯一标识}
- (void)imMiniAppDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取快应用详情
/// @param params {qaUuid:快应用唯一标识, qaPwd:应用密码}
- (void)imMiniAppDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 验证快应用访问密码
/// @param params {qaUuid:快应用唯一标识, qaPwd:密码}
- (void)imMiniAppPasswordVerifyWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


@end

NS_ASSUME_NONNULL_END
