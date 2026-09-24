//
//  LingIMUserModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

// 用户相关数据库Model

#import <Foundation/Foundation.h>

@interface LingIMUserModel : NSObject

@property(nonatomic, copy) NSString *userUID;//用户ID
@property(nonatomic, copy) NSString *userNickname;//用户昵称
@property(nonatomic, copy) NSString *userAccount;//用户账号
@property(nonatomic, copy) NSString *userAvatar;//用户头像
@property(nonatomic, copy) NSString *userRemark;//用户备注
@property (nonatomic, assign) BOOL myFriend;//是否是好友
@property (nonatomic, assign) NSInteger roleId;//角色Id

@end
