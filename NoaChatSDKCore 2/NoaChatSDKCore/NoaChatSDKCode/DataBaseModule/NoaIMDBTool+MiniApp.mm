//
//  NoaIMDBTool+MiniApp.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/21.
//

#import "NoaIMDBTool+MiniApp.h"

//小程序信息
#import "NoaFloatMiniAppModel+WCTTableCoding.h"

@implementation NoaIMDBTool (MiniApp)

#pragma mark - 获取我的 浮窗小程序 列表
- (NSArray <NoaFloatMiniAppModel *> *)getMyFloatMiniAppList {
    return [self.noaChatDB getObjectsOfClass:NoaFloatMiniAppModel.class fromTable:NoaChatDBFloatMiniAppTableName];
}

#pragma mark - 浮窗小程序 新增/更新
- (BOOL)insertFloatMiniAppWith:(NoaFloatMiniAppModel *)miniAppModel {
    return [self insertModelToTable:NoaChatDBFloatMiniAppTableName model:miniAppModel];
}

#pragma mark - 删除浮窗小程序
- (BOOL)deleteFloatMiniAppWith:(NSString *)floladId {
    //自检一下
    [self isTableStateOkWithName:NoaChatDBFloatMiniAppTableName model:NoaFloatMiniAppModel.class];
    
    return [self.noaChatDB deleteFromTable:NoaChatDBFloatMiniAppTableName where:NoaFloatMiniAppModel.floladId == floladId];
}

@end
