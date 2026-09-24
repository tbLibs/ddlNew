//
//  NoaIMDBTool+Stickers.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import "NoaIMDBTool+Stickers.h"
#import "RecentsEmojiModel+WCTTableCoding.h"
#import "NoaIMStickersModel+WCTTableCoding.h"
#import "NoaIMStickersPackageModel+WCTTableCoding.h"


@implementation NoaIMDBTool (Stickers)

#pragma mark - 最近使用Emoji
/// 获取Emoji表情中 最近使用
- (NSArray<RecentsEmojiModel *> *)getMyRecentsEmojiList {
    [DBTOOL isTableStateOkWithName:NoaChatDBRecentsEmojiTableName model:RecentsEmojiModel.class];
    return [self.noaChatDB getObjectsOfClass:RecentsEmojiModel.class fromTable:NoaChatDBRecentsEmojiTableName];
}

/// 更新或新增 Emoji表情中 最近使用
/// @param model 最新使用Emoji表情
- (BOOL)insertOrUpdateRecentsEmojiModelWith:(RecentsEmojiModel *)model {
    [DBTOOL isTableStateOkWithName:NoaChatDBRecentsEmojiTableName model:RecentsEmojiModel.class];
    NSMutableArray *allRecentsEmojiList = [[DBTOOL getMyRecentsEmojiList] mutableCopy];
    NSMutableArray *tempAllRecentsEmojiList = [NSMutableArray arrayWithArray:allRecentsEmojiList];
    BOOL ishas = NO;
    NSInteger oldIndex = 0;
    for (NSInteger i = 0; i < tempAllRecentsEmojiList.count; i++) {
        RecentsEmojiModel *tempEmoji = (RecentsEmojiModel *)[tempAllRecentsEmojiList objectAtIndex:i];
        if ([model.emojiName isEqualToString:tempEmoji.emojiName]) {
            ishas = YES;
            oldIndex = i;
        }
    }
    if (ishas) {
        [allRecentsEmojiList removeObjectAtIndex:oldIndex];
        [allRecentsEmojiList insertObject:model atIndex:0];
    } else {
        [allRecentsEmojiList removeObjectAtIndex:tempAllRecentsEmojiList.count - 1];
        [allRecentsEmojiList insertObject:model atIndex:0];
    }
    
    return [DBTOOL batchInsertRecentsEmojiModelWith:allRecentsEmojiList];
}

/// 批量新增 Emoji表情中 最近使用
/// @param list 最近使用Emoji的数组
- (BOOL)batchInsertRecentsEmojiModelWith:(NSArray<RecentsEmojiModel *> *)list {
    [DBTOOL isTableStateOkWithName:NoaChatDBRecentsEmojiTableName model:RecentsEmojiModel.class];
    [DBTOOL deleteAllObjectWithName:NoaChatDBRecentsEmojiTableName];
    return [DBTOOL insertMulitModelToTable:NoaChatDBRecentsEmojiTableName modelClass:RecentsEmojiModel.class list:list];
}

#pragma mark - 收藏的表情
/// 获取收藏的表情中的所有表情
- (NSArray<NoaIMStickersModel *> *)getMyCollectionStickersList {
    [DBTOOL isTableStateOkWithName:NoaChatDBCollectionStickersTableName model:NoaIMStickersModel.class];
    return [self.noaChatDB getObjectsOfClass:NoaIMStickersModel.class fromTable:NoaChatDBCollectionStickersTableName];
}

/// 单个 更新或新增 收藏的表情
/// @param model 收藏的表情
- (BOOL)insertOrUpdateCollectionStickersModelWith:(NoaIMStickersModel *)model {
    return [DBTOOL insertModelToTable:NoaChatDBCollectionStickersTableName model:model];
}

/// 单个 删除 收藏的表情
/// @param stickersId 收藏的表情Id
- (BOOL)deleteCollectionStickersModelWith:(NSString *)stickersId {
    [DBTOOL isTableStateOkWithName:NoaChatDBCollectionStickersTableName model:NoaIMStickersModel.class];
    return [self.noaChatDB deleteFromTable:NoaChatDBCollectionStickersTableName where:NoaIMStickersModel.stickersId == stickersId];
}

/// 批量新增 收藏的表情
/// @param list 收藏的表情列表
- (BOOL)batchInsertCollectionStickersModelWith:(NSArray<NoaIMStickersModel *> *)list {
    [DBTOOL isTableStateOkWithName:NoaChatDBCollectionStickersTableName model:NoaIMStickersModel.class];
    return [DBTOOL insertMulitModelToTable:NoaChatDBCollectionStickersTableName modelClass:NoaIMStickersModel.class list:list];
}

/// 清空 收藏的表情
- (BOOL)deleteAllCollectionStickersModels {
    [DBTOOL isTableStateOkWithName:NoaChatDBCollectionStickersTableName model:NoaIMStickersModel.class];
    return [DBTOOL deleteAllObjectWithName:NoaChatDBCollectionStickersTableName];
}

#pragma mark - 已使用的表情包
/// 获取已使用的表情包中
- (NSArray<NoaIMStickersPackageModel *> *)getMyStickersPackageList {
    [DBTOOL isTableStateOkWithName:NoaChatDBPackageStickersTableName model:NoaIMStickersPackageModel.class];
    return [self.noaChatDB getObjectsOfClass:NoaIMStickersPackageModel.class fromTable:NoaChatDBPackageStickersTableName];
}

/// 单个 删除 已使用的表情包
/// @param packageId 表情包Id
- (BOOL)deleteStickersPackageModelWith:(NSString *)packageId {
    [DBTOOL isTableStateOkWithName:NoaChatDBPackageStickersTableName model:NoaIMStickersPackageModel.class];
    return [self.noaChatDB deleteFromTable:NoaChatDBPackageStickersTableName where:NoaIMStickersPackageModel.packageId == packageId];
}

/// 批量新增 表情包
/// @param list 表情包列表
- (BOOL)batchInsertStickersPackageModelWith:(NSArray *)list {
    [DBTOOL isTableStateOkWithName:NoaChatDBPackageStickersTableName model:NoaIMStickersPackageModel.class];
    return [DBTOOL insertMulitModelToTable:NoaChatDBPackageStickersTableName modelClass:NoaIMStickersPackageModel.class list:list];
}

/// 清空 已使用的表情包
- (BOOL)deleteAllStickersPackageModels {
    [DBTOOL isTableStateOkWithName:NoaChatDBPackageStickersTableName model:NoaIMStickersPackageModel.class];
    return [DBTOOL deleteAllObjectWithName:NoaChatDBPackageStickersTableName];
}

@end
