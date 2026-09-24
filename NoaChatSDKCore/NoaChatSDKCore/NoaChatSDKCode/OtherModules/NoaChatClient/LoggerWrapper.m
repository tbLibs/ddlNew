//
//  LoggerWrapper.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/1/27.
//

#import "LoggerWrapper.h"
#import "NoaLocalLogger.h"

void LoggerInfo(NSString * _Nonnull message) {
    [NoaLocalLogger info:message];
}

void LoggerError(NSString * _Nonnull message) {
    [NoaLocalLogger error:message];
}

void LoggerWarn(NSString * _Nonnull message) {
    [NoaLocalLogger warn:message];
}

void LoggerDebug(NSString * _Nonnull message) {
    [NoaLocalLogger debug:message];
}

void LoggerVerbose(NSString * _Nonnull message) {
    [NoaLocalLogger verbose:message];
}
