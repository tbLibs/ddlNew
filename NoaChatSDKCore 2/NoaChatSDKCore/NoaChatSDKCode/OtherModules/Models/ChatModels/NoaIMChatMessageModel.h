//
//  NoaIMChatMessageModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

// 数据库 消息Model


#import <Foundation/Foundation.h>

#import <MJExtension/MJExtension.h>
#import "NoaIMSDK.h"

//聊天消息发送状态枚举
typedef NS_ENUM(NSUInteger, CIMChatMessageSendType) {
    CIMChatMessageSendTypeSending = 0,//发送中
    CIMChatMessageSendTypeSuccess = 1,//发送成功
    CIMChatMessageSendTypeFail = 2,//发送失败
};

//聊天消息翻译状态
typedef NS_ENUM(NSUInteger, CIMTranslateStatus) {
    CIMTranslateStatusNone = 0,     //无译文或隐藏译文
    CIMTranslateStatusLoading = 1,  //翻译中
    CIMTranslateStatusSuccess = 2,  //翻译成功
    CIMTranslateStatusFail = 3,     //翻译失败
};

//聊天类型枚举
typedef NS_ENUM(NSUInteger, CIMChatType) {
    /** 单聊消息 */
    CIMChatType_SingleChat = 0,
    /** 群聊消息 */
    CIMChatType_GroupChat = 1,
    /** 开放消息 */
    CIMChatType_OpenChat = 2,
    /** 群发助手 */
    CIMChatType_GroupHair = 3,
    /** 系统消息 (群助手) */
    CIMChatType_SystemMessage = 5,
    /** 音视频通话消息 */
    CIMChatType_NetCallChat = 6,
    /** 系统消息 (签到提醒) */
    CIMChatType_SignInReminder = 7,
    /** 系统消息 (支付通知) */
    CIMChatType_PaymentAssistant = 8,
};

/** 消息内容类型 */
typedef NS_ENUM(NSUInteger, CIMChatMessageType) {
    /** 基础聊天类消息 */
    CIMChatMessageType_TextMessage = 0,
    /** 图片消息 */
    CIMChatMessageType_ImageMessage = 1,
    /** 视频消息 */
    CIMChatMessageType_VideoMessage = 2,
    /** 地理定位 */
    CIMChatMessageType_GeoMessage = 3,
    /** 音频消息 */
    CIMChatMessageType_VoiceMessage = 4,
    /** 文件消息 */
    CIMChatMessageType_FileMessage = 5,
    /** 名片消息 */
    CIMChatMessageType_CardMessage = 6,
    /** 位置消息 */
    CIMChatMessageType_LocationMessage = 7,
    /** 撤回消息 */
    CIMChatMessageType_BackMessage = 8,
    /** 删除消息 */
    CIMChatMessageType_DelMessage = 9,
    /** \@用户消息(该消息为特殊消息，前后端一起定义) */
    CIMChatMessageType_AtMessage = 10,
    /** 表情消息 */
    CIMChatMessageType_StickersMessage = 12,
    /** 已读消息 */
    CIMChatMessageType_HaveReadMessage = 13,
    /** 双向删除 */
    CIMChatMessageType_BilateralDel = 15,
    /** 群组公告消息 */
    CIMChatMessageType_GroupNotice = 16,
    /** 合并转发消息 */
    CIMChatMessageType_ForwardMessage = 18,
    /** 音视频通话消息 */
    CIMChatMessageType_NetCallMessage = 20,
    /** 游戏表情 */
    CIMChatMessageType_GameStickersMessage = 21,
    /** 系统通知类型消息 */
    CIMChatMessageType_ServerMessage = 1000,
};


@interface NoaIMChatMessageModel : NSObject

/** 当前版本消息是否完整 */
@property (nonatomic, assign) BOOL currentVersionMessageOK;

/** 消息状态 */
@property (nonatomic, assign) NSInteger messageStatus;//1正常消息 0消息已被删除 2消息已被撤回

/** 聊天消息发送状态 */
@property (nonatomic, assign) CIMChatMessageSendType messageSendType;
/// 本地消息发送失败原因；0 表示无失败原因、未知原因或升级前的历史数据。
@property (nonatomic, assign) CIMMessageSendFailureReason sendFailureReason;

