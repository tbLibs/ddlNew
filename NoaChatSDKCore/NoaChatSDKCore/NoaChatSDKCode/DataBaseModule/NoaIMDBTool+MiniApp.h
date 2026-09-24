//
//  NoaIMDBTool+MiniApp.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/21.
//

#import "NoaIMDBTool.h"
#import "NoaFloatMiniAppModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (MiniApp)

/// 获取我的 浮窗小程序 列表
- (NSArray <NoaFloatMiniAppModel *> *)getMyFloatMiniAppList;

/// 浮窗小程序 新增/更新
/// - Parameter miniAppModel: 小程序快应用
- (BOOL)insertFloatMiniAppWith:(NoaFloatMiniAppModel *)miniAppModel;

/// 删除浮窗小程序
/// - Parameter miniAppID: 小程序快应用唯一标识
- (BOOL)deleteFloatMiniAppWith:(NSString *)floladId;

@end

NS_ASSUME_NONNULL_END
