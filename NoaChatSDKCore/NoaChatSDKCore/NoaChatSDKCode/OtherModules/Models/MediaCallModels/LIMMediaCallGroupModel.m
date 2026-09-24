//
//  LIMMediaCallGroupModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/8.
//

#import "LIMMediaCallGroupModel.h"

@implementation LIMMediaCallGroupModel
+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"hashKey" : @"hash"
    };
}
+ (NSDictionary *)mj_objectClassInArray
{
    return @{
        @"participants":@"LIMMediaCallGroupParticipant"
    };
}
@end
