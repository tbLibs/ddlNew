//
//  LingIMSDKUserOptions.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/5/24.
//

// SDK 用户信息 相关配置

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKUserOptions : NSObject
@property (nonatomic, copy) NSString *userID;//用户id
@property (nonatomic, copy) NSString *userToken;//用户token
@property (nonatomic, copy) NSString *userNickname;//用户昵称
@property (nonatomic, copy) NSString *userAvatar;//用户头像
@end

NS_ASSUME_NONNULL_END
