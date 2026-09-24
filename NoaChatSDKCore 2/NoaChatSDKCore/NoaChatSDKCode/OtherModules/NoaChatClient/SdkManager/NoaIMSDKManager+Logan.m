//
//  NoaIMSDKManager+Logan.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/17.
//

#import "NoaIMSDKManager+Logan.h"

@implementation NoaIMSDKManager (Logan)

#pragma mark - 配置日志信息
- (void)imSdkOpenLoganWith:(NoaIMLoganOption *)loganOption {
    if (loganOption) {
        [[NoaIMLoganManager sharedManager] configLoganOption:loganOption];
        [NoaIMUncaughtExceptionHandler setUncaughtExceptionHandler];
        [NoaIMSignalExceptionHandler setSignalExceptionHandler];
    }
}

- (void)configLoganLiceseId:(NSString *)loganLiceseId {
    [[NoaIMLoganManager sharedManager] configLoganLiceseId:loganLiceseId];
}

#pragma mark - 写入日志
- (void)imSdkWriteLoganWith:(LingIMLoganType)loganType loganContent:(NSString *)loganContent {
    [[NoaIMLoganManager sharedManager] writeLoganWith:loganType loganContent:loganContent];
}

#pragma mark - 上传日志
- (void)imSdkUploadLoganWith:(NSString *)loganDate complete:(LingIMSDKLoganUpload)aComplete {
    [[NoaIMLoganManager sharedManager] loganUploadWith:loganDate complete:aComplete];
}

#pragma mark - 清空日志模块用户信息
- (void)imSdkClearLoganOption {
    [[NoaIMLoganManager sharedManager] clearLoganUserInfo];
}

@end

