//
//  LIMMassMessageModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/4/23.
//

#import "LIMMassMessageModel.h"

@implementation LIMMassMessageBodyModel


@end

@implementation LIMMassMessageModel
+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"taskId" : @"id",
        @"bodyModel" : @"body"
    };
}
@end
