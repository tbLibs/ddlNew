//
//  LingIMFriendGroupModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

// 通讯录 好友分组相关数据库Model

#import <Foundation/Foundation.h>

@interface LingIMFriendGroupModel : NSObject

@property (nonatomic, copy) NSString *ugUuid;//好友分组 标识
@property (nonatomic, copy) NSString *ugName;//好友分组 名称
@property (nonatomic, copy) NSString *ugUpdateDateTime;//好友分组 更新时间
@property (nonatomic, assign) NSInteger ugOrder;//好友分组 排序
@property (nonatomic, assign) NSInteger ugType;//好友分组 类型 -1:默认分组，0:用户自定义分组
@property (nonatomic, assign) NSInteger delFlag;//删除标识 0正常；1删除

@end
