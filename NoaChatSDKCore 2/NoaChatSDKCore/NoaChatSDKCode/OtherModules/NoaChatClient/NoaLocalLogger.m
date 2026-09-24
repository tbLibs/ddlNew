//
//  NoaLocalLogger.m
//  NoaChatSDKCore
//

#import "NoaLocalLogger.h"

static BOOL NoaLocalLoggerEnabled = NO;

@implementation NoaLocalLogger

+ (BOOL)isLoggingEnabled { return NoaLocalLoggerEnabled; }
+ (void)setLoggingEnabled:(BOOL)enabled { NoaLocalLoggerEnabled = enabled; }

+ (BOOL)setUp { return YES; }

+ (void)verbose:(NSString *)message {
    if (!NoaLocalLoggerEnabled) { return; }
    NSLog(@"[V] %@", message);
}

+ (void)debug:(NSString *)message {
    if (!NoaLocalLoggerEnabled) { return; }
    NSLog(@"[D] %@", message);
}

+ (void)info:(NSString *)message {
#if DEBUG
    // 重连诊断在调试包中直接输出，避免全局日志开关关闭时看不到链路步骤。
    if ([message hasPrefix:@"[TCP重连链路]"]) {
        NSLog(@"[I] %@", message);
        return;
    }
#endif
    if (!NoaLocalLoggerEnabled) { return; }
    NSLog(@"[I] %@", message);
}

+ (void)warn:(NSString *)message {
    if (!NoaLocalLoggerEnabled) { return; }
    NSLog(@"[W] %@", message);
}

+ (void)error:(NSString *)message {
    if (!NoaLocalLoggerEnabled) { return; }
    NSLog(@"[E] %@", message);
}

@end
