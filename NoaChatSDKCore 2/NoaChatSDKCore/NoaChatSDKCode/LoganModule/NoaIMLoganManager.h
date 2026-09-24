//
//  NoaIMLoganManager.h
//  CIMSDKCore
//
//  Created by Candy on 2023/5/16.
//



#import <Foundation/Foundation.h>
#import "NoaIMLoganOption.h"

//日志上传服务器回调
typedef void (^LingIMLoganUpload)(NSError * _Nullable error);

//日志类型
typedef NS_ENUM(NSUInteger, LingIMLoganType) {
    LingIMLoganTypeCommon = 0,         //通用日志
    LingIMLoganTypeException = 1,      //崩溃日志
    LingIMLoganTypeHost = 2,           //长连接日志
    LingIMLoganTypeApi = 3,            //接口日志
};

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMLoganManager : NSObject

#pragma mark - 单例
+ (instancetype)sharedManager;
//单例一般不需要清空，但是在执行某些功能的时候，防止数据更换不及时，可以清空一下
- (void)clearTool;

//配置日志参数
- (void)configLoganOption:(NoaIMLoganOption *)loganOption;

//配置liceseId
- (void)configLoganLiceseId:(NSString *)loganLiceseId;

//写入日志
- (void)writeLoganWith:(LingIMLoganType)loganType loganContent:( NSString * _Nullable)loganContent;

//上传日志
- (void)loganUploadWith:(NSString *)loganDate complete:(LingIMLoganUpload _Nullable)aComplete;

//清除日志的用户信息
- (void)clearLoganUserInfo;

#pragma mark - 配置日志的完整内容
- (NSString *)configLoganContent:(NSDictionary * _Nullable )dict;

@end

NS_ASSUME_NONNULL_END
