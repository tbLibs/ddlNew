//
//  LIMSessionModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

/*
 * dialogType会话类型说明
 * 0单聊消息
 * 1群聊消息
 * 2开放消息
 * 3群发助手
 * 5系统消息(目前叫做 群助手)(针对于serverMessage)
 */

#import <Foundation/Foundation.h>
#import <MJExtension/MJExtension.h>

@class LingIMSessionModel, NoaIMChatMessageModel, LIMMassMessageModel;

NS_ASSUME_NONNULL_BEGIN

@interface LIMSessionModel : NSObject

@property (nonatomic, assign) NSInteger dialogType;//会话类型
@property (nonatomic, copy) NSString *peerUid;//会话ID(用户ID，群主ID)
@property (nonatomic, copy) NSString *userName;//会话名称
@property (nonatomic, copy) NSString *avatar;//会话头像
@property (nonatomic, assign) NSInteger unReadCount;//会话红点书
@property (nonatomic, copy) NSString *lastMsgId;//当前回话最新消息ID(服务端)
@property (nonatomic, assign) long long dialogTime;//最新消息产生的时间
@property (nonatomic, assign) BOOL dnd;//会话免打扰
@property (nonatomic, assign) NSInteger delFlag; //该回话已删除
@property (nonatomic, assign) long long pinnedTime;//会话置顶时间(大于0说明置顶了)
@property (nonatomic, copy) NSString *remarks;//用户备注
@property (nonatomic, assign) NSInteger roleId;//角色Id

@property (nonatomic, strong) NSDictionary *messageDialogHistory;//会话列表接口返回的当前会话的最新消息
@property (nonatomic, strong) NoaIMChatMessageModel *sessionLatestMessage;
//群发助手最新消息，当会话列表dialogType==3的时候，取该字段来展示
@property (nonatomic, strong) LIMMassMessageModel *sessionLatestMassMessage;

- (LingIMSessionModel *)getSessionModel;

@end

NS_ASSUME_NONNULL_END
