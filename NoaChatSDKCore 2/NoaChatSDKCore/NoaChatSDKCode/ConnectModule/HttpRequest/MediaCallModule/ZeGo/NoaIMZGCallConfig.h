//
//  NoaIMZGCallConfig.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/31.
//

//即构SDK相关信息

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMZGCallConfig : NSObject

@property (nonatomic, assign) unsigned int configAppId;//app唯一标识
@property (nonatomic, copy) NSString *configAppSign;//app的鉴权秘钥
@property (nonatomic, copy) NSString *configServerSecret;//后台服务请求接口的鉴权校验
@property (nonatomic, copy) NSString *configCallbackSecret;//后台服务回调接口的鉴权校验
@property (nonatomic, copy) NSString *configServerAddress;//服务器的 WebSocket 通信地址
@property (nonatomic, copy) NSString *configServerAddressBackup;//服务器的 WebSocket 通信地址 备用

@end

NS_ASSUME_NONNULL_END
