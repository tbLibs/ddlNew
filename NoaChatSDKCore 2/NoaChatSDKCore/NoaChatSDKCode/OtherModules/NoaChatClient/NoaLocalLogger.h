//
//  NoaLocalLogger.h
//  NoaChatSDKCore
//
//  替代已移除的 LocalLogLib，提供同名能力的轻量实现（可开关、默认不写文件，仅按开关输出到系统日志）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaLocalLogger : NSObject

+ (BOOL)isLoggingEnabled;
+ (void)setLoggingEnabled:(BOOL)enabled;

/// 原 Logger.setUp，此处恒为成功（不再初始化 CocoaLumberjack）
+ (BOOL)setUp;

+ (void)verbose:(NSString *)message;
+ (void)debug:(NSString *)message;
+ (void)info:(NSString *)message;
+ (void)warn:(NSString *)message;
+ (void)error:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
