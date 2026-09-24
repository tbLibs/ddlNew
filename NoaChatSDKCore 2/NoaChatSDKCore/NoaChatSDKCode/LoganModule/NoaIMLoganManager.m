//
//  NoaIMLoganManager.m
//  CIMSDKCore
//
//  Created by Candy on 2023/5/16.
//

#import "NoaIMLoganManager.h"
//获取设备唯一标识
#import "FCUUID.h"
#import "LingIMMacorHeader.h"
#import "NoaIMUncaughtExceptionHandler.h"
#import "NoaIMDeviceTool.h"
#import <MJExtension/MJExtension.h>

//单例
static dispatch_once_t onceToken;

@interface NoaIMLoganManager ()
@property (nonatomic, strong) NoaIMLoganOption *loganOption;
@end

@implementation NoaIMLoganManager

#pragma mark - ******单例******
+ (instancetype)sharedManager {
    static NoaIMLoganManager *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMLoganManager sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMLoganManager sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMLoganManager sharedManager];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearTool {
    onceToken = 0;
}
#pragma mark - 配置日志参数
- (void)configLoganOption:(NoaIMLoganOption *)loganOption {
    if (loganOption) {
        _loganOption = loganOption;
        
        //16位aes加密key
        NSData *keyData = [loganOption.loganKey dataUsingEncoding:NSUTF8StringEncoding];
        //16位aes加密iv
        NSData *ivData = [loganOption.loganIV dataUsingEncoding:NSUTF8StringEncoding];
        //日志文件最大大小，超过该大小后日志将不再被写入，单位:bytes。
        uint64_t file_max = loganOption.loganFileMax;

        //在使用之前，必须初始化Logan
        //重要，在实际使用时要用自己的key和iv替换这里的key和iv。最好在App每次发布新版本的时候更新key和iv。后面我们会开源更加安全的加密方案，让日志存储更加安全
        //NSData *keydata = [@"0123456789012345" dataUsingEncoding:NSUTF8StringEncoding];
        //NSData *ivdata = [@"0123456789012345" dataUsingEncoding:NSUTF8StringEncoding];
        //uint64_t file_max = 20 * 1024 * 1024;
        //loganInit(keydata, ivdata, file_max);
        
    }
    
}

- (void)configLoganLiceseId:(NSString *)loganLiceseId {
    _loganOption.loganLiceseId = loganLiceseId;
}

#pragma mark - 写入日志
- (void)writeLoganWith:(LingIMLoganType)loganType loganContent:(NSString *)loganContent {
    if (_loganOption) {

    }else {
        CIMLog(@"请配置日志参数");
    }
}

#pragma mark - 上传日志
//使用默认地址上传
- (void)loganUploadWith:(NSString *)loganDate complete:(LingIMLoganUpload)aComplete {
    
    if (_loganOption) {
        NSString *loganUrl = _loganOption.loganUploadUrl;//接受日志的服务器完整url
        NSString *dateType = loganDate;
        //loganTodaysDate();//上传当天日志 日志日期 格式："2018-11-21"
        NSString *appId = [[NSBundle mainBundle]bundleIdentifier];//当前应用的唯一标识,在多App时区分日志来源App
        NSString *unionId = _loganOption.loganUserUnionId.length > 0 ? _loganOption.loganUserUnionId : @"NONE";//当前用户的唯一标识,用来区分日志来源用户
        //设备标识
        NSString *companyID = _loganOption.loganLiceseId.length > 0 ? _loganOption.loganLiceseId : @"NONE COMPANY / IP"; //邀请码/IP/域名
        NSString *deviceId; //deviceId 设备号
        if (_loganOption.loganUserUnionId.length > 0) {
            if (_loganOption.loganUserName.length > 0) {
                deviceId = [NSString stringWithFormat:@"%@-%@", companyID, _loganOption.loganUserName];
            } else {
                deviceId = companyID;
            }
        } else {
            deviceId = companyID;
        }
    } else {
        CIMLog(@"请配置日志参数");
        NSError *error = [NSError errorWithDomain:@"come.meituan.logan.error" code:-1000 userInfo:@{@"info" : [NSString stringWithFormat:@"缺少日志模块关键信息"]}];
        if (aComplete) {
            aComplete(error);
        }
    }
}

#pragma mark - 清除日志模块的用户信息
- (void)clearLoganUserInfo {
    if (_loganOption) {
        _loganOption.loganUserUnionId = @"NONE";
    }
}
#pragma mark - 配置日志的完整内容
- (NSString *)configLoganContent:(NSDictionary *)dict {
    NSString *jsonString;
    NSMutableDictionary *dictLogan;
    if (!dict) {
        dictLogan = [NSMutableDictionary dictionary];
    }else {
        dictLogan = [NSMutableDictionary dictionaryWithDictionary:dict];
    }
    
    //通用参数配置
    //设备平台
    [dictLogan setValue:@"iOS" forKey:@"device"];
    //设备型号
    [dictLogan setValue:[NoaIMDeviceTool currentDeviceModel] forKey:@"deviceBrand"];
    //设备号
    [dictLogan setValue:[FCUUID uuidForDevice] forKey:@"deviceId"];//设备标识
    //当前时间戳(毫秒)
    NSDate *date = [NSDate date];
    long long time = [date timeIntervalSince1970] * 1000;
    [dictLogan setValue:@(time) forKey:@"reportTime"];
    //App版本或者SDK版本(此处使用的是App版本)
    [dictLogan setValue:[NoaIMDeviceTool appVersion] forKey:@"version"];
    //当前用户ID
    NSString *userID = _loganOption.loganUserUnionId.length > 0 ? _loganOption.loganUserUnionId : @"NONE";
    [dictLogan setValue:userID forKey:@"userUid"];
    //邀请码/IP/域名
    NSString *companyID = _loganOption.loganLiceseId.length > 0 ? _loganOption.loganLiceseId : @"NONE COMPANY / IP";
    [dictLogan setValue:companyID forKey:@"liceseId"];
    
    //******根据具体的场景进行配置的参数******
    
    //接口地址 oprApi
    
    //操作接口传的参数 oprParams (json字符串)
    
    //ZITD NSString * zitd = [manager.requestSerializer.HTTPRequestHeaders objectForKey:@"ZITD"];
    //[dictLogan setValue:@"tempZitd" forKey:@"zitd"];
    
    //失败原因 failReason
    
    //连接地址 socketHost
    
    //崩溃信息 exceptionInfo (json字符串)
    
    jsonString = [dictLogan mj_JSONString];
    return jsonString;
}

@end
