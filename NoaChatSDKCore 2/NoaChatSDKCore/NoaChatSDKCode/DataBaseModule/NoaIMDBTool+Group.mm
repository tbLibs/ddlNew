//
//  NoaIMDBTool+Group.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "NoaIMDBTool+Group.h"

//群组信息
#import "LingIMGroupModel+WCTTableCoding.h"

@implementation NoaIMDBTool (Group)

#pragma mark - 获取我的群组列表数据
- (NSArray<LingIMGroupModel *> *)getMyGroupList {
    [DBTOOL isTableStateOkWithName:NoaChatDBGroupTableName model:LingIMGroupModel.class];
    //return [self.cimDB getAllObjectsOfClass:LingIMGroupModel.class fromTable:CIMDBGroupTableName];
    return [self.noaChatDB getObjectsOfClass:LingIMGroupModel.class fromTable:NoaChatDBGroupTableName where:LingIMGroupModel.groupStatus == 1];
}


#pragma mark - 根据群组ID查询群组信息
- (LingIMGroupModel *)checkMyGroupWith:(NSString *)groupID {
    [DBTOOL isTableStateOkWithName:NoaChatDBGroupTableName model:LingIMGroupModel.class];
    return [self.noaChatDB getObjectOfClass:LingIMGroupModel.class fromTable:NoaChatDBGroupTableName where:LingIMGroupModel.groupId == groupID];
}

#pragma mark - 根据群组ID删除数据库内容
- (BOOL)deleteMyGroupWith:(NSString *)groupID {
    if ([self checkMyGroupWith:groupID]) {
        return [self.noaChatDB deleteFromTable:NoaChatDBGroupTableName where:LingIMGroupModel.groupId == groupID];
    }else {
        return NO;
    }
}

#pragma mark - 更新或新增群组到表
- (BOOL)insertOrUpdateGroupModelWith:(LingIMGroupModel *)model {
    [DBTOOL isTableStateOkWithName:NoaChatDBGroupTableName model:LingIMGroupModel.class];
    return [DBTOOL insertModelToTable:NoaChatDBGroupTableName model:model];
}

#pragma mark - 批量 更新或新增群组到表
- (BOOL)batchInsertOrUpdateGroupModelWithList:(NSArray <LingIMGroupModel *> *)modelList {
    return [DBTOOL insertMulitModelToTable:NoaChatDBGroupTableName modelClass:LingIMGroupModel.class list:modelList];
}

#pragma mark - 根据搜索内容查询群组数据
- (NSArray <LingIMGroupModel *> *)searchMyGroupWith:(NSString *)searchStr {
    [DBTOOL isTableStateOkWithName:NoaChatDBGroupTableName model:LingIMGroupModel.class];
    //%搜索%，检索任意位置包含有 搜索 字段的内容
    searchStr = [[NoaIMManagerTool sharedManager] stringReplaceSpecialCharacterWith:searchStr];
    if (searchStr.length > 0) {
        NSString *likeStr = [NSString stringWithFormat:@"%%%@%%",searchStr];
        return [self.noaChatDB getObjectsOfClass:LingIMGroupModel.class fromTable:NoaChatDBGroupTableName where:LingIMGroupModel.groupName.like(likeStr)];
    }else {
        return nil;
    }
}

@end
