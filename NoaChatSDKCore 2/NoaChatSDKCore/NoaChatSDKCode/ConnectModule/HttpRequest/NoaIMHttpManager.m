//
//  NoaIMHttpManager.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/19.
//

#import "NoaIMHttpManager.h"
//获取设备唯一标识
#import "FCUUID.h"
//数据解析
#import <MJExtension/MJExtension.h>
#import "NoaIMSDKManager.h"
#import "NoaIMDeviceTool.h"
#import "LXChatEncrypt.h"
#import <MMKV/MMKV.h>
#import "NoaIMLoganManager.h"

@interface NoaIMHttpManager()

@end

@implementation NoaIMHttpManager
{
    NSCache *_interfaceTimeConsumingCatche;//接口耗时统计 NSCache是线程安全的
}

static NoaIMHttpManager *manager = nil;

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self setConfig];
    });
    return manager;
}

- (instancetype)init{
    if(self = [super init]){
        
    }
    return self;
}


//网络请求配置
+ (NoaIMHttpManager *)setConfig {
    //基本网络地址
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.connectionProxyDictionary = @{}; // 关闭系统代理
    NoaIMHttpManager *httpManager = [[NoaIMHttpManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://www.baidu.com"] sessionConfiguration:config];
    //安全模式设置：AFSSLPinningModeNone：完全信任服务器证书
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    // 允许无效证书（自签名证书、过期证书等），默认为 NO
    securityPolicy.allowInvalidCertificates = YES;
    // 不验证域名，允许使用 IP 地址访问 HTTPS，默认为 YES
    // 注意：设置为 NO 会降低安全性，仅在开发/测试环境或使用 IP 访问时使用
    securityPolicy.validatesDomainName = NO;
    httpManager.securityPolicy = securityPolicy;
    
    //JSON解析
    httpManager.requestSerializer = [AFJSONRequestSerializer serializer];
    
    //超时时长
    httpManager.requestSerializer.timeoutInterval = 60;
    
    //响应
    NSMutableSet *set = [NSMutableSet setWithSet:httpManager.responseSerializer.acceptableContentTypes];
    [set addObject:@"text/html"];
    [set addObject:@"text/json"];
    [set addObject:@"text/javascript"];
    [set addObject:@"text/plain"];
    [set addObject:@"text/css"];
    [set addObject:@"text/xml"];
    [set addObject:@"application/json"];
    [set addObject:@"application/rtf"];
    [set addObject:@"application/zip"];
    [set addObject:@"application/x-shockwave-flash"];
    [set addObject:@"application/vnd.ms-powerpoint"];
    [set addObject:@"application/x-javascript"];
    [set addObject:@"application/x-gzip"];
    [set addObject:@"application/x-gtar"];
    [set addObject:@"application/msword"];
    [set addObject:@"image/png"];
    [set addObject:@"image/jpeg"];
    [set addObject:@"image/gif"];
    [set addObject:@"image/tiff"];
    [set addObject:@"audio/x-wav"];
    [set addObject:@"video/mpeg"];
    [set addObject:@"video/quicktime"];
    [set addObject:@"video/x-msvideo"];
    
    //移除网络请求返回的null
    AFJSONResponseSerializer *response = [AFJSONResponseSerializer serializer];
    response.removesKeysWithNullValues = YES;
    httpManager.responseSerializer = response;
    
    httpManager.responseSerializer.acceptableContentTypes = set;
    
    httpManager->_interfaceTimeConsumingCatche = [NSCache new];
    
    return httpManager;
}

//请求header配置
- (NSDictionary *)configHttpHeaderWithUrl:(NSString *)url {
    NSMutableDictionary *headerDic = [NSMutableDictionary dictionary];
    //设备类型 ANDROID，IOS，WEB，IOT，PC，WINDOWS，MAC
    [headerDic setObject:@"IOS" forKey:@"deviceType"];
    //deviceUuid多租户
    [headerDic setObject:[FCUUID uuidForDevice] forKey:@"deviceUuid"];
    //日志跟踪
    [headerDic setObject:[[NoaIMManagerTool sharedManager] getMessageID] forKey:@"ZTID"];
    //版本号
    [headerDic setObject:[NoaIMDeviceTool appVersion] forKey:@"version"];
    //租户信息
    [headerDic setObject:[IMSDKManager orgName] forKey:@"orgName"];
    //token信息
    [headerDic setObject:[IMSDKManager myUserToken] forKey:@"token"];
    //loginuseruid
    [headerDic setObject:[IMSDKManager myUserID] forKey:@"loginuseruid"];
    //设备凭证为空时不发送，兼容首次登录和旧缓存用户
    NSString *deviceSecret = [IMSDKManager myDeviceSecret];
    if (deviceSecret.length > 0) {
        [headerDic setObject:deviceSecret forKey:@"deviceSecret"];
    }
    //liceseId
    if ([IMSDKManager currentLiceseId].length > 0) {
        [headerDic setObject:[IMSDKManager currentLiceseId] forKey:@"conid"];
    }
    /** 接口验签 */
    //timestamp
    long long timeStamp = [NSDate getCurrentTimeIntervalWithSecond];
    [headerDic setObject:[NSString stringWithFormat:@"%lld", timeStamp] forKey:@"timestamp"];
    //signature
    NSString *signature = [self getUrlSignature:timeStamp url:url];
    [headerDic setObject:signature forKey:@"signature"];
    
    return [headerDic copy];
}

- (NSString *)getUrlSignature:(long long)timestamp url:(NSString *)url {
    //接口名
    NSString *uri = @"";
    NSString *method = @"";
    if ([url containsString:@"system/v2/getSystemConfig"]) {
        uri = @"system/v2/getSystemConfig";
        method = @"getSystemConfig";
    } else {
        if ([url hasPrefix:@"http"]) {
            url = [url stringByReplacingOccurrencesOfString:IMSDKManager.apiHost withString:@""];
        }
        uri = [url stringByReplacingOccurrencesOfString:@"/biz/" withString:@""];
        uri = [uri stringByReplacingOccurrencesOfString:@"/auth/" withString:@""];
        uri = [uri stringByReplacingOccurrencesOfString:@"/zim-file/" withString:@""];
        uri = [uri stringByReplacingOccurrencesOfString:@"/file/" withString:@""];
        method = [IMSDKManager tenantCode];
    }
    
    NSString *signature = [LXChatEncrypt method5:method uri:uri timestamp:timestamp];
    return signature;
}

#pragma mark - ******1.数据请求******
- (void)netRequestWithType:(LingIMHttpRequestType)type path:(NSString *)path parameters:(NSDictionary *)parameters onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    
    //判断是否设置了请求域名
    if (!(IMSDKManager.apiHost.length > 0)) {
        NSLog(@"请设置SDK的请求域名信息!!!");
        return;
    }
    
    if (!parameters) {
        parameters = [NSDictionary dictionary];
    }
    
    //Url组装
    NSString *fullPath;
    if ([path containsString:@"http"]) {
        fullPath = path;
    } else {
        fullPath = [NSString stringWithFormat:@"%@%@",IMSDKManager.apiHost,path];
    }
    
    //请求方法类型
    NSString *medthStr = @"POST";
    
    //GET请求
    if (type == LingIMHttpRequestTypeGET) {
        //Param 重新组装请求参数，将参数缀到url后面
        if (parameters != nil && parameters.allKeys.count > 0) {
            NSString *paramStr = @"?";
            // 快速遍历参数数组
            for(id key in parameters) {
                NSString *resultValue;
                id value = [parameters objectForKey:key];
                if ([value isKindOfClass:[NSNumber class]]) {
                    resultValue = [value stringValue];
                } else {
                    resultValue = value;
                }
                paramStr = [paramStr stringByAppendingString:key];
                paramStr = [paramStr stringByAppendingString:@"="];
                paramStr = [paramStr stringByAppendingString:resultValue];
                paramStr = [paramStr stringByAppendingString:@"&"];
            }
            // 处理多余的&以及返回含参url
            if (paramStr.length > 1) {
                // 去掉末尾的&
                paramStr = [paramStr substringToIndex:paramStr.length - 1];
                fullPath = [fullPath stringByAppendingString:paramStr];
            }
        }
        fullPath = [fullPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        medthStr = @"GET";
        parameters = nil;
    } else {
        //POST请求
        medthStr = @"POST";
    }
    
    //token已过期，需要自动更新一次token
    if (self.refreshTokenOpeartion != nil && ![path isEqualToString:@"/auth/account/v2/autoToken"]) {
        //开始自动更新toke
        __weak typeof(self) weakSelf = self;
        NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
            [weakSelf netRequestWithType:type path:fullPath parameters:parameters onSuccess:onSuccess onFailure:onFailure];
        }];
        [networkOpeatrion addDependency:self.refreshTokenOpeartion];
        [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
        
        if (onFailure) {
            onFailure(0, nil, [self.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"]);
        }
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    NSDictionary *hearder = [self configHttpHeaderWithUrl:path];
    NSString *ztid = [hearder objectForKey:@"ZTID"];
    CFTimeInterval start = CACurrentMediaTime();
    [_interfaceTimeConsumingCatche setObject:[NSNumber numberWithDouble:start] forKey:ztid];
    
    __block NSURLSessionDataTask *task =  [self dataTaskWithHTTPMethod:medthStr URLString:fullPath parameters:parameters headers:hearder uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
        
    } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.updateBaseHostOpeartion = nil;
        NSString * ztid = [hearder objectForKey:@"ZTID"];
        CFTimeInterval start = [[strongSelf->_interfaceTimeConsumingCatche objectForKey:ztid] doubleValue];
        CFTimeInterval total = CACurrentMediaTime() - start;
        
        NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:responseObject];
        if (resp.isHttpSuccess) {
            if (resp.data == nil) {
                if (onSuccess) {
                    onSuccess(resp.data, ztid);
                }
            } else {
                id respData = [weakSelf responseDataDescryptWithDataString:resp.data url:path];
                if (respData != nil) {
                    if (onSuccess) {
                        onSuccess(respData, ztid);
                    }
                } else {
                    if([path containsString:@"/dns/report"]) {
                        if (onFailure) {
                            onFailure(0, @"", ztid);
                        }
                    } else {
                        if (onFailure) {
                            onFailure(0, @"网络异常~", ztid);
                        }
                    }
                }
            }
        } else {
            NSLog(@"接口：%@ 报错，code：%ld，des：%@，TOKEN：%@", fullPath, (long)resp.code, resp.message, [IMSDKManager myUserToken]);
            if (resp.code == LingIMHttpResponseCodeTokenOutTime ||
                resp.code == LingIMHttpResponseCodeTokenError ||
                resp.code == LingIMHttpResponseCodeOtherTokenError ||
                resp.code == LingIMHttpResponseCodeNotAuth ||
                resp.code == LingIMHttpResponseCodeTokenNull) {
                
                //token已过期，需要自动更新一次token
                if (weakSelf.refreshTokenOpeartion == nil) {
                    //开始自动更新toke
                    weakSelf.refreshTokenOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        [weakSelf authRefreshTokenOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                            dispatch_semaphore_signal(semaphore);
                        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                            dispatch_semaphore_signal(semaphore);
                        }];
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                        weakSelf.refreshTokenOpeartion = nil;
                    }];
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [weakSelf netRequestWithType:type path:fullPath parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                    [weakSelf.netWorkingQueue addOperation:weakSelf.refreshTokenOpeartion];
                    [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                } else {
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [weakSelf netRequestWithType:type path:fullPath parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                    [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                }
                
            } else if (resp.code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
                //执行用户 强制下线 代理回调
                if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                    [weakSelf.userDelegate noaSdkUserForceLogout:999 message:@""];
                }
            } else if (resp.code == LingIMHttpResponseCodeUsedIpDisabled) {
                //执行用户 强制下线 代理回调并给出提示语
                if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                    [weakSelf.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:resp.message];
                }
                if (onFailure) {
                    onFailure(resp.code, resp.message, resp.traceId);
                }
            } else {
                if (onFailure) {
                    onFailure(resp.code, resp.message, resp.traceId);
                }
                //日志处理
                NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                [weakSelf loganConfigWith:fullPath param:parameters failure:resp.message ztid:ztid];
            }
        }
        
        if (total > 2.0){ //接口响应时间大于2s
            [strongSelf loganConfigWith:fullPath ztid:ztid traceId:resp.traceId time:total];
            NSLog(@"CFTimeInterval total : %f  %@", total, fullPath);
        }
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
        
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSLog(@"接口：%@ 报错，code：%ld，des：%@", fullPath, (long)error.code, error.description);
        NSString * ztid = [hearder objectForKey:@"ZTID"];
        if([path containsString:@"/dns/report"] || [path containsString:@"/biz/translate/translate"]) {
            if (onFailure) {
                onFailure(error.code, @"", ztid);
            }
        } else {
            if (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost) {
                if (strongSelf.updateBaseHostOpeartion == nil) {
                    //开始自动更新toke
                    strongSelf.updateBaseHostOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                        NSString *key = [NSString stringWithFormat:@"nodePreferResult_%@", [IMSDKManager currentLiceseId]];
                        NSMutableArray *nodeResultList = [[[MMKV defaultMMKV] getObjectOfClass:[NSArray class] forKey:key] mutableCopy];
                        NSArray *tempNodeResultList = [NSArray arrayWithArray:nodeResultList];
                        for (int k = 0; k < tempNodeResultList.count; k++) {
                            NSMutableDictionary *tempNodeDict = [(NSDictionary *)[tempNodeResultList objectAtIndex:k] mutableCopy];
                            NSString *nodeStr = (NSString *)[tempNodeDict objectForKey:@"node"];
                            if ([[IMSDKManager apiHost] containsString:nodeStr]) {
                                [tempNodeDict setObject:@(NO) forKey:@"lastState"];
                                [nodeResultList replaceObjectAtIndex:k withObject:tempNodeDict];
                                break;
                            }
                        }
                        if (nodeResultList != nil && nodeResultList.count > 0) {
                            NSString *fastNodeHost = @"";
                            for (int i = 0; i < nodeResultList.count; i++) {
                                NSDictionary *tempfastNodeDict = (NSDictionary *)[nodeResultList objectAtIndex:i];
                                BOOL lastState = [[tempfastNodeDict objectForKey:@"lastState"] boolValue];
                                if (lastState) {
                                    fastNodeHost = (NSString *)[tempfastNodeDict objectForKey:@"node"];
                                }
                            }
                            if (fastNodeHost != nil && fastNodeHost.length > 0) {
                                NSString *requestHost;
                                if (![fastNodeHost containsString:@"http"]) {
                                    requestHost = [NSString stringWithFormat:@"https://%@", fastNodeHost];
                                } else {
                                    requestHost = [fastNodeHost stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
                                }
                                NoaIMSDKApiOptions *option = [NoaIMSDKApiOptions new];
                                option.imApi = requestHost;
                                option.imOrgName = [IMSDKManager orgName];
                                [IMSDKManager configSDKApiWith:option];
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUpdateHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUpdateHttpNodeWith:requestHost];
                                }
                            } else {
                                [strongSelf.netWorkingQueue cancelAllOperations];
                                if (onFailure) {
                                    onFailure(error.code, @"", ztid);
                                }
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                                }
                            }
                        } else {
                            [strongSelf.netWorkingQueue cancelAllOperations];
                            if (onFailure) {
                                onFailure(error.code, @"", ztid);
                            }
                            if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                            }
                        }
                        strongSelf.updateBaseHostOpeartion = nil;
                    }];
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [strongSelf netRequestWithType:type path:path parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:strongSelf.updateBaseHostOpeartion];
                    [strongSelf.netWorkingQueue addOperation:strongSelf.updateBaseHostOpeartion];
                    [strongSelf.netWorkingQueue addOperation:networkOpeatrion];
                }
            } else {
                if (onFailure) {
                    onFailure(error.code, @"网络异常~", ztid);
                }
            }
        }
        //日志处理
        [weakSelf loganConfigWith:fullPath param:parameters failure:[NSString stringWithFormat:@"%ld-%@", error.code, error.description] ztid:ztid];
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
    }];
    
    [task resume];
}

