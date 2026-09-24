//
//  LingIMSessionModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

// 会话相关数据库Model


#import <Foundation/Foundation.h>
#import "NoaIMChatMessageModel.h"
#import "LIMMassMessageModel.h"

//会话类型
typedef NS_ENUM(NSUInteger, CIMSessionType) {
    CIMSessionTypeDefault = 0,        //未知 占位
    CIMSessionTypeSingle = 1,         //单聊
    CIMSessionTypeGroup = 2,          //群聊
    CIMSessionTypeMassMessage = 3,    //群发助手
    CIMSessionTypeSystemMessage = 5,  //系统消息(群助手)
    CIMSessionTypeSignInReminder = 6, //系统消息(签到提醒)
    CIMSessionTypePaymentAssistant = 7,//支付通知
};

//群聊类型
typedef NS_ENUM(NSUInteger, CIMGroupType) {
    CIMGroupTypeDefault = 0,        //未知 占位
    CIMGroupTypeNormal = 1,         //普通群聊
};


@interface LingIMSessionModel : NSObject <NSCopying, NSMutableCopying>

@property (nonatomic, copy) NSString *sessionID;//会话ID
@property (nonatomic, copy) NSString *sessionName;//会话名称
@property (nonatomic, copy) NSString *sessionAvatar;//会话头像
@property (nonatomic, assign) CIMSessionType sessionType;//会话类型
@property (nonatomic, assign) CIMGroupType sessionGroupType;//群聊类型(会话类型为群聊的时候有效)
@property (nonatomic, assign) BOOL sessionTop;//会话置顶
@property (nonatomic, assign) BOOL sessionNoDisturb;//会话免打扰
@property (nonatomic, assign) NSInteger readTag;//0:未读数为0，左滑菜单为标记已读 1:未读数为1，左滑菜单为清除未读
@property (nonatomic, copy) NSString *sessionTableName;//会话表名称

@property (nonatomic, assign) long long sessionTopTime;//会话置顶时间(排序)

@property (nonatomic, assign) NSInteger sessionUnreadCount;//会话未读消息个数

@property (nonatomic, assign) long long sessionLatestTime;//会话最新消息时间(排序)
@property (nonatomic, copy) NSString *sessionLatestServerMsgID;//会话最新消息ID(服务端)，仅在更新服务端会话列表和接收新消息时更新
@property (nonatomic, strong) NSDictionary *draftDict;//草稿内容("draftContent":文本内容, "atUser":@用户信息)
@property (nonatomic, assign) NSInteger sessionStatus;//会话状态 0不进行UI展示，1进行UI展示

@property (nonatomic, strong) NoaIMChatMessageModel *sessionLatestMessage;//最新一条消息(不存储)
@property (nonatomic, strong) LIMMassMessageModel *sessionLatestMassMessage;//群发消息，最新一条消息(不存储)

@property (nonatomic, assign) BOOL isSelected;//是否选中状态(不存储)

@property (nonatomic, assign) long long lastSendMsgTime; //上一次发送消息的时间戳 单位：毫秒

@property (nonatomic, assign) NSInteger roleId;//角色Id

/// 翻译配置信息
//翻译配置项ID
@property (nonatomic, copy) NSString *translateConfigId;

/// 接收
//是否开启接收消息自动翻译
@property (nonatomic, assign) NSInteger isReceiveAutoTranslate; //0:关闭；1:打开
//接收-翻译通道
@property (nonatomic, copy) NSString *receiveTranslateChannel;
@property (nonatomic, copy) NSString *receiveTranslateChannelName;
//接收-翻译目标语种
@property (nonatomic, copy) NSString *receiveTranslateLanguage;
@property (nonatomic, copy) NSString *receiveTranslateLanguageName;

/// 发送
//是否开启发送消息自动翻译
@property (nonatomic, assign) NSInteger isSendAutoTranslate; //0:关闭；1:打开
//发送-翻译通道
@property (nonatomic, copy) NSString *sendTranslateChannel;
@property (nonatomic, copy) NSString *sendTranslateChannelName;
//发送-翻译目标语种
@property (nonatomic, copy) NSString *sendTranslateLanguage;
@property (nonatomic, copy) NSString *sendTranslateLanguageName;


@end
