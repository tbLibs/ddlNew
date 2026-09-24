//
//  NoaIMLoganOption.h
//  CIMSDKCore
//
//  Created by Candy on 2023/5/17.
//

// 日志模块配置参数

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMLoganOption : NSObject

@property (nonatomic, copy) NSString *loganKey;//日志模块，16位aes加密key
@property (nonatomic, copy) NSString *loganIV;//日志模块，16位aes加密iv
@property (nonatomic, assign) uint64_t loganFileMax;//日志模块，日志文件最大大小，超过该大小后日志将不再被写入，单位:bytes。

@property (nonatomic, copy) NSString *loganUploadUrl;//日志模块，上传服务器的完整地址
@property (nonatomic, copy) NSString *loganUploadExpediteUrl;//日志模块，上传服务器的完整地址(加速)
@property (nonatomic, copy) NSString *loganUserUnionId;//日志模块，当前用户的唯一标识
@property (nonatomic, copy) NSString *loganUserName;//日志模块，当前用户的账号名
@property (nonatomic, copy) NSString *loganLiceseId;//日志模块，邀请码ID
@end

NS_ASSUME_NONNULL_END
