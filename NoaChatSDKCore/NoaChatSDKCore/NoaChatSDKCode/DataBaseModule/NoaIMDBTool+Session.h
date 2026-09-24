//
//  NoaIMDBTool+Session.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/26.
//

#import "NoaIMDBTool.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (Session)

/// 获取我的 会话列表 数据
- (NSArray <LingIMSessionModel *> *)getMySessionListExcept:(NSString *)sessionId;

/// 获取我的 会话列表中前50条单聊 数据
- (NSArray<LingIMSessionModel *> *)getMySessionListFromSignlChat;

#pragma mark - 获取我的会话列表单聊数据50条，剔除掉 群、群助手、群发助手、系统通知等
- (NSArray<LingIMSessionModel *> *)getMySessionListFromSignlChatWithOffServer;

#pragma mark - 获取我的会话列表数据，剔除掉 群助手、群发助手、系统通知等
- (NSArray<LingIMSessionModel *> *)getMySessionListWithOffServer;

/// 获取我的 置顶会话列表 数据
- (NSArray <LingIMSessionModel *> *)getMyTopSessionListExcept:(NSString *)sessionId;

#pragma mark - 获取我的会话列表置顶会话 分页数据
- (NSArray<LingIMSessionModel *> *)getMyTopSessionListWithOffset:(NSInteger)offset limit:(NSInteger)limit;


/// 根据会话ID查询是否存在该会话
/// @param sessionID 会话ID
- (LingIMSessionModel *)checkMySessionWith:(NSString *)sessionID;

#pragma mark - 根据会话类型查询是否存在该会话
- (LingIMSessionModel *)checkMySessionWithType:(CIMSessionType)sessionType;

/// 更新或新增会话到表
/// @param model 消息内容
- (BOOL)insertOrUpdateSessionModelWith:(LingIMSessionModel *)model;

#pragma mark - 批量-更新或新增会话到表
- (BOOL)insertOrUpdateSessionModelListWith:(NSArray<LingIMSessionModel *> *)list;

/// 获取会话全部未读消息数量
- (NSInteger)getAllSessionUnreadCount;

#pragma mark - 获取会话列表中全部未读会话
- (NSArray<LingIMSessionModel *> *)getAllSessionUnreadList;

/// 获取某个会话的全部未读消息数量
/// @param sessionTableName 会话表名称
- (NSInteger)getOneSessionUnreadCountWith:(NSString *)sessionTableName;

/// 根据聊天消息，获取存储消息的会话表名称
/// @param message 聊天消息
- (NSString *)getSessionTableNameWith:(NoaIMChatMessageModel *)message;

/// 根据聊天消息，获取会话ID
/// @param message 聊天消息
- (NSString *)getSessionIDWith:(NoaIMChatMessageModel *)message;

/// 删除会话model，以及是否清空会话内容
/// @param sessionID 会话ID
/// @param sessionTableName 会话表名称
- (BOOL)deleteSessionModelWith:(NSString *)sessionID sessionTableName:(NSString * _Nullable)sessionTableName;

/// 更新会话列表的全部sessionStatus值
/// @param sessionStatus 要修改的值
- (BOOL)updateAllSessionStatusWith:(NSInteger)sessionStatus;

/// 更新会话列表中某个会话的头像
/// @param sessionId 会话id
/// @param avatar 会话头像
- (BOOL)updateSessionAvatarWithSessionId:(NSString *)sessionId withAvatar:(NSString *)avatar;

/// 删除会话列表里某个状态的全部数据
/// @param sessionStatus 要删除的状态
- (BOOL)deleteAllSessionStatusWith:(NSInteger)sessionStatus;

@end

NS_ASSUME_NONNULL_END
