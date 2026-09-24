//
//  NSDate+SyncServer.m
//  DateDemo
//
//  Created by Candy on 2023/8/4.
//

/*
 时间校准设计
 1.1获取某一时刻服务器的时间A
 1.2获取同一时刻下的本地时间B
 2.需要用到时间时，获取当前时间C，按照C-B作为时间间隔D，则A+D是当前服务器的时间
 说明：要准确的做到客户端和服务端的时间一致，则B和C必须是不受系统时间影响的，所以采用iOS的接口---系统运行时间
 */

#import "NSDate+SyncServer.h"
#import <sys/sysctl.h>
#import <MMKV/MMKV.h>

@implementation NSDate (SyncServer)

#pragma mark - 获取默认系统时间作为服务器返回时间的默认值
+ (void)getDefaultServerTimeFromSystem {
    
    //当前跟随系统的时间戳
    NSDate *currentDate = [NSDate date];
    long long currentServerTime = [currentDate timeIntervalSince1970] * 1000;
    
    //当前系统运行时间戳
    long long currentSystemRunTime = [NSDate getCurrentSystemRunTimeValue] * 1000;
    
    if (currentServerTime > 0) {
        [[MMKV defaultMMKV] setUInt64:currentServerTime forKey:@"SyncTimeForServer"];
        
    }
    
    if (currentSystemRunTime > 0) {
        [[MMKV defaultMMKV] setUInt64:currentSystemRunTime forKey:@"SyncTimeForSystemRun"];
        
    }
}

#pragma mark - 根据服务器返回信息获取服务器毫秒级时间戳
+ (void)getMillisecondTimeFromServerWith:(NSURLResponse * __nullable)response {
    
    if (![response isKindOfClass:NSHTTPURLResponse.class]) {
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    //请求到达服务器时的服务器时间
    NSString *dateServer = [httpResponse.allHeaderFields objectForKey:@"Date"];
    if (dateServer == nil) {
        return;
    }
    if (![dateServer isKindOfClass:NSString.class]) {
        return;
    }
    //服务器时间字符串转换为Date
    NSDate *inputDate = [NSDate dateFromServiceWith:dateServer];
    if (inputDate == nil) {
        return;
    }
    
    //当前服务器返回的时间戳(毫秒级)
    long long currentServerTime = [inputDate timeIntervalSince1970] * 1000;
    
    //当前系统运行的时间(毫秒级)
    long long currentSystemRunTime = [NSDate getCurrentSystemRunTimeValue] * 1000;
    
    if (currentServerTime > 0) {
        //存储服务器返回的时间戳
        [[MMKV defaultMMKV] setInt64:currentServerTime forKey:@"SyncTimeForServer"];
        
    }
    
    if (currentSystemRunTime > 0) {
        //存储当前系统运行的时间
        [[MMKV defaultMMKV] setInt64:currentSystemRunTime forKey:@"SyncTimeForSystemRun"];
        
    }
    
}
#pragma mark - 获取同步的服务器时间戳(毫秒级)
+ (long long)getSyncMillisecondTimeFromServer {
    long long syncTimeServer = [[MMKV defaultMMKV] getInt64ForKey:@"SyncTimeForServer"];
    return syncTimeServer;
}

+ (BOOL)hasValidServerTimeSync {
    // 2001-09-09 前后的毫秒时间戳量级，过滤 0 / 开机时长误当 epoch 的情况
    long long syncTimeServer = [[MMKV defaultMMKV] getInt64ForKey:@"SyncTimeForServer"];
    return syncTimeServer > 1000000000000LL;
}

#pragma mark - 获取校准后的服务器毫秒级时间戳(毫秒级)
+ (long long)getCurrentServerMillisecondTime {
    if (![self hasValidServerTimeSync]) {
        return [self getCurrentTimeIntervalWithSecond];
    }
    //服务器同步的时间戳(毫秒)
    long long syncTimeServer = [[MMKV defaultMMKV] getInt64ForKey:@"SyncTimeForServer"];
    long long syncTimeSystemRun = [[MMKV defaultMMKV] getInt64ForKey:@"SyncTimeForSystemRun"];
    //当前系统运行时间
    long long currentTimeSystemRun = [NSDate getCurrentSystemRunTimeValue] * 1000;
    
    //时间间隔(毫秒)
    long long timeInterval = currentTimeSystemRun - syncTimeSystemRun;
    
    //获取当前服务器时间戳(毫秒)
    long long currentServerTime = syncTimeServer + timeInterval;
    if (currentServerTime <= 1000000000000LL) {
        return [self getCurrentTimeIntervalWithSecond];
    }
    return currentServerTime;
}

+ (long long)safeCurrentServerMillisecondTime {
    return [self getCurrentServerMillisecondTime];
}

#pragma mark - 获取0时区的时间格式 -- private
+ (NSDateFormatter *)dateFormatterForGMT {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *en_US_POSIX = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:en_US_POSIX];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return dateFormatter;
}

