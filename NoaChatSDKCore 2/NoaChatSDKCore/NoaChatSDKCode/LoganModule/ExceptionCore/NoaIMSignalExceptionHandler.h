//
//  NoaIMSignalExceptionHandler.h
//  CIMSDKCore
//
//  Created by Candy on 2023/5/17.
//

// 崩溃处理
//https://developer.huawei.com/consumer/cn/forum/topic/0203721046139040273?fid=0101271690375130218
//SignalHandler不要在debug环境下测试。因为系统的debug会优先去拦截。我们要运行一次后，关闭debug状态，直接在模拟器上点击我们build上去的app运行

#import <Foundation/Foundation.h>

typedef void (^LingIMSignalExceptionBlock)(NSString * _Nullable exceptionContent);

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSignalExceptionHandler : NSObject
+ (void)setSignalExceptionHandler;
@end

NS_ASSUME_NONNULL_END