#pragma mark - ******2.消息转发接口******
- (void)netRequestForwardWithPath:(NSString *)path paramData:(NSData *)paramData onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    //判断是否设置了请求域名
    if (!(IMSDKManager.apiHost.length > 0)) {
        NSLog(@"请设置SDK的请求域名信息!!!");
        return;
    }
    
    //Url组装
    NSString *fullPath;
    if ([path containsString:@"http"]) {
        fullPath = path;
    } else {
        fullPath = [NSString stringWithFormat:@"%@%@",IMSDKManager.apiHost,path];
    }
    
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:fullPath parameters:nil error:nil];
    //设备类型 ANDROID，IOS，WEB，IOT，PC，WINDOWS，MAC
    [request addValue:@"IOS" forHTTPHeaderField:@"deviceType"];
    //deviceUuid多租户
    NSString *deviceID = [FCUUID uuidForDevice];
    [request addValue:deviceID forHTTPHeaderField:@"deviceUuid"];
    //日志跟踪
    NSString *ztid = [[NoaIMManagerTool sharedManager] getMessageID];
    [request addValue:ztid forHTTPHeaderField:@"ZTID"];
    //租户信息
    [request addValue:IMSDKManager.orgName forHTTPHeaderField:@"orgName"];
    //版本号
    [request addValue:[NoaIMDeviceTool appVersion] forHTTPHeaderField:@"version"];
    //loginuseruid
    [request addValue:[IMSDKManager myUserID] forHTTPHeaderField:@"loginuseruid"];
    //token
    if ([IMSDKManager myUserToken].length > 0) {
        //Header里加上token
        [request addValue:[IMSDKManager myUserToken] forHTTPHeaderField:@"token"];
    }
    //liceseId
    if ([IMSDKManager currentLiceseId].length > 0) {
        [request setValue:[IMSDKManager currentLiceseId] forHTTPHeaderField:@"conid"];
    }
    
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:paramData];
    
    /** 接口验签 */
    long long timeStamp = [NSDate getCurrentTimeIntervalWithSecond];
    //timestamp
    [request setValue:[NSString stringWithFormat:@"%lld", timeStamp] forHTTPHeaderField:@"timestamp"];
    //signature
    NSString *signature = [self getUrlSignature:timeStamp url:path];
    [request setValue:signature forHTTPHeaderField:@"signature"];
    
    __weak typeof(self) weakSelf = self;
    CFTimeInterval start = CACurrentMediaTime();
    [_interfaceTimeConsumingCatche setObject:[NSNumber numberWithDouble:start] forKey:ztid];
    
    __block NSURLSessionDataTask *task =  [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CFTimeInterval start = [[strongSelf->_interfaceTimeConsumingCatche objectForKey:ztid] doubleValue];
        CFTimeInterval total = CACurrentMediaTime() - start;
        
        //响应
        if (error) {
            if (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost) {
                if (strongSelf.updateBaseHostOpeartion == nil) {
                    //开始自动更新toke
                    strongSelf.updateBaseHostOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                        NSString *key = [NSString stringWithFormat:@"nodePreferResult_%@", [IMSDKManager currentLiceseId]];
                        NSMutableArray *nodeResultList = [[[MMKV defaultMMKV] getObjectOfClass:[NSArray class] forKey:key] mutableCopy];
                        NSArray *tempNodeResultList = [NSArray arrayWithArray:nodeResultList];
                        for (int k = 0; k < tempNodeResultList.count; k++) {
                            NSMutableDictionary *tempNodeDict = [(NSDictionary *)[tempNodeResultList objectAtIndex:k] mutableCopy];
                            NSString *nodeStr = (NSString *)[tempNodeDict objectForKey:@"node"];
                            if ([[IMSDKManager apiHost] containsString:nodeStr]) {
                                [tempNodeDict setObject:@(NO) forKey:@"lastState"];
                                [nodeResultList replaceObjectAtIndex:k withObject:tempNodeDict];
                                break;
                            }
                        }
                        if (nodeResultList != nil && nodeResultList.count > 0) {
                            NSString *fastNodeHost = @"";
                            for (int i = 0; i < nodeResultList.count; i++) {
                                NSDictionary *tempfastNodeDict = (NSDictionary *)[nodeResultList objectAtIndex:i];
                                BOOL lastState = [[tempfastNodeDict objectForKey:@"lastState"] boolValue];
                                if (lastState) {
                                    fastNodeHost = (NSString *)[tempfastNodeDict objectForKey:@"node"];
                                }
                            }
                            if (fastNodeHost != nil && fastNodeHost.length > 0) {
                                NSString *requestHost;
                                if (![fastNodeHost containsString:@"http"]) {
                                    requestHost = [NSString stringWithFormat:@"https://%@", fastNodeHost];
                                } else {
                                    requestHost = [fastNodeHost stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
                                }
                                NoaIMSDKApiOptions *option = [NoaIMSDKApiOptions new];
                                option.imApi = requestHost;
                                option.imOrgName = [IMSDKManager orgName];
                                [IMSDKManager configSDKApiWith:option];
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUpdateHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUpdateHttpNodeWith:requestHost];
                                }
                            } else {
                                [strongSelf.netWorkingQueue cancelAllOperations];
                                if (onFailure) {
                                    onFailure(error.code, @"", ztid);
                                }
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                                }
                            }
                        } else {
                            [strongSelf.netWorkingQueue cancelAllOperations];
                            if (onFailure) {
                                onFailure(error.code, @"", ztid);
                            }
                            if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                            }
                        }
                        strongSelf.updateBaseHostOpeartion = nil;
                    }];
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [strongSelf netRequestForwardWithPath:path paramData:paramData onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:strongSelf.updateBaseHostOpeartion];
                    [strongSelf.netWorkingQueue addOperation:strongSelf.updateBaseHostOpeartion];
                    [strongSelf.netWorkingQueue addOperation:networkOpeatrion];
                }
            } else {
                if (onFailure) {
                    onFailure(error.code, @"网络异常~", ztid);
                }
            }
            //日志处理
            [weakSelf loganConfigWith:fullPath param:nil failure:[NSString stringWithFormat:@"%ld-%@", error.code, error.description] ztid:ztid];
        } else {
            strongSelf.updateBaseHostOpeartion = nil;
            if (responseObject) {
                NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:responseObject];
                if (resp.isHttpSuccess) {
                    if (resp.data == nil) {
                        if (onSuccess) {
                            onSuccess(resp.data, ztid);
                        }
                    } else {
                        id respData = [weakSelf responseDataDescryptWithDataString:resp.data url:path];
                        if (respData != nil) {
                            if (onSuccess) {
                                onSuccess(respData, ztid);
                            }
                        } else {
                            if (onFailure) {
                                onFailure(0, @"网络异常~", ztid);
                            }
                        }
                    }
                }else {
                    
                    if (resp.code == LingIMHttpResponseCodeTokenOutTime ||
                        resp.code == LingIMHttpResponseCodeTokenError ||
                        resp.code == LingIMHttpResponseCodeOtherTokenError ||
                        resp.code == LingIMHttpResponseCodeNotAuth ||
                        resp.code == LingIMHttpResponseCodeTokenNull) {
                        //token已过期，需要自动更新一次token
                        if (weakSelf.refreshTokenOpeartion == nil) {
                            //开始自动更新toke
                            weakSelf.refreshTokenOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                                [weakSelf authRefreshTokenOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                                    dispatch_semaphore_signal(semaphore);
                                } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                                    dispatch_semaphore_signal(semaphore);
                                }];
                                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                                weakSelf.refreshTokenOpeartion = nil;
                            }];
                            NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                                [weakSelf netRequestForwardWithPath:fullPath paramData:paramData onSuccess:onSuccess onFailure:onFailure];
                            }];
                            [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                            [weakSelf.netWorkingQueue addOperation:weakSelf.refreshTokenOpeartion];
                            [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                        } else {
                            NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                                [weakSelf netRequestForwardWithPath:fullPath paramData:paramData onSuccess:onSuccess onFailure:onFailure];
                            }];
                            [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                            [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                        }
                    } else if (resp.code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
                        //执行用户 强制下线 代理回调
                        if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                            [weakSelf.userDelegate noaSdkUserForceLogout:999 message:@""];
                        }
                    } else if (resp.code == LingIMHttpResponseCodeUsedIpDisabled) {
                        //执行用户 强制下线 代理回调并给出提示语
                        if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                            [weakSelf.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:resp.message];
                        }
                    } else {
                        NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                        if (onFailure) {
                            onFailure(resp.code, resp.message, ztid);
                        }
                        //日志处理
                        [weakSelf loganConfigWith:fullPath param:nil failure:resp.message ztid:ztid];
                    }
                }
            }
        }
        
        if (total > 2.0){ //接口响应时间大于2s
            [strongSelf loganConfigWith:fullPath ztid:ztid traceId:ztid time:total];
            NSLog(@"CFTimeInterval total : %f  %@", total, fullPath);
        }
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
    }];
    
    [task resume];
}

