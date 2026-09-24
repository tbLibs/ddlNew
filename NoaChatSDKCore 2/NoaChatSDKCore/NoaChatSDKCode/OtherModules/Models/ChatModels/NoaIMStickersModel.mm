//
//  NoaIMStickersModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import "NoaIMStickersModel+WCTTableCoding.h"
#import "NoaIMStickersModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation NoaIMStickersModel

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"stickersId" : @"id"
    };
}


WCDB_IMPLEMENTATION(NoaIMStickersModel)

WCDB_PRIMARY(stickersId)//主键

WCDB_SYNTHESIZE(contentUrl)
WCDB_SYNTHESIZE(fileName)
WCDB_SYNTHESIZE(height)
WCDB_SYNTHESIZE(stickersId)
WCDB_SYNTHESIZE(isDeleted)
WCDB_SYNTHESIZE(name)
WCDB_SYNTHESIZE(size)
WCDB_SYNTHESIZE(sort)
WCDB_SYNTHESIZE(stickersKey)
WCDB_SYNTHESIZE(stickersSetId)
WCDB_SYNTHESIZE(thumbUrl)
WCDB_SYNTHESIZE(type)
WCDB_SYNTHESIZE(updateTime)
WCDB_SYNTHESIZE(updateUserName)
WCDB_SYNTHESIZE(userUid)
WCDB_SYNTHESIZE(width)
WCDB_SYNTHESIZE(isStickersSet)
@end
