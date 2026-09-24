//
//  LingIMSDKHostOptions.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/24.
//

// SDK IM 相关配置

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKHostOptions : NSObject

//socket 主机 地址
@property (nonatomic, copy) NSString *imHost;
//socket 主机 端口
@property (nonatomic, copy) NSString *imPort;

@end

NS_ASSUME_NONNULL_END