#pragma mark - ******3.通用带有服务器时间返回的数据请求接口******
- (void)netRequestWithServiceTimeWithType:(LingIMHttpRequestType)type path:(NSString *)path parameters:(NSDictionary * _Nullable)parameters onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    //判断是否设置了请求域名
    if (!(IMSDKManager.apiHost.length > 0)) {
        NSLog(@"请设置SDK的请求域名信息!!!");
        return;
    }
    
    if (!parameters) {
        parameters = [NSDictionary dictionary];
    }
    
    //Url组装
    NSString *fullPath;
    if ([path containsString:@"http"]) {
        fullPath = path;
    } else {
        fullPath = [NSString stringWithFormat:@"%@%@",IMSDKManager.apiHost,path];
    }
    
    //请求方法类型
    NSString *medthStr = @"POST";
    
    //GET请求
    if (type == LingIMHttpRequestTypeGET) {
        //Param 重新组装请求参数，将参数缀到url后面
        if (parameters != nil && parameters.allKeys.count > 0) {
            NSString *paramStr = @"?";
            // 快速遍历参数数组
            for(id key in parameters) {
                NSString *resultValue;
                id value = [parameters objectForKey:key];
                if ([value isKindOfClass:[NSNumber class]]) {
                    resultValue = [value stringValue];
                } else {
                    resultValue = value;
                }
                paramStr = [paramStr stringByAppendingString:key];
                paramStr = [paramStr stringByAppendingString:@"="];
                paramStr = [paramStr stringByAppendingString:resultValue];
                paramStr = [paramStr stringByAppendingString:@"&"];
            }
            // 处理多余的&以及返回含参url
            if (paramStr.length > 1) {
                // 去掉末尾的&
                paramStr = [paramStr substringToIndex:paramStr.length - 1];
                fullPath = [fullPath stringByAppendingString:paramStr];
            }
        }
        fullPath = [fullPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        medthStr = @"GET";
        parameters = nil;
    } else {
        //POST请求
        medthStr = @"POST";
    }
    
    __weak typeof(self) weakSelf = self;
    NSDictionary *hearder = [self configHttpHeaderWithUrl:path];
    NSString *ztid = [hearder objectForKey:@"ZTID"];
    CFTimeInterval start = CACurrentMediaTime();
    [_interfaceTimeConsumingCatche setObject:[NSNumber numberWithDouble:start] forKey:ztid];
    
    __block NSURLSessionDataTask *task =  [self dataTaskWithHTTPMethod:medthStr URLString:fullPath parameters:parameters headers:hearder uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
        
    } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.updateBaseHostOpeartion = nil;
        NSString * ztid = [hearder objectForKey:@"ZTID"];
        CFTimeInterval start = [[strongSelf->_interfaceTimeConsumingCatche objectForKey:ztid] doubleValue];
        CFTimeInterval total = CACurrentMediaTime() - start;
        
        NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:responseObject];
        
        if (resp.isHttpSuccess) {
            NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
            //接口请求返回成功code
            //服务端响应时间
            NSHTTPURLResponse *serviceResponse = (NSHTTPURLResponse *)task.response;
            //时间格式:Mon, 17 Apr 2023 10:05:42 GMT  (EEE, d MMM yyyy HH:mm:ss zzz)
            NSString *serviceTimeStr = [serviceResponse valueForHTTPHeaderField:@"Date"];
            NSDate *serviceDate = [NSDate dateFromRFC822String:serviceTimeStr];
            long long serviceDateValue = [serviceDate timeIntervalSince1970] * 1000;
            NSLog(@"开始加密: ztid：%@  data:%@ url:%@",ztid,responseObject,path);
            if (resp.data == nil) {
                if (onSuccess) {
                    onSuccess(resp.data, serviceDateValue);
                }
            } else {
                id respData = [weakSelf responseDataDescryptWithDataString:resp.data url:path];
                if (respData != nil) {
                    if (onSuccess) {
                        onSuccess(respData, serviceDateValue);
                    }
                } else {
                    if (onFailure) {
                        onFailure(0, @"网络异常~", ztid);
                    }
                }
            }
        } else {
            if (resp.code == LingIMHttpResponseCodeTokenOutTime ||
                resp.code == LingIMHttpResponseCodeTokenError ||
                resp.code == LingIMHttpResponseCodeOtherTokenError ||
                resp.code == LingIMHttpResponseCodeNotAuth ||
                resp.code == LingIMHttpResponseCodeTokenNull) {
                
                //token已过期，需要自动更新一次token
                if (weakSelf.refreshTokenOpeartion == nil) {
                    //开始自动更新toke
                    weakSelf.refreshTokenOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        [weakSelf authRefreshTokenOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                            dispatch_semaphore_signal(semaphore);
                        } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                            dispatch_semaphore_signal(semaphore);
                        }];
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                        weakSelf.refreshTokenOpeartion = nil;
                    }];
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [weakSelf netRequestWithServiceTimeWithType:type path:fullPath parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                    [weakSelf.netWorkingQueue addOperation:weakSelf.refreshTokenOpeartion];
                    [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                } else if (resp.code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
                    //执行用户 强制下线 代理回调
                    if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                        [weakSelf.userDelegate noaSdkUserForceLogout:999 message:@""];
                    }
                } else if (resp.code == LingIMHttpResponseCodeUsedIpDisabled) {
                    //执行用户 强制下线 代理回调并给出提示语
                    if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                        [weakSelf.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:resp.message];
                    }
                } else if (resp.code == LingIMHttpResponseCodeUsedIpDisabled) {
                    //执行用户 强制下线 代理回调并给出提示语
                    if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                        [weakSelf.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:resp.message];
                    }
                } else {
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [weakSelf netRequestWithServiceTimeWithType:type path:fullPath parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                    [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                }
                
            } else {
                //接口请求返回错误code
                NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                if (onFailure) {
                    onFailure(resp.code, resp.message, ztid);
                }
                //日志处理
                [weakSelf loganConfigWith:fullPath param:parameters failure:resp.message ztid:ztid];
            }
        }
        
        if (total > 2.0){ //接口响应时间大于2s
            [strongSelf loganConfigWith:fullPath ztid:ztid traceId:resp.traceId time:total];
            NSLog(@"CFTimeInterval total : %f  %@", total, fullPath);
        }
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString * ztid = [hearder objectForKey:@"ZTID"];
        if (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost) {
            if (strongSelf.updateBaseHostOpeartion == nil) {
                //开始自动更新toke
                strongSelf.updateBaseHostOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                    NSString *key = [NSString stringWithFormat:@"nodePreferResult_%@", [IMSDKManager currentLiceseId]];
                    NSMutableArray *nodeResultList = [[[MMKV defaultMMKV] getObjectOfClass:[NSArray class] forKey:key] mutableCopy];
                    NSArray *tempNodeResultList = [NSArray arrayWithArray:nodeResultList];
                    for (int k = 0; k < tempNodeResultList.count; k++) {
                        NSMutableDictionary *tempNodeDict = [(NSDictionary *)[tempNodeResultList objectAtIndex:k] mutableCopy];
                        NSString *nodeStr = (NSString *)[tempNodeDict objectForKey:@"node"];
                        if ([[IMSDKManager apiHost] containsString:nodeStr]) {
                            [tempNodeDict setObject:@(NO) forKey:@"lastState"];
                            [nodeResultList replaceObjectAtIndex:k withObject:tempNodeDict];
                            break;
                        }
                    }
                    if (nodeResultList != nil && nodeResultList.count > 0) {
                        NSString *fastNodeHost = @"";
                        for (int i = 0; i < nodeResultList.count; i++) {
                            NSDictionary *tempfastNodeDict = (NSDictionary *)[nodeResultList objectAtIndex:i];
                            BOOL lastState = [[tempfastNodeDict objectForKey:@"lastState"] boolValue];
                            if (lastState) {
                                fastNodeHost = (NSString *)[tempfastNodeDict objectForKey:@"node"];
                            }
                        }
                        if (fastNodeHost != nil && fastNodeHost.length > 0) {
                            NSString *requestHost;
                            if (![fastNodeHost containsString:@"http"]) {
                                requestHost = [NSString stringWithFormat:@"https://%@", fastNodeHost];
                            } else {
                                requestHost = [fastNodeHost stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
                            }
                            NoaIMSDKApiOptions *option = [NoaIMSDKApiOptions new];
                            option.imApi = requestHost;
                            option.imOrgName = [IMSDKManager orgName];
                            [IMSDKManager configSDKApiWith:option];
                            if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUpdateHttpNodeWith:)]) {
                                [strongSelf.userDelegate noaSdkUpdateHttpNodeWith:requestHost];
                            }
                        } else {
                            [strongSelf.netWorkingQueue cancelAllOperations];
                            if (onFailure) {
                                onFailure(error.code, @"", ztid);
                            }
                            if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                            }
                        }
                    } else {
                        [strongSelf.netWorkingQueue cancelAllOperations];
                        if (onFailure) {
                            onFailure(error.code, @"", ztid);
                        }
                        if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                            [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                        }
                    }
                    strongSelf.updateBaseHostOpeartion = nil;
                }];
                NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                    [strongSelf netRequestWithServiceTimeWithType:type path:path parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                }];
                [networkOpeatrion addDependency:strongSelf.updateBaseHostOpeartion];
                [strongSelf.netWorkingQueue addOperation:strongSelf.updateBaseHostOpeartion];
                [strongSelf.netWorkingQueue addOperation:networkOpeatrion];
            }
        } else {
            if (onFailure) {
                onFailure(error.code, @"网络异常~", ztid);
            }
        }
        
        //日志处理
        [weakSelf loganConfigWith:fullPath param:parameters failure:[NSString stringWithFormat:@"%ld-%@", error.code, error.description] ztid:ztid];
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
    }];
    
    [task resume];
}

