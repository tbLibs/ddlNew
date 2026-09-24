//
//  NoaIMUncaughtExceptionHandler.h
//  CIMSDKCore
//
//  Created by Candy on 2023/5/16.
//

// 崩溃处理
//https://developer.huawei.com/consumer/cn/forum/topic/0204721042700470435?fid=0101271690375130218
//caughtExceptionHandler可以在调试状态下捕捉

#import <Foundation/Foundation.h>

typedef void (^LingIMUncaughtExceptionBlock)(NSString * _Nullable exceptionContent);

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMUncaughtExceptionHandler : NSObject

+ (void)setUncaughtExceptionHandler;

+ (NSUncaughtExceptionHandler *)getHandler;

@end

NS_ASSUME_NONNULL_END

//iOS的crash捕获分两种情况，有OC类异常和Signal信号捕获。
//
//OC类异常，可以先通过NSGetUncaughtExceptionHandler保存先前注册的异常处理器，然后通过NSSetUncaughtExceptionHandler设置我们自己的异常处理器。处理结束后，需要在设置会原来的异常处理器。在我们自己的customUncaughtExceptionHandler里，需要手动调用下原来的处理器。
//
//Signal信号捕获，Signal信号是由iOS底层mach信号异常转换后，以signal信号抛出的异常。既然是兼容posix标准的异常，我们可以用sigaction函数注册对应的信号。
//
//这里，我们就知道了在iOS里如何使用代码进行crash的捕获。
//
//因为xcode支持崩溃日志自动符号化，前提是本地有当时build/archive生成的dsym文件。我们在xcode上运行，崩溃日志已经自动符号化了。但如果dsym文件丢失或者拿到的崩溃日志不是标准的crash log，如何定位crash呢。
//https://developer.huawei.com/consumer/cn/forum/topic/0204738547149110987?fid=0101271690375130218
