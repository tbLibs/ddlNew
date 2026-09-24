//
//  LingIMTcpCommonTool.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/6/27.
//

#import "LingIMTcpCommonTool.h"
#import "LXChatEncrypt.h"
#import "NoaIMSDKManager.h"

@implementation LingIMTcpCommonTool

/// MARK: 接口返回的data解密处理
+ (id)responseDataDescryptWithDataString:(id)obj url:(NSString *)url {
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *dataString = (NSString *)obj;
        BOOL dataStringIsJson = [self isValidJsonString:dataString];
//        NSLog(@"解密-- 加密字符串：%@",dataString);
        //如果 dataString 是一个有效Json
        if(dataStringIsJson) {
            id jsonObj = [self jsonDecode:dataString];
            return jsonObj;
        }else{
            //对 dataString 尝试解密
            NSString *descryptDataStr;
            if ([url containsString:@"system/v2/getSystemConfig"]) {
                descryptDataStr = [LXChatEncrypt method6:dataString];
            } else {
                descryptDataStr = [LXChatEncrypt method7:[IMSDKManager tenantCode] encryptData:dataString];
            }
//            NSLog(@"解密-- 解密字符串：%@",descryptDataStr);
            
            if(descryptDataStr == nil){
                //解密失败
                return dataString;
            }else{
                //解密成功
                BOOL descryptDataStrIsJson = [self isValidJsonString:descryptDataStr];
                if(descryptDataStrIsJson){
                    id descryptObj = [self jsonDecode:descryptDataStr];
//                    NSLog(@"解密-- 2解密字符Json对象：%@",descryptObj);
                    return descryptObj;
                }else{
//                    NSLog(@"解密-- 2解密字符串：%@",descryptDataStr);
                    return descryptDataStr;
                }
            }
        }
    } else {
        return obj;
    }
}

+ (BOOL)isValidJsonString:(NSString *)str {
    NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return NO;
    }
    
    @try {
        NSError *error = nil;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&error];
        return (jsonObject != nil && error == nil);
    } @catch (NSException *exception) {
        return NO;
    }
}

/// 对象转换为字符串
/// - Parameter obj: 需要转换的对象
+ (NSString *)jsonEncode:(id)obj {
    if (!obj || ![NSJSONSerialization isValidJSONObject:obj]) {
        return @"";
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingPrettyPrinted error:&error];
    if (error || !jsonData) {
        return @"";
    }
    NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (!jsonString) {
        return @"";
    }
    return jsonString;
}

+ (id)jsonDecode:(NSString *)jsonString {
    if (!jsonString || jsonString.length == 0) {
        return nil;
    }
    
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return nil;
    }
    
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    return error ? nil : jsonObject;
}


@end
