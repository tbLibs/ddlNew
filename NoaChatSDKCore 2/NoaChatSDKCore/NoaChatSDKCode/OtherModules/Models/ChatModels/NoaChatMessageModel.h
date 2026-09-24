//
//  NoaChatMessageModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

#import <Foundation/Foundation.h>
#import <MJExtension/MJExtension.h>
#import "NoaIMChatMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaChatMessageModel : NSObject

@property (nonatomic, copy) NSString *ID;

@property (nonatomic, copy) NSString *referenceMsgId;//被引用消息ID
@property (nonatomic, copy) NSString *msgId;//消息ID
@property (nonatomic, copy) NSString *smsgId;//服务端生成的消息ID
@property (nonatomic, assign) long long sendTime;//消息发送时间
@property (nonatomic, assign) CIMChatType ctype;//聊天类型
@property (nonatomic, assign) CIMChatMessageType mtype;//消息类型
@property (nonatomic, assign) NSInteger status;//消息状态 1正常  2撤回   0删除
@property (nonatomic, assign) BOOL isRead;//消息是否已读(我)
@property (nonatomic, copy) NSString *fromUid;//发送消息人ID
@property (nonatomic, copy) NSString *nick;//发送消息人昵称
@property (nonatomic, copy) NSString *icon;//发送消息人头像
@property (nonatomic, copy) NSString *toUid;//接收消息ID(人/群)
@property (nonatomic, copy) NSString *body;//消息内容json

@property (nonatomic, assign) BOOL isAck;//是否需要回执
@property (nonatomic, assign) BOOL isEncry;//是否加密
@property (nonatomic, assign) NSInteger snapchat;//阅后即焚时间戳

@property (nonatomic, assign) NSInteger totalNeedReadCount;//消息总需要读人数
@property (nonatomic, assign) NSInteger haveReadCount;//消息已读人数


/// 根据聊天记录消息，获取数据库存储类型消息
- (NoaIMChatMessageModel *)getChatMessageFromMessageRecordModel;

/** 将历史消息记录中字典格式数据转换成IMChatMessage 只用于转发消息记录中的messageList */
- (NSMutableArray <IMChatMessage *> *)getIMChatMessageFormBodyArr:(NSArray *)bodyMessageArr;

@end

NS_ASSUME_NONNULL_END
