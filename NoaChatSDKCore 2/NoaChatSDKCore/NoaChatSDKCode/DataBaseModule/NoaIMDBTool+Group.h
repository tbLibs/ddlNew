//
//  NoaIMDBTool+Group.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "NoaIMDBTool.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (Group)

/// 获取我的群组列表数据
- (NSArray<LingIMGroupModel *> *)getMyGroupList;

/// 根据群组ID查询群组信息
/// @param groupID 群组ID
- (LingIMGroupModel *)checkMyGroupWith:(NSString *)groupID;

/// 根据群组ID删除数据库内容
/// @param groupID 群组ID
- (BOOL)deleteMyGroupWith:(NSString *)groupID;

/// 更新或新增群组到表
/// @param model 消息内容
- (BOOL)insertOrUpdateGroupModelWith:(LingIMGroupModel *)model;

#pragma mark - 批量 更新或新增群组到表
/// @param modelList 群组数据数组
- (BOOL)batchInsertOrUpdateGroupModelWithList:(NSArray <LingIMGroupModel *> *)modelList;

/// 根据搜索内容查询群组数据
/// @param searchStr 搜索内容
- (NSArray <LingIMGroupModel *> *)searchMyGroupWith:(NSString *)searchStr;

@end

NS_ASSUME_NONNULL_END
