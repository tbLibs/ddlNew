//
//  NoaIMManagerTool.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/9/29.
//

// CIMSDK工具类单例

#import <Foundation/Foundation.h>
#import "FCUUID.h"

NS_ASSUME_NONNULL_BEGIN



@interface NoaIMManagerTool : NSObject

#pragma mark - 单例
+ (instancetype)sharedManager;
//单例一般不需要清空，但是在执行某些功能的时候，防止数据更换不及时，可以清空一下
- (void)clearManager;

#pragma mark - 业务

/// 获取消息内容长度
/// @param data 消息体
/// @param index 消息头部长度
-(int32_t)getMessageContentLenght:(NSData *)data withHeaderLength:(int32_t *)index;

/// 获得消息的唯一标识
- (NSString *)getMessageID;

/// 获取当前SDK的版本号
- (NSString *)getCurrentSdkVersion;

/// 获得IP地址
/// @param preferIPV4 ipv4
- (NSString *)getIPAddress:(BOOL)preferIPV4;

#pragma mark - 获取当前设备的公网IP
- (NSString *)getDevicePublicNetworkIP;

//IDFV
- (NSString *)appIDFV;

//设备唯一标识
- (NSString *)appUniqueIdentifier;

//移除字符串中的特殊字符
- (NSString *)stringReplaceSpecialCharacterWith:(NSString *)oldStr;
@end

NS_ASSUME_NONNULL_END