/** 消息ID(前端消息ID) */
@property (nonatomic, copy) NSString * _Nullable msgID;
/** 消息ID(服务消息ID) */
@property(nonatomic, copy) NSString * _Nullable serviceMsgID;
/** 聊天类型 */
@property (nonatomic, assign) CIMChatType chatType;
/** 消息类型 */
@property (nonatomic, assign) CIMChatMessageType messageType;
/** 发送者(用户ID) */
@property (nonatomic, copy) NSString * _Nullable fromID;
/** 发送者昵称 */
@property (nonatomic, copy) NSString * _Nullable fromNickname;
/** 发送者头像 */
@property(nonatomic, copy) NSString * _Nullable fromIcon;
/** 接受者(用户ID/群组ID) */
@property (nonatomic, copy) NSString * _Nullable toID;
/** 是否需要回执(true/false,该值必传) */
@property(nonatomic, readwrite) BOOL isAck;
/** 是否加密(true/false,默认false) */
@property(nonatomic, readwrite) BOOL isEncry;
/** 阅后即焚时间戳(默认0) */
@property(nonatomic, assign) NSInteger snapchat;
/** 发送时间(单位:毫秒) */
@property(nonatomic, assign) long long sendTime;
/** 发送的设备(服务端使用，前端不用传递和使用) */
@property(nonatomic, copy) NSString * _Nullable toSource;
/** 发送的用户(服务端使用，前端不用传递和使用) */
@property(nonatomic, copy) NSString * _Nullable toUid;
/** 单聊或群聊消息已读 */
@property (nonatomic, assign) BOOL chatMessageReaded;//聊天消息我是否已读
@property(nonatomic, assign) NSInteger haveReadCount;//聊天消息已读人数
@property(nonatomic, assign) NSInteger totalNeedReadCount;//聊天消息总共需要读的人数

//引用的消息id（引用时候传入，未引用则不传）
@property (nonatomic, copy) NSString * _Nullable referenceMsgId;

//翻译状态
@property (nonatomic, assign) CIMTranslateStatus translateStatus;

//文本消息
@property (nonatomic, copy) NSString * _Nullable textContent;//文本内容
@property (nonatomic, copy) NSString * _Nullable textExt;//拓展字段
@property (nonatomic, copy) NSString * _Nullable translateContent;//文本翻译后内容
@property (nonatomic, copy) NSString * _Nullable againTranslateContent;//文本再次翻译后内容

//图片消息
@property (nonatomic, assign) float imgHeight;//图片高度
@property (nonatomic, assign) float imgWidth;//图片宽度
@property (nonatomic, assign) float imgSize;//图片大小
@property (nonatomic, copy) NSString * _Nullable imgName;//图片名字(原图)
@property (nonatomic, copy) NSString * _Nullable thumbnailImg;//图片名字(缩略图)
@property (nonatomic, copy) NSString * _Nullable imgExt;//拓展字段
@property (nonatomic, copy) NSString * _Nullable localImgName;//本地沙盒图片名字(发送消息的时候赋值)
@property (nonatomic, copy) NSString * _Nullable localthumbImgName;//本地沙盒缩略图名字(发送消息的时候赋值)
@property (nonatomic, strong) UIImage * _Nullable localImg;//本地沙盒图片(发送消息的时候赋值)
@property (nonatomic, assign) BOOL isSendForFile;//图片大的话，有图转文件的判断

//视频消息
@property (nonatomic, copy) NSString * _Nullable videoCover;//视频封面
@property (nonatomic, assign) float videoCoverH;//视频封面高度
@property (nonatomic, assign) float videoCoverW;//视频封面宽度
@property (nonatomic, assign) float videoCoverSize;//视频封面大小
@property (nonatomic, assign) float videoLength;//视频长度
@property (nonatomic, assign) float videoSize;//视频大小
@property (nonatomic, copy) NSString * _Nullable videoName;//视频名字
@property (nonatomic, copy) NSString * _Nullable videoExt;//拓展字段
@property (nonatomic, copy) NSString * _Nullable localVideoName;//本地沙盒视频名字
@property (nonatomic, copy) NSString * _Nullable localVideoCover;//本地沙盒视频封面名字

