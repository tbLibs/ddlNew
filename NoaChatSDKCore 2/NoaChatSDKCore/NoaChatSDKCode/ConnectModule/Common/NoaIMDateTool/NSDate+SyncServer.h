//
//  NSDate+SyncServer.h
//  DateDemo
//
//  Created by Candy on 2023/8/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (SyncServer)

//获取默认系统时间作为服务器返回时间的默认值
+ (void)getDefaultServerTimeFromSystem;

//获取服务端返回的时间戳(毫秒级)
+ (void)getMillisecondTimeFromServerWith:(NSURLResponse * __nullable)response;
//获取同步的服务器时间戳(毫秒级)
+ (long long)getSyncMillisecondTimeFromServer;
/// 是否已有有效的服务端时间校准（SyncTimeForServer 为合理 epoch 毫秒）
+ (BOOL)hasValidServerTimeSync;
//获取校准后的服务器毫秒级时间戳(毫秒级)；未校准时回退设备时间，避免发出接近 0 的假时间
+ (long long)getCurrentServerMillisecondTime;
/// 与 getCurrentServerMillisecondTime 相同，语义上强调「可安全用于发消息」
+ (long long)safeCurrentServerMillisecondTime;
//获取当前设备时间戳(毫秒级)
+(long long)getCurrentTimeIntervalWithSecond;
//UTC时间字符串
+ (NSString *)UTCDateTimeStr;
@end

NS_ASSUME_NONNULL_END
