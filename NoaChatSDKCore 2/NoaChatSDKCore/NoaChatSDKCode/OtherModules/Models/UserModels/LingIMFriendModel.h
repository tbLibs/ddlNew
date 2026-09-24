//
//  LingIMFriendModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

// 好友相关数据库Model

#import <Foundation/Foundation.h>

@interface LingIMFriendModel : NSObject

//好友id
@property (nonatomic, copy) NSString *friendUserUID;
//好友账号
@property (nonatomic, copy) NSString *userName;
//好友昵称
@property (nonatomic, copy) NSString *nickname;
//好友昵称拼音
@property (nonatomic, copy) NSString * nicknamePinyin;
//好友头像
@property (nonatomic, copy) NSString *avatar;
//会话置顶
@property (nonatomic, assign) BOOL msgTop;
//消息免打扰
@property (nonatomic, assign) BOOL msgNoPromt;
//好有在线状态
@property (nonatomic, assign) BOOL onlineStatus;
//好友备注
@property (nonatomic, copy) NSString *remarks;
//好友备注拼音
@property (nonatomic, copy) NSString * remarksPinyin;
//好友描述
@property (nonatomic, copy) NSString *descRemark;
//账号状态(0正常，1封禁，3注销中，4已注销)
@property (nonatomic, assign) NSInteger disableStatus;
//好友的用户类型 0好友为普通用户 1好友为系统用户
@property (nonatomic, assign) NSInteger userType;
//在视图上显示的名称（有备注的话，此字段和备注一样，没有的备注的话，此字段和nickname一样）
@property (nonatomic, copy) NSString *showName;
//好友 所在好友分组标识
@property (nonatomic, copy) NSString *ugUuid;
//好友 角色名称 id
@property (nonatomic, assign) NSInteger roleId;
//好友状态 1：是好友 0：不是好友（已删除好友）
@property (nonatomic, assign) NSInteger status;

//是否选中状态(不做本地存储)
@property (nonatomic, assign) BOOL isSelected;
// 删除某会话的某个时间之前的全部消息
@property (nonatomic, assign) long long canMsgTime;

@end
