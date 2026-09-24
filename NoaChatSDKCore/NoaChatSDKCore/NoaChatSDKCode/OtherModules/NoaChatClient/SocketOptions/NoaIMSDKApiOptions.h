//
//  LingIMSDKApiOptions.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/24.
//

// SDK 服务器 相关配置

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKApiOptions : NSObject

// 接口服务器
@property (nonatomic, copy) NSString *imApi;
// 租户标志
@property (nonatomic, copy) NSString *imOrgName;

@end

NS_ASSUME_NONNULL_END