//语音消息
@property (nonatomic, assign) float voiceLength;//语音时长
@property (nonatomic, copy) NSString * _Nullable voiceName;//语音文件名称
@property (nonatomic, copy) NSString * _Nullable voiceExt; //拓展字段
@property (nonatomic, copy) NSString * _Nullable localVoiceName;//本地沙盒语音文件名称
@property (nonatomic, copy) NSString * _Nullable localVoicePath;//本地沙盒语音文件完整路径

//文件消息
@property (nonatomic, assign) float fileSize;//文件大小
@property (nonatomic, copy) NSString * _Nullable fileName;//文件名称
@property (nonatomic, copy) NSString * _Nullable filePath;//文件路径
@property (nonatomic, copy) NSString * _Nullable fileType;//文件类型
@property (nonatomic, copy) NSString * _Nullable fileExt; //拓展字段
@property (nonatomic, copy) NSString * _Nullable showFileName;//需要展示的文件名称

//消息 撤回
@property (nonatomic, copy) NSString * _Nullable backDelServiceMsgID;//撤回 删除 的消息服务端ID
@property (nonatomic, copy) NSString * _Nullable backDeleteExt;//拓展字段
@property (nonatomic, assign) NSInteger backDelInformSwitch;//撤回 删除 的消息服务端ID
@property (nonatomic, strong) NSMutableArray * _Nullable backDelInformUidArray;//拓展字段

//@消息
@property (nonatomic, copy) NSString * _Nullable atContent;//@消息内容
@property (nonatomic, strong) NSArray * _Nullable atUsersInfoList;//@人员信息
@property (nonatomic, strong) NSMutableDictionary * _Nullable atUsersDict;//@人员信息(旧的数据结果，现在无用了)
@property (nonatomic, copy) NSString * _Nullable atExt;//@消息拓展
@property (nonatomic, copy) NSString * _Nullable showContent;//@消息展示内容
@property (nonatomic, copy) NSString * _Nullable atTranslateContent;//文本翻译后内容
@property (nonatomic, copy) NSString * _Nullable againAtTranslateContent;//文本再次翻译后内容
@property (nonatomic, copy) NSString * _Nullable showTranslateContent;//@消息展示内容

//群公告消息
@property (nonatomic, copy) NSString * _Nullable groupNoticeContent;//群公告内容
@property (nonatomic, copy) NSString * _Nullable groupNoticeTranslateContent;//群公告(译文)内容
@property (nonatomic, copy) NSString * _Nullable groupNoticeID;//群公告ID
@property (nonatomic, copy) NSString * _Nullable groupNoticeExt;//拓展字段

//需要在聊天界面展示的 系统通知 类型的消息
@property (nonatomic, strong) NSData * _Nullable serverMessageProtobuf;//存储数据库
@property (nonatomic, strong) IMServerMessage * _Nullable serverMessage;//不存储数据库，UI展示的时候取该字段值

//名片消息
@property (nonatomic, copy) NSString * _Nullable cardUrl;//名片访问地址
@property (nonatomic, copy) NSString * _Nullable cardName;//名片名称
@property (nonatomic, copy) NSString * _Nullable cardUserId;//用户ID
@property (nonatomic, copy) NSString * _Nullable cardHeadPicUrl;//头像地址
@property (nonatomic, copy) NSString * _Nullable cardNickName;//用户昵称
@property (nonatomic, copy) NSString * _Nullable cardUserName;//用户名
@property (nonatomic, copy) NSString * _Nullable cardExt;//扩展字段

//地理定位
@property (nonatomic, copy) NSString * _Nullable geoLng;//维度
@property (nonatomic, copy) NSString * _Nullable geoLat;//精度
@property (nonatomic, copy) NSString * _Nullable geoName;//地理名称
@property (nonatomic, copy) NSString * _Nullable geoImg;//地理封面图
@property (nonatomic, assign) float geoImgHeight;//地理封面图高度
@property (nonatomic, assign) float geoImgWidth;//地理封面图宽度
@property (nonatomic, copy) NSString * _Nullable geoExt;//扩展字段
@property (nonatomic, copy) NSString * _Nullable geoDetails;//地理位置详情
@property (nonatomic, copy) NSString * _Nullable localGeoImgName;//本地沙盒图片名字(发送时赋值)


