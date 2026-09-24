//
//  NoaIMManagerTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/9/29.
//

#import "NoaIMManagerTool.h"
#import <UIKit/UIKit.h>
//#import <SAMKeychain.h>


//获得设备的IP地址
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"


//单例
static dispatch_once_t onceToken;

@interface NoaIMManagerTool ()

@end

@implementation NoaIMManagerTool

#pragma mark - 单例
+ (instancetype)sharedManager {
    static NoaIMManagerTool *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMManagerTool sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMManagerTool sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMManagerTool sharedManager];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearManager{
    onceToken = 0;
}

#pragma mark - ******业务******
#pragma mark - 获取消息内容长度
- (int32_t)getMessageContentLenght:(NSData *)data withHeaderLength:(int32_t *)index {
    
    int8_t tmp = [self readRawByte:data headIndex:index];
    
    if (tmp >= 0) return tmp;
    
    int32_t result = tmp & 0x7f;
    if ((tmp = [self readRawByte:data headIndex:index]) >= 0) {
        result |= tmp << 7;
    } else {
        result |= (tmp & 0x7f) << 7;
        if ((tmp = [self readRawByte:data headIndex:index]) >= 0) {
            result |= tmp << 14;
        } else {
            result |= (tmp & 0x7f) << 14;
            if ((tmp = [self readRawByte:data headIndex:index]) >= 0) {
                result |= tmp << 21;
            } else {
                result |= (tmp & 0x7f) << 21;
                result |= (tmp = [self readRawByte:data headIndex:index]) << 28;
                if (tmp < 0) {
                    for (int i = 0; i < 5; i++) {
                        if ([self readRawByte:data headIndex:index] >= 0) {
                            return result;
                        }
                    }
                    
                    result = -1;
                }
            }
        }
    }
    return result;
}

/// 获取当前SDK的版本号
- (NSString *)getCurrentSdkVersion {
    return @"sdk_1.0.0";
}

//读取字节
- (int8_t)readRawByte:(NSData *)data headIndex:(int32_t *)index {
    if (*index >= data.length) return -1;
    
    *index = *index + 1;
    return ((int8_t *)data.bytes)[*index - 1];
}

#pragma mark - 获得消息的唯一标识
- (NSString *)getMessageID {
    //iOS6出现的方法，每次调用，都会产生一个新值
    NSString *uuid = [[NSUUID UUID] UUIDString];//973FC752-75EA-4217-BEB3-CF5DD0610FC2
    uuid = [uuid stringByReplacingOccurrencesOfString:@"-" withString:@""];
    uuid = [uuid lowercaseString];
    return uuid;
}

#pragma mark - 获得设备的IP地址
- (NSString *)getIPAddress:(BOOL)preferIPV4 {
    NSArray *searchArray = preferIPV4 ?
    @[ IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
        address = addresses[key];
        //筛选出IP地址格式
        if([self isValidatIP:address]) *stop = YES;
    } ];
    return address ? address : @"0.0.0.0";
  
}
- (BOOL)isValidatIP:(NSString *)ipAddress {
    if (ipAddress.length > 0) {
        NSString *urlRegEx = @"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
        "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:urlRegEx options:0 error:&error];
        
        if (regex != nil) {
            NSTextCheckingResult *firstMatch=[regex firstMatchInString:ipAddress options:0 range:NSMakeRange(0, [ipAddress length])];
            
            if (firstMatch) {
                //输出结果
                NSRange resultRange = [firstMatch rangeAtIndex:0];
                if (ipAddress.length == 0) {
                        return NO;
                    }
                if (resultRange.location == NSNotFound || NSMaxRange(resultRange) > ipAddress.length) {
                    return NO;
                }
                NSString *result = [ipAddress substringWithRange:resultRange];
                NSLog(@"%@",result);
                return YES;
            }
        }
        return NO;
    }else {
        return NO;
    }
}
- (NSDictionary *)getIPAddresses {
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

#pragma mark - 获取当前设备的公网IP
- (NSString *)getDevicePublicNetworkIP {
    // 当前公网ip
    NSArray *ipAPIs = @[
        //@"https://api.ipify.org",
        @"https://ipinfo.io/ip",
        @"https://checkip.amazonaws.com",
        @"http://checkip.amazonaws.com"
    ];

    // 使用锁来保证线程安全地访问共享变量ipStr
    NSLock *lock = [[NSLock alloc] init];
    __block NSString *ipStr = @"";
    __block NSInteger ipApiRequestNum = 0;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    for (NSString *apiUrlString in ipAPIs) {
        NSURL *url = [NSURL URLWithString:apiUrlString];
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            ipApiRequestNum++;
            if (!error && data) {
                NSString *ipString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (ipString.length > 0) {
                    // 是合法IP格式，加锁后再赋值给ipStr，保证线程安全
                    [lock lock];
                    ipStr = ipString;
                    [lock unlock];
                }
                dispatch_semaphore_signal(semaphore);
            } else {
                if (ipApiRequestNum == ipAPIs.count) {
                    // 所有请求都失败时返回nil，让调用者决定如何处理
                    ipStr = @"";
                    dispatch_semaphore_signal(semaphore);
                }
            }
        }];
        [task resume];
    }
    // 设置超时时间，避免长时间阻塞导致类似死锁情况
    BOOL semaphoreWaitResult = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC))) == 0;
    if (!semaphoreWaitResult) {
        //获取公网IP超时
        return @"";
    }
    // 如果获取到了有效的ipStr，进行换行符替换并返回，否则返回nil
    if (ipStr.length > 0) {
        // 使用try-catch块来捕获可能在字符串替换操作中出现的异常
        @try {
            if (ipStr != nil && ipStr.length > 0) {
                return [ipStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            } else {
                return @"";
            }
        } @catch (NSException *exception) {
            //字符串替换操作出现异常
            return @"";
        }
    }
    return @"";
}

#pragma mark - IDFV
- (NSString *)appIDFV{
    NSString *strIDFV = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return strIDFV;
}

- (NSString *)appUniqueIdentifier{
//    //服务名
//    NSString *serviceName = [NSBundle mainBundle].bundleIdentifier;
//    //键名
//    NSString *accountKey = @"CIMSDKDEVICEID";
//    //将(IDFV+keychain)作为设备唯一标识
//    NSString *IDFVStr = [SAMKeychain passwordForService:serviceName account:accountKey];
//    if ([IDFVStr isEqualToString:@""] || IDFVStr == nil) {
//        IDFVStr = [self appIDFV];
//        [SAMKeychain setPassword:IDFVStr forService:serviceName account:accountKey];
//    }
//    return IDFVStr ? IDFVStr : @"未知设备";
//    //return @"5DDD17B7-1DF8-4DF4-BB50-1E318446B90A";
    
    return [FCUUID uuidForDevice];
}

#pragma mark - 移除字符串中的特殊字符
- (NSString *)stringReplaceSpecialCharacterWith:(NSString *)oldStr {
    if (oldStr.length > 0) {
        //NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"@／：；（）¥「」＂、[]{}#%-*+=_\\|~＜＞$€^•'@#$%^&*()_+'\""];
        NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@"%_"];
        //由于NSString中有全角符号和半角符号, 因此有些符号要包括全角和半角的
        NSString *newStr = [oldStr stringByTrimmingCharactersInSet:set];
        return newStr;
    }else {
        return oldStr;
    }
}

@end
