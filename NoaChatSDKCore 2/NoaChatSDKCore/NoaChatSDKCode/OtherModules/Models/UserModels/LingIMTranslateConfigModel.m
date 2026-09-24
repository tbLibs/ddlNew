//
//  LingIMTranslateConfigModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/11/24.
//

#import "LingIMTranslateConfigModel.h"

@implementation LingIMTranslateConfigModel

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"configId" : @"id",
    };
}


@end
