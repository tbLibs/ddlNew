//
//  LIMMediaCallGroupParticipant.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/8.
//

#import "LIMMediaCallGroupParticipant.h"

@implementation LIMMediaCallGroupParticipant
+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"userUid" : @"id",
        @"hashKey" : @"hash"
    };
}


+ (NSDictionary *)mj_objectClassInArray {
    return @{
        @"participants":@"LIMMediaCallGroupParticipant"
    };
}

@end