#pragma mark - ******4.通用的 请求地址是否为完整地址的请求******
- (void)netRequestWorkCommonBaseUrl:(NSString *)baseUrl Path:(NSString *)path medth:(LingIMHttpRequestType)medth parameters:(NSDictionary *)parameters onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    if (!parameters) {
        parameters = [NSDictionary dictionary];
    }
    
    //Url组装
    NSString *fullPath;
    if ([path hasPrefix:@"http"]) {
        fullPath = path;
    }else {
        fullPath = [NSString stringWithFormat:@"%@%@", baseUrl, path];
    }
    
    //请求方法类型
    NSString *medthStr = @"POST";
    if (medth == LingIMHttpRequestTypeGET) {  //GET请求
        //Param 重新组装请求参数，将参数缀到url后面
        if (parameters != nil && parameters.allKeys.count > 0) {
            NSString *paramStr = @"?";
            // 快速遍历参数数组
            for(id key in parameters) {
                NSString *resultValue;
                id value = [parameters objectForKey:key];
                if ([value isKindOfClass:[NSNumber class]]) {
                    resultValue = [value stringValue];
                } else {
                    resultValue = value;
                }
                paramStr = [paramStr stringByAppendingString:key];
                paramStr = [paramStr stringByAppendingString:@"="];
                paramStr = [paramStr stringByAppendingString:resultValue];
                paramStr = [paramStr stringByAppendingString:@"&"];
            }
            // 处理多余的&以及返回含参url
            if (paramStr.length > 1) {
                // 去掉末尾的&
                paramStr = [paramStr substringToIndex:paramStr.length - 1];
                fullPath = [fullPath stringByAppendingString:paramStr];
            }
        }
        fullPath = [fullPath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        medthStr = @"GET";
        parameters = nil;
    } else {
        //POST请求
        medthStr = @"POST";
    }
    
    __weak typeof(self) weakSelf = self;
    NSDictionary *hearder = [self configHttpHeaderWithUrl:path];
    NSString *ztid = [hearder objectForKey:@"ZTID"];
    CFTimeInterval start = CACurrentMediaTime();
    [_interfaceTimeConsumingCatche setObject:[NSNumber numberWithDouble:start] forKey:ztid];
    
    __block NSURLSessionDataTask *task =  [self dataTaskWithHTTPMethod:medthStr URLString:fullPath parameters:parameters headers:hearder uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
        
    } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.updateBaseHostOpeartion = nil;
        NSString * ztid = [hearder objectForKey:@"ZTID"];
        CFTimeInterval start = [[strongSelf->_interfaceTimeConsumingCatche objectForKey:ztid] doubleValue];
        CFTimeInterval total = CACurrentMediaTime() - start;
        
        NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:responseObject];
        if ([fullPath containsString:@"adm-license/feedback/addFeedBack"]) {
            if (resp.code == 200) {
                //邀请码/域名 投诉与支持 提交数据到另一个项目，该项目里接口成功的code为200，不是10000
                if (onSuccess) {
                    onSuccess(resp.data, ztid);
                }
            } else {
                if (onFailure) {
                    onFailure(resp.code, resp.message, resp.traceId);
                }
            }
        } else {
            if (resp.isHttpSuccess) {
                if (resp.data == nil) {
                    if (onSuccess) {
                        onSuccess(resp.data, ztid);
                    }
                } else {
                    id respData = [weakSelf responseDataDescryptWithDataString:resp.data url:fullPath];
                    if (respData != nil) {
                        if (onSuccess) {
                            onSuccess(respData, ztid);
                        }
                    } else {
                        if (onFailure) {
                            onFailure(0, @"网络异常~", ztid);
                        }
                    }
                }
            } else {
                NSLog(@"接口：%@ 报错，code：%ld，des：%@", fullPath, (long)resp.code, resp.message);
                NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                if (resp.code == LingIMHttpResponseCodeTokenOutTime ||
                    resp.code == LingIMHttpResponseCodeTokenError ||
                    resp.code == LingIMHttpResponseCodeOtherTokenError ||
                    resp.code == LingIMHttpResponseCodeNotAuth ||
                    resp.code == LingIMHttpResponseCodeTokenNull) {
                    //token已过期，需要自动更新一次token
                    if (weakSelf.refreshTokenOpeartion == nil) {
                        //开始自动更新toke
                        weakSelf.refreshTokenOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                            [weakSelf authRefreshTokenOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                                dispatch_semaphore_signal(semaphore);
                            } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                                dispatch_semaphore_signal(semaphore);
                            }];
                            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                            weakSelf.refreshTokenOpeartion = nil;
                        }];
                        NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                            [weakSelf netRequestWorkCommonBaseUrl:baseUrl Path:path medth:medth parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                        }];
                        [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                        [weakSelf.netWorkingQueue addOperation:weakSelf.refreshTokenOpeartion];
                        [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                    } else {
                        NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                            [weakSelf netRequestWorkCommonBaseUrl:baseUrl Path:path medth:medth parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                        }];
                        [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                        [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                    }
                    if([path containsString:@"/biz/system/v2/getSystemConfig"]){
                        if (onFailure) {
                            onFailure(resp.code, resp.message, ztid);
                        }
                    }
                } else if (resp.code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
                    //执行用户 强制下线 代理回调
                    if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                        [weakSelf.userDelegate noaSdkUserForceLogout:999 message:@""];
                    }
                } else if (resp.code == LingIMHttpResponseCodeUsedIpDisabled) {
                    //执行用户 强制下线 代理回调并给出提示语
                    if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                        [weakSelf.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:resp.message];
                    }
                } else {
                    if (onFailure) {
                        onFailure(resp.code, resp.message, ztid);
                    }
                    //日志处理
                    [weakSelf loganConfigWith:fullPath param:parameters failure:resp.message ztid:ztid];
                    
                }
            }
        }
        if (total > 2.0){ //接口响应时间大于2s
            [strongSelf loganConfigWith:fullPath ztid:ztid traceId:resp.traceId time:total];
            NSLog(@"CFTimeInterval total : %f  %@", total, fullPath);
        }
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSString * ztid = [hearder objectForKey:@"ZTID"];
        NSLog(@"接口：%@ 报错，code：%ld，des：%@", fullPath, (long)error.code, error.description);
        if (onFailure) {
            if ([path containsString:@"/biz/system/v2/getSystemConfig"] || [path containsString:@"/biz/sso/connect"] || [path containsString:@"/health"]) {
                onFailure(error.code, error.description, ztid);
            } else {
                if (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost) {
                    if (strongSelf.updateBaseHostOpeartion == nil) {
                        //开始自动更新toke
                        strongSelf.updateBaseHostOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                            NSString *key = [NSString stringWithFormat:@"nodePreferResult_%@", [IMSDKManager currentLiceseId]];
                            NSMutableArray *nodeResultList = [[[MMKV defaultMMKV] getObjectOfClass:[NSArray class] forKey:key] mutableCopy];
                            NSArray *tempNodeResultList = [NSArray arrayWithArray:nodeResultList];
                            for (int k = 0; k < tempNodeResultList.count; k++) {
                                NSMutableDictionary *tempNodeDict = [(NSDictionary *)[tempNodeResultList objectAtIndex:k] mutableCopy];
                                NSString *nodeStr = (NSString *)[tempNodeDict objectForKey:@"node"];
                                if ([[IMSDKManager apiHost] containsString:nodeStr]) {
                                    [tempNodeDict setObject:@(NO) forKey:@"lastState"];
                                    [nodeResultList replaceObjectAtIndex:k withObject:tempNodeDict];
                                    break;
                                }
                            }
                            if (nodeResultList != nil && nodeResultList.count > 0) {
                                NSString *fastNodeHost = @"";
                                for (int i = 0; i < nodeResultList.count; i++) {
                                    NSDictionary *tempfastNodeDict = (NSDictionary *)[nodeResultList objectAtIndex:i];
                                    BOOL lastState = [[tempfastNodeDict objectForKey:@"lastState"] boolValue];
                                    if (lastState) {
                                        fastNodeHost = (NSString *)[tempfastNodeDict objectForKey:@"node"];
                                    }
                                }
                                if (fastNodeHost != nil && fastNodeHost.length > 0) {
                                    NSString *requestHost;
                                    if (![fastNodeHost containsString:@"http"]) {
                                        requestHost = [NSString stringWithFormat:@"https://%@", fastNodeHost];
                                    } else {
                                        requestHost = [fastNodeHost stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
                                    }
                                    NoaIMSDKApiOptions *option = [NoaIMSDKApiOptions new];
                                    option.imApi = requestHost;
                                    option.imOrgName = [IMSDKManager orgName];
                                    [IMSDKManager configSDKApiWith:option];
                                    if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUpdateHttpNodeWith:)]) {
                                        [strongSelf.userDelegate noaSdkUpdateHttpNodeWith:requestHost];
                                    }
                                } else {
                                    [strongSelf.netWorkingQueue cancelAllOperations];
                                    if (onFailure) {
                                        onFailure(error.code, @"", ztid);
                                    }
                                    if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                        [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                                    }
                                }
                            } else {
                                [strongSelf.netWorkingQueue cancelAllOperations];
                                if (onFailure) {
                                    onFailure(error.code, @"", ztid);
                                }
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                                }
                            }
                            strongSelf.updateBaseHostOpeartion = nil;
                        }];
                        NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                            if ([IMSDKManager apiHost].length > 0) {
                                [strongSelf netRequestWorkCommonBaseUrl:[IMSDKManager apiHost] Path:path medth:medth parameters:parameters onSuccess:onSuccess onFailure:onFailure];
                            }
                        }];
                        [networkOpeatrion addDependency:strongSelf.updateBaseHostOpeartion];
                        [strongSelf.netWorkingQueue addOperation:strongSelf.updateBaseHostOpeartion];
                        [strongSelf.netWorkingQueue addOperation:networkOpeatrion];
                    }
                } else {
                    onFailure(error.code, @"网络异常~", ztid);
                }
            }
        }
        
        //日志处理
        [weakSelf loganConfigWith:fullPath param:parameters failure:[NSString stringWithFormat:@"%ld-%@", error.code, error.description] ztid:ztid];
        
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
        
    }];
    
    [task resume];
}

