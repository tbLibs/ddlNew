//
//  LXChatEncrypt.h
//  LXChatEncrypt
//
//  Created by Candy on 2024/7/10.
//

#import <Foundation/Foundation.h>

@interface LXChatEncrypt : NSObject

+ (NSString *)method1:(NSString *)encryptData key:(NSString *)key;

+ (NSString *)method2:(NSString *)encryptData;

+ (NSString *)method3:(NSString *)encryptData;

+ (NSString *)method4:(NSString *)passwordData;

+ (NSString *)method5:(NSString *)method uri:(NSString *)uri timestamp:(long long)timestamp;

+ (NSString *)method6:(NSString *)encryptData;

+ (NSString *)method7:(NSString *)method encryptData:(NSString *)encryptData;

+ (NSString *)method8:(NSString *)encryptData;
@end
