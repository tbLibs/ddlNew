//
//  LoggerWrapper.h
//  NoaChatSDKCore
//
//  Created by phl on 2025/1/27.
//

#ifndef LoggerWrapper_h
#define LoggerWrapper_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// C 风格的函数，可以在 .mm 文件中安全调用
void LoggerInfo(NSString * _Nonnull message);
void LoggerError(NSString * _Nonnull message);
void LoggerWarn(NSString * _Nonnull message);
void LoggerDebug(NSString * _Nonnull message);
void LoggerVerbose(NSString * _Nonnull message);

#ifdef __cplusplus
}
#endif

#endif /* LoggerWrapper_h */