#pragma mark - ******** 5 长链接失败后, 发送消息接口 ******
- (void)netRequestMessagePushWithPath:(NSString *)path paramData:(NSData *)paramData onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    //判断是否设置了请求域名
    if (!(IMSDKManager.apiHost.length > 0)) {
        NSLog(@"请设置SDK的请求域名信息!!!");
        return;
    }
    
    //Url组装
    NSString *fullPath;
    if ([path containsString:@"http"]) {
        fullPath = path;
    } else {
        fullPath = [NSString stringWithFormat:@"%@%@",IMSDKManager.apiHost,path];
    }
    
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST" URLString:fullPath parameters:nil error:nil];
    //设备类型 ANDROID，IOS，WEB，IOT，PC，WINDOWS，MAC
    [request addValue:@"IOS" forHTTPHeaderField:@"deviceType"];
    //deviceUuid多租户
    NSString *deviceID = [FCUUID uuidForDevice];
    [request addValue:deviceID forHTTPHeaderField:@"deviceUuid"];
    //日志跟踪
    NSString *ztid = [[NoaIMManagerTool sharedManager] getMessageID];
    [request addValue:ztid forHTTPHeaderField:@"ZTID"];
    //租户信息
    [request addValue:IMSDKManager.orgName forHTTPHeaderField:@"orgName"];
    //版本号
    [request addValue:[NoaIMDeviceTool appVersion] forHTTPHeaderField:@"version"];
    //loginuseruid
    [request addValue:[IMSDKManager myUserID] forHTTPHeaderField:@"loginuseruid"];
    //token
    if ([IMSDKManager myUserToken].length > 0) {
        //Header里加上token
        [request addValue:[IMSDKManager myUserToken] forHTTPHeaderField:@"token"];
    }
    //liceseId
    if ([IMSDKManager currentLiceseId].length > 0) {
        [request setValue:[IMSDKManager currentLiceseId] forHTTPHeaderField:@"conid"];
    }
    
    [request setValue:@"application/x-protobuf" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:paramData];
    
    /** 接口验签 */
    long long timeStamp = [NSDate getCurrentTimeIntervalWithSecond];
    //timestamp
    [request setValue:[NSString stringWithFormat:@"%lld", timeStamp] forHTTPHeaderField:@"timestamp"];
    //signature
    NSString *signature = [self getUrlSignature:timeStamp url:path];
    [request setValue:signature forHTTPHeaderField:@"signature"];
    
    __weak typeof(self) weakSelf = self;
    CFTimeInterval start = CACurrentMediaTime();
    [_interfaceTimeConsumingCatche setObject:[NSNumber numberWithDouble:start] forKey:ztid];
    
    __block NSURLSessionDataTask *task =  [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CFTimeInterval start = [[strongSelf->_interfaceTimeConsumingCatche objectForKey:ztid] doubleValue];
        CFTimeInterval total = CACurrentMediaTime() - start;
        
        //响应
        if (error) {
            NSInteger httpStatus = [response isKindOfClass:NSHTTPURLResponse.class] ? [(NSHTTPURLResponse *)response statusCode] : 0;
            if (httpStatus >= 400 && httpStatus < 600) {
                if (onFailure) onFailure(httpStatus, @"", ztid);
                return;
            }
            if (error.code == NSURLErrorTimedOut || error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorNetworkConnectionLost) {
                if (strongSelf.updateBaseHostOpeartion == nil) {
                    //开始自动更新toke
                    strongSelf.updateBaseHostOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                        NSString *key = [NSString stringWithFormat:@"nodePreferResult_%@", [IMSDKManager currentLiceseId]];
                        NSMutableArray *nodeResultList = [[[MMKV defaultMMKV] getObjectOfClass:[NSArray class] forKey:key] mutableCopy];
                        NSArray *tempNodeResultList = [NSArray arrayWithArray:nodeResultList];
                        for (int k = 0; k < tempNodeResultList.count; k++) {
                            NSMutableDictionary *tempNodeDict = [(NSDictionary *)[tempNodeResultList objectAtIndex:k] mutableCopy];
                            NSString *nodeStr = (NSString *)[tempNodeDict objectForKey:@"node"];
                            if ([[IMSDKManager apiHost] containsString:nodeStr]) {
                                [tempNodeDict setObject:@(NO) forKey:@"lastState"];
                                [nodeResultList replaceObjectAtIndex:k withObject:tempNodeDict];
                                break;
                            }
                        }
                        if (nodeResultList != nil && nodeResultList.count > 0) {
                            NSString *fastNodeHost = @"";
                            for (int i = 0; i < nodeResultList.count; i++) {
                                NSDictionary *tempfastNodeDict = (NSDictionary *)[nodeResultList objectAtIndex:i];
                                BOOL lastState = [[tempfastNodeDict objectForKey:@"lastState"] boolValue];
                                if (lastState) {
                                    fastNodeHost = (NSString *)[tempfastNodeDict objectForKey:@"node"];
                                }
                            }
                            if (fastNodeHost != nil && fastNodeHost.length > 0) {
                                NSString *requestHost;
                                if (![fastNodeHost containsString:@"http"]) {
                                    requestHost = [NSString stringWithFormat:@"https://%@", fastNodeHost];
                                } else {
                                    requestHost = [fastNodeHost stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
                                }
                                NoaIMSDKApiOptions *option = [NoaIMSDKApiOptions new];
                                option.imApi = requestHost;
                                option.imOrgName = [IMSDKManager orgName];
                                [IMSDKManager configSDKApiWith:option];
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUpdateHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUpdateHttpNodeWith:requestHost];
                                }
                            } else {
                                [strongSelf.netWorkingQueue cancelAllOperations];
                                if (onFailure) {
                                    onFailure(error.code, @"", ztid);
                                }
                                if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                    [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                                }
                            }
                        } else {
                            [strongSelf.netWorkingQueue cancelAllOperations];
                            if (onFailure) {
                                onFailure(error.code, @"", ztid);
                            }
                            if ([strongSelf.userDelegate respondsToSelector:@selector(noaSdkUnableHttpNodeWith:)]) {
                                [strongSelf.userDelegate noaSdkUnableHttpNodeWith:@"网络连接异常,请联系管理员"];
                            }
                        }
                        strongSelf.updateBaseHostOpeartion = nil;
                    }];
                    NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                        [strongSelf netRequestMessagePushWithPath:path paramData:paramData onSuccess:onSuccess onFailure:onFailure];
                    }];
                    [networkOpeatrion addDependency:strongSelf.updateBaseHostOpeartion];
                    [strongSelf.netWorkingQueue addOperation:strongSelf.updateBaseHostOpeartion];
                    [strongSelf.netWorkingQueue addOperation:networkOpeatrion];
                }
            } else {
                if (onFailure) {
                    onFailure(error.code, error.description, ztid);
                }
            }
            //日志处理
            
            [weakSelf loganConfigWith:fullPath param:nil failure:[NSString stringWithFormat:@"%ld-%@", error.code, error.description] ztid:ztid];
            
        } else {
            strongSelf.updateBaseHostOpeartion = nil;
            if (responseObject) {
                NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:responseObject];
                if (resp.isHttpSuccess) {
                    if (resp.data == nil) {
                        if (onSuccess) {
                            onSuccess(resp.data, ztid);
                        }
                    } else {
                        id respData = [weakSelf responseDataDescryptWithDataString:resp.data url:path];
                        if (respData != nil) {
                            if (onSuccess) {
                                onSuccess(respData, ztid);
                            }
                        } else {
                            if (onFailure) {
                                onFailure(0, @"网络异常~", ztid);
                            }
                        }
                    }
                }else {
                    
                    if (resp.code == LingIMHttpResponseCodeTokenOutTime ||
                        resp.code == LingIMHttpResponseCodeTokenError ||
                        resp.code == LingIMHttpResponseCodeOtherTokenError ||
                        resp.code == LingIMHttpResponseCodeNotAuth ||
                        resp.code == LingIMHttpResponseCodeTokenNull) {
                        //token已过期，需要自动更新一次token
                        if (weakSelf.refreshTokenOpeartion == nil) {
                            //开始自动更新toke
                            weakSelf.refreshTokenOpeartion = [NSBlockOperation blockOperationWithBlock:^{
                                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                                [weakSelf authRefreshTokenOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                                    dispatch_semaphore_signal(semaphore);
                                } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                                    dispatch_semaphore_signal(semaphore);
                                }];
                                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                                weakSelf.refreshTokenOpeartion = nil;
                            }];
                            NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                                [weakSelf netRequestMessagePushWithPath:fullPath paramData:paramData onSuccess:onSuccess onFailure:onFailure];
                            }];
                            [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                            [weakSelf.netWorkingQueue addOperation:weakSelf.refreshTokenOpeartion];
                            [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                        } else {
                            NSBlockOperation * networkOpeatrion = [NSBlockOperation blockOperationWithBlock:^{
                                [weakSelf netRequestMessagePushWithPath:fullPath paramData:paramData onSuccess:onSuccess onFailure:onFailure];
                            }];
                            [networkOpeatrion addDependency:weakSelf.refreshTokenOpeartion];
                            [weakSelf.netWorkingQueue addOperation:networkOpeatrion];
                        }
                    } else if (resp.code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
                        //执行用户 强制下线 代理回调
                        if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                            [weakSelf.userDelegate noaSdkUserForceLogout:999 message:@""];
                        }
                    } else if (resp.code == LingIMHttpResponseCodeUsedIpDisabled) {
                        //执行用户 强制下线 代理回调并给出提示语
                        if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
                            [weakSelf.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:resp.message];
                        }
                    } else {
                        NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
                        if (onFailure) {
                            onFailure(resp.code, resp.message, ztid);
                        }
                        //日志处理
                        [weakSelf loganConfigWith:fullPath param:nil failure:resp.message ztid:ztid];
                    }
                }
            }
        }
        
        if (total > 2.0){ //接口响应时间大于2s
            [strongSelf loganConfigWith:fullPath ztid:ztid traceId:ztid time:total];
            NSLog(@"CFTimeInterval total : %f  %@", total, fullPath);
        }
        // 移除记录
        [strongSelf->_interfaceTimeConsumingCatche removeObjectForKey:ztid];
    }];
    
    [task resume];
    
}

