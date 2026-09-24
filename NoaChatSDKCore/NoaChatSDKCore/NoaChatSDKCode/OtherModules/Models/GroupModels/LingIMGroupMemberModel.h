//
//  LingIMGroupModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import <Foundation/Foundation.h>

@interface LingIMGroupMemberModel : NSObject

@property (nonatomic, copy) NSString *userUid;//ID
@property (nonatomic, assign) NSInteger areMyFriend;//是否是我的好友
@property (nonatomic, copy) NSString *joinTime;//群成员入群时间
@property (nonatomic, copy) NSString *nicknameInGroup;//群成员在本群的昵称
@property (nonatomic, assign) NSInteger role;//群成员角色 (0普通成员 1管理员 2群主 3机器人)
@property (nonatomic, copy) NSString *userAvatar;//头像
@property (nonatomic, copy) NSString *userName;//用户名
@property (nonatomic, copy) NSString *userNickname;//昵称

@property (nonatomic, assign) BOOL isGroupMember;//维护一个是否已经选择此成员的属性，供业务层使用

//好友备注
@property (nonatomic, copy) NSString * remarks;
//好友描述
@property (nonatomic, copy) NSString * descRemark;
//账号状态(注销状态：4)
@property (nonatomic, assign) NSInteger disableStatus;
//在视图上显示的名称（有备注的话，此字段和备注一样，没有的备注的话，此字段和nickname一样）
@property (nonatomic, copy) NSString * showName;
//判断当前用户是否在群组中
@property (nonatomic, assign) BOOL memberIsInGroup;
//角色Id
@property (nonatomic, assign) NSInteger roleId;
//是否已经从本群删除
@property (nonatomic, assign) BOOL isDel;
//群成员活跃等级分数
@property (nonatomic, assign) NSInteger activityScroe;
//上传更新群成员时间戳
@property (nonatomic, assign) long long latestUpdateTime;

@end
