//
//  NoaIMUncaughtExceptionHandler.m
//  CIMSDKCore
//
//  Created by Candy on 2023/5/16.
//

#import "NoaIMUncaughtExceptionHandler.h"
#import "NoaIMLoganManager.h"

//先判断是否有前者已经注册了handler，如果有则应该把这个handler保存下来，在自己处理完自己的handler之后，再把这个歌handler抛出去，供前面的注册者处理
static NSUncaughtExceptionHandler *previousUncaughtExceptionHandler;

@implementation NoaIMUncaughtExceptionHandler

#pragma mark - NSSetUncaughtExceptionHandler
+ (void)setUncaughtExceptionHandler {
    previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandlers);
}

#pragma mark - 捕获异常
static void uncaughtExceptionHandlers (NSException *exception) {
    //利用 NSSetUncaughtExceptionHandler，当程序异常退出的时候，可以先进行处理，然后做一些自定义的动作
    NSArray *arr = [exception callStackSymbols];//得到当前调用堆栈信息
    NSString *reason = [exception reason];//异常的原因
    NSString *name = [exception name];//异常类型
    NSString *exceptionContent = [NSString stringWithFormat:@"Exception name:%@\nException reason:%@\nException stack:%@", name, reason, arr];
    
    //存储到日志模块
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:exceptionContent forKey:@"exceptionInfo"];
    [[NoaIMLoganManager sharedManager] writeLoganWith:LingIMLoganTypeException loganContent:[[NoaIMLoganManager sharedManager] configLoganContent:loganDict]];
    
//    if (previousUncaughtExceptionHandler) {
//        previousUncaughtExceptionHandler(exception);
//    }
//    
    //保存到本地
    //NSString *crashPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingString:@"/crashException.txt"];
    //[exceptionContent writeToFile:crashPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
}

#pragma mark - 获取异常信息
+ (NSUncaughtExceptionHandler *)getHandler {
    return NSGetUncaughtExceptionHandler();
}

@end