#pragma mark - ****** 刷新token ******
- (void)authRefreshTokenOnSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    NSLog(@"++++++++++++ NoaChatSDKCore刷新用户token ++++++++++++++");
    NSString *token = IMSDKManager.myUserToken;
    NSString *myUserId = IMSDKManager.myUserID;
    if (!token || token.length == 0 || !myUserId || myUserId.length == 0) {
        CIMLog(@"Token刷新终止，原因:token、userId异常");
        if (onFailure) {
            onFailure(0, @"", @"");
        }
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   IMSDKManager.myUserToken,@"token",
                                   IMSDKManager.myUserID,@"userUid",nil];
    
    NSLog(@"%@",params);
    
    __weak typeof(self) weakSelf = self;
    
    [self netRequestWithType:LingIMHttpRequestTypePOST path:Auth_Refresh_Token_Url parameters:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        //traceId
        NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
        
        NSString *newToken = (NSString *)data;
        NSLog(@"token自动更新完成，SDK层-1  token：%@",newToken);
        if([newToken isEqualToString:IMSDKManager.myUserToken] || newToken.length == 0 || newToken == nil){
            [weakSelf.netWorkingQueue cancelAllOperations];
            if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkRefreshUsetToken: errorMsg:)]) {
                [weakSelf.userDelegate noaSdkRefreshUsetToken:@"" errorMsg:nil];
            }
            if (onFailure) {
                onFailure(0, @"", ztid);
            }
        }else {
            //更新Kit层token
            if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkRefreshUsetToken: errorMsg:)]) {
                [weakSelf.userDelegate noaSdkRefreshUsetToken:newToken errorMsg:@""];
            }
            
            //更新SDK层token
            NoaIMSDKUserOptions *userOption = [NoaIMSDKUserOptions new];
            userOption.userToken = newToken;
            userOption.userID = IMSDKManager.myUserID;
            userOption.userNickname = IMSDKManager.myUserNickname;
            userOption.userAvatar = IMSDKManager.myUserAvatar;
            [IMSDKManager configSDKUserWith:userOption];
            
            if (onSuccess) {
                onSuccess(newToken, ztid);
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        [weakSelf.netWorkingQueue cancelAllOperations];
        if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkRefreshUsetToken: errorMsg:)]) {
            [weakSelf.userDelegate noaSdkRefreshUsetToken:@"" errorMsg:msg];
        }
        //账号封禁、设备封禁、IP封禁
        if (code == Auth_User_Account_Banned || code == Auth_User_Device_Banned || code == Auth_User_IPAddress_Banned) {
            if ([weakSelf.userDelegate respondsToSelector:@selector(noaSdkRefreshTokenAuthBanned:)]) {
                [weakSelf.userDelegate noaSdkRefreshTokenAuthBanned:code];
            }
            return;
        }
        //traceId
        NSString * ztid = [weakSelf.requestSerializer.HTTPRequestHeaders objectForKey:@"ZTID"];
        if (onFailure) {
            onFailure(code, msg, ztid);
        }
    }];
}