#pragma mark - UTC时间字符串
+ (NSString *)UTCDateTimeStr {
    // 获取当前的UTC日期时间
    NSDate *date = [NSDate date];
    NSTimeZone *utcTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSInteger seconds = [utcTimeZone secondsFromGMTForDate:date];
    NSDate *utcDate = [date dateByAddingTimeInterval:seconds];
     
    // 创建一个日期格式器
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
     
    // 获取UTC日期时间的字符串表示
    NSString *utcString = [formatter stringFromDate:utcDate];
    return utcString;
}

#pragma mark - 服务器Header里的时间获取 -- private
+ (NSDate *)dateFromServiceWith:(NSString *)dateString {
    NSDate *date = nil;
    
    if (dateString) {
        NSDateFormatter *dateFormatter = [NSDate dateFormatterForGMT];
        @synchronized(dateFormatter) {

            // Process
            NSString *RFC822String = [[NSString stringWithString:dateString] uppercaseString];
            if ([RFC822String rangeOfString:@","].location != NSNotFound) {
                if (!date) { // Sun, 19 May 2002 15:21:36 GMT
                    [dateFormatter setDateFormat:@"EEE, d MMM yyyy HH:mm:ss zzz"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
                if (!date) { // Sun, 19 May 2002 15:21 GMT
                    [dateFormatter setDateFormat:@"EEE, d MMM yyyy HH:mm zzz"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
                if (!date) { // Sun, 19 May 2002 15:21:36
                    [dateFormatter setDateFormat:@"EEE, d MMM yyyy HH:mm:ss"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
                if (!date) { // Sun, 19 May 2002 15:21
                    [dateFormatter setDateFormat:@"EEE, d MMM yyyy HH:mm"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
            } else {
                if (!date) { // 19 May 2002 15:21:36 GMT
                    [dateFormatter setDateFormat:@"d MMM yyyy HH:mm:ss zzz"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
                if (!date) { // 19 May 2002 15:21 GMT
                    [dateFormatter setDateFormat:@"d MMM yyyy HH:mm zzz"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
                if (!date) { // 19 May 2002 15:21:36
                    [dateFormatter setDateFormat:@"d MMM yyyy HH:mm:ss"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
                if (!date) { // 19 May 2002 15:21
                    [dateFormatter setDateFormat:@"d MMM yyyy HH:mm"];
                    date = [dateFormatter dateFromString:RFC822String];
                }
            }
            if (!date) NSLog(@"Could not parse RFC822 date: \"%@\" Possible invalid format.", dateString);
            
        }
    }
    
    return date;
}

#pragma mark - 获取当前系统运行了多少时间(单位：秒) -- private
+ (long long)getCurrentSystemRunTimeValue {
    struct timeval boottime;
    
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    size_t size = sizeof(boottime);
    
    //获取Unix time
    //Unix time是以UTC 1970年1月1号 00：00：00为基准时间，当前时间距离基准点偏移的秒数
    struct timeval now;
    struct timezone tz;
    gettimeofday(&now, &tz);
    
    //时间间隔
    double uptime = -1;
    
    //sysctl()记录了设备重启的时间
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1 && boottime.tv_sec != 0)
    {
        uptime = now.tv_sec - boottime.tv_sec;
        uptime += (double)(now.tv_usec - boottime.tv_usec) / 1000000.0;
    }
    
    NSLog(@"当前系统运行时间%f", uptime);
    return uptime;
    /*
     gettimeofday()和sysctl()都会受系统时间影响,但他们二者做一个减法所得的值,就和系统时间无关了.这样就可以避免用户修改时间了
     */
}

#pragma mark - 获取当前设备时间戳(毫秒级)
+(long long)getCurrentTimeIntervalWithSecond; {
    NSDate *date = [NSDate date];
    long long time = [date timeIntervalSince1970] * 1000;
    return time;
}
@end
