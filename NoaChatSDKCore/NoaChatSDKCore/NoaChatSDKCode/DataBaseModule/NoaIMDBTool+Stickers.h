//
//  NoaIMDBTool+Stickers.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import "NoaIMDBTool.h"
#import "RecentsEmojiModel.h"
#import "NoaIMStickersModel.h"
#import "NoaIMStickersPackageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (Stickers)

#pragma mark - 最近使用Emoji
/// 获取Emoji表情中 最近使用
- (NSArray<RecentsEmojiModel *> *)getMyRecentsEmojiList;

/// 更新或新增 Emoji表情中 最近使用
/// @param model 最新使用Emoji表情
- (BOOL)insertOrUpdateRecentsEmojiModelWith:(RecentsEmojiModel *)model;

/// 批量新增 Emoji表情中 最近使用
/// @param list 最近使用Emoji的数组
- (BOOL)batchInsertRecentsEmojiModelWith:(NSArray<RecentsEmojiModel *> *)list;

#pragma mark - 收藏的表情
/// 获取收藏的表情中的所有表情
- (NSArray<NoaIMStickersModel *> *)getMyCollectionStickersList;

/// 单个 更新或新增 收藏的表情
/// @param model 收藏的表情
- (BOOL)insertOrUpdateCollectionStickersModelWith:(NoaIMStickersModel *)model;

/// 单个 删除 收藏的表情
/// @param stickersId 收藏的表情Id
- (BOOL)deleteCollectionStickersModelWith:(NSString *)stickersId;

/// 批量新增 收藏的表情
/// @param list 收藏的表情列表
- (BOOL)batchInsertCollectionStickersModelWith:(NSArray<NoaIMStickersModel *> *)list;

/// 清空 收藏的表情
- (BOOL)deleteAllCollectionStickersModels;

#pragma mark - 已使用的表情包
/// 获取已使用的表情包中
- (NSArray<NoaIMStickersPackageModel *> *)getMyStickersPackageList;

/// 单个 删除 已使用的表情包
/// @param packageId 表情包Id
- (BOOL)deleteStickersPackageModelWith:(NSString *)packageId;

/// 批量新增 表情包
/// @param list 表情包列表
- (BOOL)batchInsertStickersPackageModelWith:(NSArray *)list;

/// 清空 已使用的表情包
- (BOOL)deleteAllStickersPackageModels;


@end

NS_ASSUME_NONNULL_END