- (void)stopAllRequest {
    [self.operationQueue cancelAllOperations];
}

//将字典转换成json字符串
- (NSString *)convertToJsonData:(NSDictionary *)dict {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString*jsonString;
    if(!jsonData) {
        NSLog(@"%@",error);
    }else{
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    //去掉字符串中的换行符
    NSRange range = {0,mutStr.length};
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range];
    
    return mutStr;
}

#pragma mark - 接口返回的data解密处理
- (id)responseDataDescryptWithDataString:(id)data url:(NSString *)url {
    if ([data isKindOfClass:[NSString class]]) {
        NSString *dataString = (NSString *)data;
        BOOL dataStringIsJson = [self isValidJsonString:dataString];
        //        NSLog(@"解密-- 加密字符串：%@",dataString);
        //如果 dataString 是一个有效Json
        if(dataStringIsJson) {
            id jsonObj = [self jsonObjectFromString:dataString];
            //            NSLog(@"解密-- 解密字符Json对象：%@",jsonObj);
            return jsonObj;
        }else{
            //对 dataString 尝试解密
            NSString *descryptDataStr;
            if ([url containsString:@"system/v2/getSystemConfig"]) {
                descryptDataStr = [LXChatEncrypt method6:dataString];
            } else {
                descryptDataStr = [LXChatEncrypt method7:[IMSDKManager tenantCode] encryptData:dataString];
            }
            //            NSLog(@"解密-- 解密字符串：%@",descryptDataStr);
            
            if(descryptDataStr == nil){
                //解密失败
                return dataString;
            }else{
                //解密成功
                BOOL descryptDataStrIsJson = [self isValidJsonString:descryptDataStr];
                if(descryptDataStrIsJson){
                    id descryptObj = [self jsonObjectFromString:descryptDataStr];
                    //                    NSLog(@"解密-- 2解密字符Json对象：%@",descryptObj);
                    return descryptObj;
                }else{
                    //                    NSLog(@"解密-- 2解密字符串：%@",descryptDataStr);
                    return descryptDataStr;
                }
            }
        }
    } else {
        return data;
    }
}

