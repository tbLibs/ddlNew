//
//  NoaIMSocketHostOptions.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSocketHostOptions : NSObject

@property (nonatomic, copy) NSString *socketHost;      //主机地址
@property (nonatomic, assign) NSInteger socketPort;    //主机端口
@property (nonatomic, copy) NSString *socketOrgName;   //租户标识

@end

NS_ASSUME_NONNULL_END
