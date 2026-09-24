//
//  NoaIMSDKManager+Session.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/27.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Session)

/// 新增/更新会话列表
/// @param message 聊天信息model
- (BOOL)toolInsertOrUpdateSessionWith:(NoaIMChatMessageModel *)message isRemind:(BOOL)isRemind;

/// 新增/更新会话列表(如果开启了 关闭群信息 ，则创建群时，只在会话列表里显示新会话，不显示创建群聊的邀请进群的系统消息)
/// @param message 聊天信息model
- (BOOL)toolInsertSessionForCloseGroupRemindWith:(NoaIMChatMessageModel *)message;

/// 更新会话列表，某会话信息
/// @param sessionModel 会话信息model
- (BOOL)toolUpdateSessionWith:(LingIMSessionModel *)sessionModel;

/// 删除我的某个会话
/// @param sessionID 会话ID
/// @param deleteAll 是否同时清空聊天记录
- (BOOL)toolDeleteMySessionWith:(NSString *)sessionID deleteAllChatMessage:(BOOL)deleteAll;

/// 获取我的会话列表数据
- (NSArray *)toolGetMySessionListExcept:(NSString *)sessionId;

/// 获取我的会话列表中前50个单聊的会话信息
- (NSArray *)toolGetMySessionListFromSignlChat;

#pragma mark - 获取我的会话列表单聊数据50条，剔除掉 群、群助手、群发助手、系统通知等
- (NSArray *)toolGetMySessionListFromSignlChatWithOffServer;

#pragma mark - 获取我的会话列表数据，剔除掉 群助手、群发助手、系统通知等
- (NSArray *)toolGetMySessionListWithOffServer;

/// 获取我置顶的会话列表
- (NSArray *)toolGetMyTopSessionListExcept:(NSString *)sessionId;

/// 根据会话ID查询是否存在该会话
/// @param sessionID 会话ID
- (LingIMSessionModel *)toolCheckMySessionWith:(NSString *)sessionID;

/// 根据会话类型查询是否存在该会话
/// @param sessionType 会话类型
- (LingIMSessionModel *)toolCheckMySessionWithType:(CIMSessionType)sessionType;

/// 某个会话消息已读
/// @param model 会话信息
- (BOOL)toolOneSessionAllReadWith:(LingIMSessionModel *)model;

/// 会话消息全部已读
- (void)toolSessionListAllRead;

/// 获取会话全部未读消息数量
- (NSInteger)toolGetAllSessionUnreadCount;

/// 删除会话model，以及是否清空会话内容
/// @param model 会话model
/// @param deleteAll 是否同时删除会话表内容
- (BOOL)toolDeleteSessionModelWith:(LingIMSessionModel *)model andDeleteAllChatModel:(BOOL)deleteAll;

/// 清空我的会话列表信息
- (BOOL)toolDeleteAllMySession;

/// 统一修改我的会话列表sessionStatus的值
- (BOOL)toolUpdateAllMySessionStatusWith:(NSInteger)sessionStatus;

/// 更新会话列表中某个会话的头像
/// @param sessionId 会话id
/// @param avatar 会话头像
- (BOOL)toolUpdateSessionAvatarWithSessionId:(NSString *)sessionId withAvatar:(NSString *)avatar;

/// 统一删除我的会话列表某个sessionStatus状态数据
- (BOOL)toolDeleteAllMySessionStatusWith:(NSInteger)sessionStatus;
@end

NS_ASSUME_NONNULL_END