-(BOOL)isValidJsonString:(NSString *)str{
    NSData * data = [str dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return NO;
    }
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                    options:0
                                                      error:&error];
    return (jsonObject != nil && error == nil);
}

-(id)jsonObjectFromString:(NSString *)jsonString{
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        NSLog(@"Error: Unable to convert string to NSData");
        return nil;
    }
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        NSLog(@"Error: %@", error.localizedDescription);
        return nil;
    }
    
    return jsonObject;
}

#pragma mark - 配置接口请求失败后的日志
- (void)loganConfigWith:(NSString *)url param:(NSDictionary *)param failure:(NSString *)failureReason ztid:(NSString *)ztid {
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:url forKey:@"oprApi"];//请求地址
    [loganDict setValue:[param mj_JSONString] forKey:@"oprParams"];//请求参数
    [loganDict setValue:failureReason forKey:@"failReason"];//失败原因
    [loganDict setValue:ztid forKey:@"ztid"];//ztid

    //写入日志
    NoaIMLoganManager *loganManager = [NoaIMLoganManager sharedManager];
    [loganManager writeLoganWith:LingIMLoganTypeApi loganContent:[loganManager configLoganContent:loganDict]];
    
    [self sentryUploadWithDictionary:loganDict transaction:@"event_http"];

}
- (void)sentryUploadWithDictionary:(NSDictionary *)dictionary transaction:(NSString *)transaction{
    if (!transaction || transaction.length == 0) return;
    if (!dictionary || dictionary.count == 0) return;
    // 交由 App 侧 ZTSentryManager 监听后上报，避免 SDK 依赖 Sentry pod / App 类
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ZTSentryEventUploadNotification"
                                                        object:nil
                                                      userInfo:@{@"transaction": transaction,
                                                                 @"data": dictionary}];
}


#pragma mark - 配置接口请求大于2s的日志
- (void)loganConfigWith:(NSString *)url ztid:(NSString *)ztid traceId:(NSString *)traceId time:(CFTimeInterval)time {
    NSMutableDictionary *loganDict = [NSMutableDictionary dictionary];
    [loganDict setValue:url forKey:@"fullPath"];//请求地址
    [loganDict setValue:@(time) forKey:@"time"]; //时间
    [loganDict setValue:ztid forKey:@"ztid"];//ztid
    [loganDict setValue:traceId forKey:@"traceId"];//traceId
    //写入日志
    NoaIMLoganManager *loganManager = [NoaIMLoganManager sharedManager];
    [loganManager writeLoganWith:LingIMLoganTypeApi loganContent:[loganManager configLoganContent:loganDict]];

}

#pragma mark - 配置网络请求库实现双向认证证书配置
//配置confighttpSessionManagerSecurityPolicy的安全策略
- (void)confighttpSessionManagerCerAndP12CerIsIPAddress:(BOOL)isIPAddress {
    if (isIPAddress == NO) {
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        [self setSecurityPolicy:securityPolicy];
    } else {
        if(self.cerData && self.p12Data && self.p12pwd){
            //安全模式设置：AFSSLPinningModeNone：完全信任服务器证书
            AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
            
            // allowInvalidCertificates 是否允许无效证书（也就是自建的证书），默认为NO
            // 如果是需要验证自建证书，需要设置为YES
            securityPolicy.allowInvalidCertificates = YES;
            
            //validatesDomainName 是否需要验证域名，默认为YES；
            //假如证书的域名与你请求的域名不一致，需把该项设置为NO；如设成NO的话，即服务器使用其他可信任机构颁发的证书，也可以建立连接，这个非常危险，建议打开。
            //置为NO，主要用于这种情况：客户端请求的是子域名，而证书上的是另外一个域名。因为SSL证书上的域名是独立的，假如证书上注册的域名是www.google.com，那么mail.google.com是无法验证通过的；当然，有钱可以注册通配符的域名*.google.com，但这个还是比较贵的。
            //如置为NO，建议自己添加对应域名的校验逻辑。
            securityPolicy.validatesDomainName = NO;
            NSData *cerTempData = [NSData dataWithData:self.cerData];
            securityPolicy.pinnedCertificates = [NSSet setWithArray:@[cerTempData]];
            
            [self setSecurityPolicy:securityPolicy];
            
            __weak typeof(self) weakSelf = self;
            //配置p12证书
            [self setSessionDidBecomeInvalidBlock:^(NSURLSession * _Nonnull session, NSError * _Nonnull error) {
                
            }];
            
            [self setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession*session, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing*_credential) {
                NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
                __autoreleasing NSURLCredential *credential =nil;
                
                NSLog(@"authenticationMethod=%@",challenge.protectionSpace.authenticationMethod);
                
                SecIdentityRef identity = NULL;
                SecTrustRef trust = NULL;
                
                
                if(!weakSelf.p12Data)
                {
                    NSLog(@"p12data:not exist");
                }
                else
                {
                    NSData *PKCS12Data = [NSData dataWithData:weakSelf.p12Data];
                    if ([weakSelf extractIdentity:&identity andTrust:&trust fromPKCS12Data:PKCS12Data])
                    {
                        SecCertificateRef certificate = NULL;
                        SecIdentityCopyCertificate(identity, &certificate);
                        const void*certs[] = {certificate};
                        CFArrayRef certArray =CFArrayCreate(kCFAllocatorDefault, certs,1,NULL);
                        credential =[NSURLCredential credentialWithIdentity:identity certificates:(__bridge  NSArray*)certArray persistence:NSURLCredentialPersistencePermanent];
                        disposition =NSURLSessionAuthChallengeUseCredential;
                    }
                }
                *_credential = credential;
                return disposition;
                
            }];
        }
    }
}

//读取p12文件中的密码
- (BOOL)extractIdentity:(SecIdentityRef*)outIdentity andTrust:(SecTrustRef *)outTrust fromPKCS12Data:(NSData *)inPKCS12Data {
    OSStatus securityError = errSecSuccess;
    //client certificate password
    NSDictionary *optionsDictionary = [NSDictionary dictionaryWithObject:self.p12pwd
                                                                  forKey:(__bridge id)kSecImportExportPassphrase];
    @try {
        CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
        securityError = SecPKCS12Import((__bridge CFDataRef)inPKCS12Data,(__bridge CFDictionaryRef)optionsDictionary,&items);
        
        if(securityError == 0) {
            //CFDictionaryRef myIdentityAndTrust = CFArrayGetValueAtIndex(items,0);
            CFDictionaryRef myIdentityAndTrust = (CFDictionaryRef)CFArrayGetValueAtIndex(items,0);
            const void*tempIdentity =NULL;
            tempIdentity = CFDictionaryGetValue (myIdentityAndTrust,kSecImportItemIdentity);
            *outIdentity = (SecIdentityRef)tempIdentity;
            const void*tempTrust =NULL;
            tempTrust = CFDictionaryGetValue(myIdentityAndTrust,kSecImportItemTrust);
            *outTrust = (SecTrustRef)tempTrust;
        }  else {
            NSLog(@"Failedwith error code %d",(int)securityError);
            return NO;
        }
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
        return NO;
    }
    return YES;
}


#pragma mark - SDK层，token刷新
- (void)refreshAuthToken {
    //开始自动更新token
    //token已过期，需要自动更新一次token
    if (self.refreshTokenOpeartion == nil) {
        __weak typeof(self) weakSelf = self;
        self.refreshTokenOpeartion = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            [weakSelf authRefreshTokenOnSuccess:^(id  _Nullable data, NSString * _Nullable traceId) {
                dispatch_semaphore_signal(semaphore);
            } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                dispatch_semaphore_signal(semaphore);
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            weakSelf.refreshTokenOpeartion = nil;
        }];
        [weakSelf.netWorkingQueue addOperation:weakSelf.refreshTokenOpeartion];
    }
}

- (NSOperationQueue *)netWorkingQueue {
    if (_netWorkingQueue == nil) {
        _netWorkingQueue = [[NSOperationQueue alloc] init];
    }
    return _netWorkingQueue;
}

@end
