//
//  LingIMGroupModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import <Foundation/Foundation.h>

@interface LingIMGroupModel : NSObject

@property(nonatomic, copy) NSString *groupId;//群组ID
@property(nonatomic, copy) NSString *groupName;//群组名称
@property(nonatomic, copy) NSString *groupAvatar;//群组头像
@property (nonatomic, assign) BOOL msgTop;//群聊会话置顶
@property (nonatomic, assign) BOOL msgNoPromt;//群聊消息免打扰
@property (nonatomic, assign) BOOL isGroupChat;//全群是否禁言
@property (nonatomic, assign) BOOL isNeedVerify;//进群是否需要验证
@property (nonatomic, assign) BOOL isPrivateChat;//全群是否禁止私聊
@property (nonatomic, assign) BOOL isNetCall;//是否开启全员禁止拨打音视频
@property (nonatomic, assign) BOOL isShowHistory;//新成员是否可以查看群历史记录
@property (nonatomic, assign) NSInteger isMessageInform;//是否开启群提示
@property (nonatomic, assign) NSInteger groupInformStatus;//开启/关闭群通知：0:关闭群通知 1:开启群通知 (默认为1 开启) 优先级高于isMessageInform
@property (nonatomic, assign) NSInteger groupStatus;//群状态0封禁1正常2删除
@property (nonatomic, assign) NSInteger leaveGroupStatus;//离群状态（0：正常；1：退群)
@property (nonatomic, assign) NSInteger userGroupRole;//我在本群的角色(0普通成员;1管理员;2群主)
@property (nonatomic, assign) NSInteger memberCount;
@property (nonatomic, assign) long long lastSyncMemberTime;//上次同步群成员的时间戳
@property (nonatomic, assign) long long lastSyncActiviteScoreime;//上次同步群成员活跃积分的时间戳
@property (nonatomic, assign) BOOL isShowQrCode;//是否显示群二维码(0:不展示; 1:展示)
@property (nonatomic, assign) BOOL closeSearchUser;//关闭搜索用户0:否1:是
@property (nonatomic, assign) long long canMsgTime;//删除该时间戳之前的本地消息
@property (nonatomic, assign) NSInteger isActiveEnabled;//是否启用群活跃功能（0：关闭，1：开启）

@property (nonatomic, assign) BOOL isSelected;  //是否选中状态(不用存储在数据库)


@end