//多选-合并转发 消息记录
@property (nonatomic, strong) NSData * _Nullable forwardMessageProtobuf;//存储数据库
@property (nonatomic, strong) ForwardMessage * _Nullable forwardMessage;//不存储数据库，UI展示的时候取该字段值

//系统公告
@property (nonatomic, copy) NSString * _Nullable systemNoticeTitle;//系统公告 标题
@property (nonatomic, copy) NSString * _Nullable systemNoticeContent;//系统公告 内容
@property (nonatomic, copy) NSString * _Nullable systemNoticeImages;//系统公告 图片，多个图片以半角逗号(,)隔开

//网络媒体通话(音视频)(目前是用的是 即构)
@property (nonatomic, copy) NSString * _Nullable netCallRoomCreateUser;//创建房间的用户
@property (nonatomic, copy) NSString * _Nullable netCallId;//通话id
@property (nonatomic, copy) NSString * _Nullable netCallRoomId;//房间ID
@property (nonatomic, copy) NSString * _Nullable netCallToken;//鉴权token
@property (nonatomic, assign) NSInteger netCallType;//模式, 1语音 2视频
@property (nonatomic, assign) NSInteger netCallTimeout;//超时时间 默认秒
@property (nonatomic, assign) NSInteger netCallChatType;//聊天类型，1单聊类型，2群聊类型
@property (nonatomic, assign) NSInteger netCallDuration;//单聊通话时长
@property (nonatomic, strong) NSArray * _Nullable netCallRoomUsers;//群聊 房间成员(已接听成员)
@property (nonatomic, strong) NSArray * _Nullable netCallOperationUsers;//群聊 本次动作的操作者
//单聊通话状态，1:发起，2:取消，3:超时未应答，4:拒绝，5:挂断，6:接受，7:通话中断,8:其他设备已接听
//群聊通话状态，1:发起，3:超时未应答，4:拒绝，5:挂断，6:接受，7:通话中断,8:其他设备已接听，9:邀请加入，10：主动加入，11:结束
@property (nonatomic, assign) NSInteger netCallStatus;

//音视频通话操作提示消息 LiveKit 采用的是 IMServerMessage -> CustomEvent(content字段json);
//CustomEvent type字段 101单聊音视频 102群聊音视频(处理通话逻辑) 103群聊音视频(处理消息展示和通话信息(当前多少人正在通话)展示)

//表情消息StickersMessage
@property (nonatomic, assign) float stickersHeight;//表情图片高度
@property (nonatomic, assign) float stickersWidth;//表情图片宽度
@property (nonatomic, assign) long long stickersSize;//表情图片大小
@property (nonatomic, copy) NSString * _Nullable stickersName;//表情图片名字
@property (nonatomic, copy) NSString * _Nullable stickersId;//表情图片唯一id
@property (nonatomic, copy) NSString * _Nullable stickersThumbnailImg;//表情图片(缩略图)
@property (nonatomic, copy) NSString * _Nullable stickersImg;//表情图片(原图)
@property (nonatomic, assign) BOOL isStickersSet;//是否为表情包里的表情
@property (nonatomic, copy) NSString * _Nullable stickersExt;//拓展字段


//已读消息HaveReadMessage
@property (nonatomic, strong) NSMutableArray<NSString*> * _Nullable sMsgIdArray ;//需要标记已读的sMsgId数组

//游戏表情
@property(nonatomic, assign) int gameSticekersType;//类型 - type 1:石头剪刀布 2:色子
@property (nonatomic, copy) NSString * _Nullable gameStickersResut;//结果信息(字符串)
@property (nonatomic, copy) NSString * _Nullable gameStickersExt;//拓展字段
@property (nonatomic, assign) BOOL isGameAnimationed;//是否已经展示过动画

// 本地标记：该消息的译文是否在本机成功展示过（0:否 1:是），用于全局翻译关闭时保留历史译文显示
@property (nonatomic, assign) NSInteger localTranslatedShown;

@end
