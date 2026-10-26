//
//  NoaIMManagerTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/9/29.
//

#import "NoaIMManagerTool.h"
#import <UIKit/UIKit.h>
//#import <SAMKeychain.h>


//单例
static dispatch_once_t onceToken;

@interface NoaIMManagerTool ()

@end

@implementation NoaIMManagerTool

#pragma mark - 单例
+ (instancetype)sharedManager {
    static NoaIMManagerTool *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMManagerTool sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMManagerTool sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMManagerTool sharedManager];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearManager{
    onceToken = 0;
}

#pragma mark - ******业务******
#pragma mark - 获取消息内容长度
- (int32_t)getMessageContentLenght:(NSData *)data withHeaderLength:(int32_t *)index {
    
    int8_t tmp = [self readRawByte:data headIndex:index];
    
    if (tmp >= 0) return tmp;
    
    int32_t result = tmp & 0x7f;
    if ((tmp = [self readRawByte:data headIndex:index]) >= 0) {
        result |= tmp << 7;
    } else {
        result |= (tmp & 0x7f) << 7;
        if ((tmp = [self readRawByte:data headIndex:index]) >= 0) {
            result |= tmp << 14;
        } else {
            result |= (tmp & 0x7f) << 14;
            if ((tmp = [self readRawByte:data headIndex:index]) >= 0) {
                result |= tmp << 21;
            } else {
                result |= (tmp & 0x7f) << 21;
                result |= (tmp = [self readRawByte:data headIndex:index]) << 28;
                if (tmp < 0) {
                    for (int i = 0; i < 5; i++) {
                        if ([self readRawByte:data headIndex:index] >= 0) {
                            return result;
                        }
                    }
                    
                    result = -1;
                }
            }
        }
    }
    return result;
}

/// 获取当前SDK的版本号
- (NSString *)getCurrentSdkVersion {
    return @"sdk_1.0.0";
}

//读取字节
- (int8_t)readRawByte:(NSData *)data headIndex:(int32_t *)index {
    if (*index >= data.length) return -1;
    
    *index = *index + 1;
    return ((int8_t *)data.bytes)[*index - 1];
}

#pragma mark - 获得消息的唯一标识
- (NSString *)getMessageID {
    //iOS6出现的方法，每次调用，都会产生一个新值
    NSString *uuid = [[NSUUID UUID] UUIDString];//973FC752-75EA-4217-BEB3-CF5DD0610FC2
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    uuid = [uuid lowercaseString];
    return uuid;
}

#pragma mark - IDFV
- (NSString *)appIDFV{
    NSString *strIDFV = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return strIDFV;
}

- (NSString *)appUniqueIdentifier{
//    //服务名
//    NSString *serviceName = [NSBundle mainBundle].bundleIdentifier;
//    //键名
//    NSString *accountKey = @"CIMSDKDEVICEID";
//    //将(IDFV+keychain)作为设备唯一标识
//    NSString *IDFVStr = [SAMKeychain passwordForService:serviceName account:accountKey];
//    if ([IDFVStr isEqualToString:@""] || IDFVStr == nil) {
//        IDFVStr = [self appIDFV];
//        [SAMKeychain setPassword:IDFVStr forService:serviceName account:accountKey];
//    }
//    return IDFVStr ? IDFVStr : @"未知设备";
//    //return @"5DDD17B7-1DF8-4DF4-BB50-1E318446B90A";
    
    return [FCUUID uuidForDevice];
}

#pragma mark - 移除字符串中的特殊字符
- (NSString *)stringReplaceSpecialCharacterWith:(NSString *)oldStr {
    if (oldStr.length > 0) {
        //NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"@／：；（）¥「」＂、[]{}#%-*+=_\\|~＜＞$€^•'@#$%^&*()_+'\""];
        NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"%_"];
        //由于NSString中有全角符号和半角符号, 因此有些符号要包括全角和半角的
        NSString *newStr = [oldStr stringByTrimmingCharactersInSet:set];
        return newStr;
    }else {
        return oldStr;
    }
}

@end
