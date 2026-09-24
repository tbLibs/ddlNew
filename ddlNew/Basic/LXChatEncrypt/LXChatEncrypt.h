//
//  LXChatEncrypt.h
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 老项目独立加密静态库的公开接口；当前只使用 method5 和 method6。
@interface LXChatEncrypt : NSObject

+ (nullable NSString *)method1:(NSString *)encryptData key:(NSString *)key;
+ (nullable NSString *)method2:(NSString *)encryptData;
+ (nullable NSString *)method3:(NSString *)encryptData;
+ (nullable NSString *)method4:(NSString *)passwordData;
+ (nullable NSString *)method5:(NSString *)method uri:(NSString *)uri timestamp:(long long)timestamp;
+ (nullable NSString *)method6:(NSString *)encryptData;
+ (nullable NSString *)method7:(NSString *)method encryptData:(NSString *)encryptData;
+ (nullable NSString *)method8:(NSString *)encryptData;

@end

NS_ASSUME_NONNULL_END
