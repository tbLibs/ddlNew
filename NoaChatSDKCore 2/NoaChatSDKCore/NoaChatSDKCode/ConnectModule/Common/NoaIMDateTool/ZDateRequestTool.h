//
//  ZDateRequestTool.h
//  DateDemo
//
//  Created by Candy on 2023/8/4.
//

#import <Foundation/Foundation.h>
#import "NSDate+SyncServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZDateRequestTool : NSObject
//配置默认的服务器时间，防止一下三个方法不生效时，可以利用系统的时间
+ (void)configDefaultServerTime;

+ (void)requestDate;

@end

NS_ASSUME_NONNULL_END
