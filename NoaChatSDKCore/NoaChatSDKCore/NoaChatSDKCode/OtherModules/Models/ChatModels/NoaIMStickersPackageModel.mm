//
//  NoaIMStickersPackageModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import "NoaIMStickersPackageModel+WCTTableCoding.h"
#import "NoaIMStickersPackageModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation NoaIMStickersPackageModel

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"stickersDes" : @"description",
        @"packageId" : @"id"
    };
}

//+ (NSDictionary *)mj_objectClassInArray {
//    return @{
//        @"stickersList":[LingIMStickersModel class]
//    };
//}

WCDB_IMPLEMENTATION(NoaIMStickersPackageModel)

WCDB_PRIMARY(packageId)//主键

WCDB_SYNTHESIZE(coverFile)
WCDB_SYNTHESIZE(stickersDes)
WCDB_SYNTHESIZE(packageId)
WCDB_SYNTHESIZE(isDownLoad)
WCDB_SYNTHESIZE(isDeleted)
WCDB_SYNTHESIZE(name)
WCDB_SYNTHESIZE(status)
WCDB_SYNTHESIZE(stickersCount)
//WCDB_SYNTHESIZ, stickersList)
WCDB_SYNTHESIZE(stickersListJsonStr)
WCDB_SYNTHESIZE(thumbUrl)
WCDB_SYNTHESIZE(updateTime)
WCDB_SYNTHESIZE(updateUserName)
WCDB_SYNTHESIZE(useCount)

//获得表情包里的表情列表
- (NSArray <NoaIMStickersModel *> *)stickersList {
    NSArray *tempStickersList = [self jsonStringToArr:_stickersListJsonStr];
    NSArray <NoaIMStickersModel *> *resultStickersList = [NoaIMStickersModel mj_objectArrayWithKeyValuesArray:tempStickersList];
    return resultStickersList;
}

#pragma mark - 将json字符串转换成数组
- (NSArray *)jsonStringToArr:(NSString *)jsonString {
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:jsonData
                                                   options:kNilOptions error:&err];
    return arr;
}

@end
