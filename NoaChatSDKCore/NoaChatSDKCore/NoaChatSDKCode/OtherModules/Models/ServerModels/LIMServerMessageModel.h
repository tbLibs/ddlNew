//
//  LIMServerMessageModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

#import <Foundation/Foundation.h>

#import <MJExtension/MJExtension.h>
#import "NoaIMSDK.h"

NS_ASSUME_NONNULL_BEGIN

@interface LIMServerMessageModel : NSObject

@property (nonatomic, copy) NSString *ID;

@property (nonatomic, copy) NSString *fromUid;//发送消息人ID(系统)
@property (nonatomic, copy) NSString *nick;//发送消息人昵称
@property (nonatomic, copy) NSString *icon;//发送消息人头像
@property (nonatomic, copy) NSString *toUid;//接收消息ID(人/群)
@property (nonatomic, assign) long long sendTime;//消息发送时间
@property (nonatomic, copy) NSString *smsgId;//服务端生成的消息ID
@property (nonatomic, assign) IMServerMessage_ServerMsgType smsgType;//系统通知消息类型
@property (nonatomic, copy) NSString *messageBody;//消息内容json

/// 根据系统通知消息，获取数据库存储类型消息
- (IMServerMessage *)getChatMessageFromServerMessageModel;

@end

NS_ASSUME_NONNULL_END
