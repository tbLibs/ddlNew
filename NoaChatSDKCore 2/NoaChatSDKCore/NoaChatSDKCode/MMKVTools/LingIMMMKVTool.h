//
//  LingIMMMKVTool.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/3.
//

#define MMKVTOOL [LingIMMMKVTool sharedTool]

#import <Foundation/Foundation.h>

//SDK
#import "NoaIMSDK.h"//sdk头文件

NS_ASSUME_NONNULL_BEGIN

@interface LingIMMMKVTool : NSObject

#pragma mark - 单例
+ (instancetype)sharedTool;
//单例一般不需要清空，但是在执行某些功能的时候，防止数据更换不及时，可以清空一下
- (void)clearTool;

#pragma mark - ******业务******

/// 工具配置参数设置
/// @param userID 用户ID
/// @param userToken 用户token
- (void)configMMKVToolWith:(NSString *)userID token:(NSString *)userToken;

/// 发送的消息存储到MMKV
/// @param chatMessage 发送消息
- (BOOL)addSendChatMessageWith:(IMChatMessage *)chatMessage;

/// 根据消息ID获取发送的消息
/// @param msgID 消息ID
- (IMChatMessage *)getSendChatMessageWith:(NSString *)msgID;

/// 根据消息ID删除发送的消息
/// @param msgID 消息ID
- (void)deleteSendChatMessageWith:(NSString *)msgID;

/// 获取全部发送的消息(如果有则重新发送这些消息)
- (NSArray <IMChatMessage *> *)getAllSendChatMessage;

/// 清空所有发送的消息
- (void)clearAllSendChatMessage;

/// 根据消息ID获取回话表名称
/// @param msgID 消息ID
- (NSString *)getSessionIDWith:(NSString *)msgID;

@end

NS_ASSUME_NONNULL_END
