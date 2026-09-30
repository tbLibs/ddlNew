//
//  NoaIMContactsSyncValidation.h
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

#import <Foundation/Foundation.h>

/// 增量好友状态只能是 0/1；缺失或 null 不能被模型默认值误当作删除事件。
NS_INLINE BOOL NoaIMContactsFriendStatusIsValid(id status) {
    if ([status isKindOfClass:NSNumber.class]) return [status isEqual:@0] || [status isEqual:@1];
    if ([status isKindOfClass:NSString.class]) return [status isEqualToString:@"0"] || [status isEqualToString:@"1"];
    return NO;
}

/// 通讯录分页必须包含数组和有效进度，不能把缺失字段当成同步成功。
NS_INLINE BOOL NoaIMContactsPageIsValid(id data, NSInteger expectedPage, BOOL onlinePage) {
    if (![data isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *page = data;
    if (![page[@"rows"] isKindOfClass:NSArray.class]) return NO;
    NSArray *rows = page[@"rows"];
    for (NSString *key in @[@"pages", @"current"]) {
        id value = page[key];
        if (![value isKindOfClass:NSNumber.class] && ![value isKindOfClass:NSString.class]) return NO;
        NSScanner *scanner = [NSScanner scannerWithString:[value description]];
        long long number = -1;
        if (![scanner scanLongLong:&number] || !scanner.isAtEnd || number < 0 || number > NSIntegerMax) return NO;
    }
    NSInteger current = [page[@"current"] integerValue];
    NSInteger pages = [page[@"pages"] integerValue];
    if (current != expectedPage || (pages < current && !(pages == 0 && current == 1 && rows.count == 0))) return NO;
    for (id row in rows) {
        if (onlinePage) {
            if (![row isKindOfClass:NSString.class] || [row length] == 0) return NO;
        } else if (![row isKindOfClass:NSDictionary.class]) {
            return NO;
        }
    }
    return YES;
}

/// 汇总所有页的在线 UID，最后一次性更新，避免后一页清空前一页状态。
NS_INLINE void NoaIMContactsMergeOnlinePage(NSMutableSet<NSString *> *onlineUIDs, NSArray<NSString *> *rows) {
    [onlineUIDs addObjectsFromArray:rows];
}
