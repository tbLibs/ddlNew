//
//  SDKContactsSyncChecks.m
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

#import "../../NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/NoaChatClient/SdkManager/NoaIMContactsSyncValidation.h"

/// 执行生产 SDK 的分页校验和在线 UID 合并，不依赖 TCP、用户凭据或数据库。
int main(void) {
    @autoreleasepool {
        NSUInteger checks = 0;
        void (^check)(BOOL, NSString *) = ^(BOOL passed, NSString *message) {
            if (!passed) { NSLog(@"验证失败：%@", message); exit(1); }
        };
#define CHECK(condition, message) do { check((condition), (message)); checks++; } while (0)
        CHECK(NoaIMContactsPageIsValid(@{@"rows": @[@{}], @"current": @1, @"pages": @2}, 1, NO), @"正常好友分页");
        CHECK(NoaIMContactsPageIsValid(@{@"rows": @[], @"current": @1, @"pages": @0}, 1, NO), @"无好友的空页");
        CHECK(!NoaIMContactsPageIsValid(@{}, 1, NO), @"缺失分页字段不能成功");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": NSNull.null, @"current": @1, @"pages": @1}, 1, NO), @"null rows 不能崩溃或推进游标");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[@"不是对象"], @"current": @1, @"pages": @1}, 1, NO), @"好友条目必须为对象");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[], @"current": @1, @"pages": @2}, 2, NO), @"重复页不能造成无限请求");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[], @"current": @2, @"pages": @1}, 2, NO), @"分页总数必须有效");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[], @"current": NSNull.null, @"pages": @1}, 1, NO), @"null 进度必须拒绝");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[], @"current": @1, @"pages": @1.5}, 1, NO), @"小数分页必须拒绝");
        CHECK(NoaIMContactsPageIsValid(@{@"rows": @[@"friend-a"], @"current": @"1", @"pages": @"2"}, 1, YES), @"兼容字符串分页数");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[@{}], @"current": @1, @"pages": @1}, 1, YES), @"在线 UID 必须为字符串");
        CHECK(!NoaIMContactsPageIsValid(@{@"rows": @[@""], @"current": @1, @"pages": @1}, 1, YES), @"在线 UID 不能为空");
        NSMutableSet *onlineUIDs = [NSMutableSet set];
        NoaIMContactsMergeOnlinePage(onlineUIDs, @[@"friend-a"]);
        NoaIMContactsMergeOnlinePage(onlineUIDs, @[@"friend-b", @"friend-a"]);
        CHECK(([onlineUIDs isEqualToSet:[NSSet setWithArray:@[@"friend-a", @"friend-b"]]]), @"所有页的在线好友必须保留并去重");
        NoaIMContactsMergeOnlinePage(onlineUIDs, @[]);
        CHECK(onlineUIDs.count == 2, @"空尾页不能把前几页好友改为离线");
        CHECK(NoaIMContactsFriendStatusIsValid(@0) && NoaIMContactsFriendStatusIsValid(@"1"), @"正常增量状态允许删除或更新");
        CHECK(!NoaIMContactsFriendStatusIsValid(nil), @"缺失状态不能删除好友");
        CHECK(!NoaIMContactsFriendStatusIsValid(NSNull.null), @"null 状态不能删除好友");
        CHECK(!NoaIMContactsFriendStatusIsValid(@2), @"未知状态不能推进游标");
        CHECK(!NoaIMContactsFriendStatusIsValid(@0.5), @"小数状态不能作为删除事件");
        printf("SDK 通讯录分页验证通过：%lu 项\n", (unsigned long)checks);
    }
    return 0;
}
