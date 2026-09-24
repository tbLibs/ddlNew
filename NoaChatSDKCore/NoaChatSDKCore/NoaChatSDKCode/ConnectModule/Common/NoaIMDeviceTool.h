//
//  NoaIMDeviceTool.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDeviceTool : NSObject

//当前设备型号
+ (NSString *)currentDeviceModel;

//设备平台
+ (NSString *)devicePlatform;

//获取当前系统版本iOS16.5
+ (NSString*)systemVersion;

//App版本号 1.0.0
+ (NSString *)appVersion;

@end

NS_ASSUME_NONNULL_END
