//
//  NoaIMDBTool+ChatMessage.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/24.
//

// 聊天消息数据库存储

#import "NoaIMDBTool.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (ChatMessage)

/// 单个插入聊天信息
/// - Parameters:
///   - message: 聊天信息
///   - tableName: 表名
- (BOOL)insertOrUpdateChatMessageWith:(NoaIMChatMessageModel *)message tableName:(NSString *)tableName;

/// 批量插入聊天信息
/// - Parameters:
///   - messageList: 聊天信息列表
///   - tableName: 表名
- (BOOL)insertOrUpdateChatMessagesWith:(NSArray<NoaIMChatMessageModel *> *)messageList tableName:(NSString *)tableName;

/// 获取某个会话的聊天历史消息
/// @param sessionTableName 会话表名称
/// @param limit 返回数据个数
/// @param offset 开始取数据的位置
- (NSArray <NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName limit:(NSInteger)limit offset:(NSInteger)offset;

/// 获取某个会话的聊天历史最新的一条消息
/// /// @param sessionTableName 会话表名称
- (NoaIMChatMessageModel *)getChatMessageHistoryFirstMsgWith:(NSString *)sessionTableName;

/// 获取某类型的聊天历史记录
/// @param sessionTableName 会话表名称
/// @param limit 返回数据个数
/// @param offset 开始取数据的位置
/// @param messageType 消息类型
/// @param likeStr 文本搜索内容
- (NSArray <NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName limit:(NSInteger)limit offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString *)likeStr;

/// 获取某类型的聊天历史记录
/// @param sessionTableName 会话表名称
/// @param limit 返回数据个数
/// @param offset 开始取数据的位置
/// @param messageType 消息类型
/// @param likeStr 文本搜索内容
/// @param userIdList 发送者uid数组
- (NSArray <NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName limit:(NSInteger)limit offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString *)likeStr userIdList:(NSArray *)userIdList;

/// 获取某个时间范围内容的聊天历史记录
/// @param sessionTableName 会话表名称
/// @param startTime 开始时间
/// @param endTime 结束时间
- (NSArray<NoaIMChatMessageModel *> *)getChatMessageHistoryWith:(NSString *)sessionTableName startTime:(long long)startTime endTime:(long long)endTime;

/// 按中心消息ID，获取前后各N条图片/视频消息（不包含中心消息）
/// @param sessionTableName 会话表名称
/// @param centerMsgId 中心消息msgID
/// @param beforeCount 向前（更老）获取的条数
/// @param afterCount 向后（更新）获取的条数
- (NSArray<NoaIMChatMessageModel *> *)getImageVideoAroundWith:(NSString *)sessionTableName centerMsgId:(NSString *)centerMsgId before:(NSInteger)beforeCount after:(NSInteger)afterCount;

/// 删除 某消息
/// @param message 消息内容
/// @param tableName 表名称
- (BOOL)deleteChatMessageWith:(NoaIMChatMessageModel *)message tableName:(NSString *)tableName;

/// 撤回 某消息
/// @param message 消息内容
/// @param tableName 表名称
- (BOOL)backDeleteChatMessageWith:(NoaIMChatMessageModel *)message tableName:(NSString *)tableName;

/// 清空某个会话的全部聊天数据
/// @param tableName 表名称
- (BOOL)deleteAllChatMessageWith:(NSString *)tableName;

/// 根据某个消息ID获取消息
/// @param msgID 消息ID
/// @param tableName 会话表名称
- (NoaIMChatMessageModel *)getOneChatMessageWithMessageID:(NSString *)msgID withTableName:(NSString *)tableName;

/// 根据某个服务端消息ID获取消息
/// @param smsgID 服务端消息ID
/// @param tableName 会话表名称
- (NoaIMChatMessageModel *)getOneChatMessageWithServiceMessageID:(NSString *)smsgID withTableName:(NSString *)tableName;

/// 根据某个服务端消息ID获取消息（排除删除和撤回的消息）
/// @param smsgID 服务端消息ID
/// @param tableName 会话表名称
- (NoaIMChatMessageModel *)getOneChatMessageWithServiceMessageIDExcludeDeleted:(NSString *)smsgID withTableName:(NSString *)tableName;

/// 获取某个会话的最新消息
/// @param tableName 会话表名称
- (NoaIMChatMessageModel *)getLatestChatMessageWithTableName:(NSString *)tableName;

/// 全部已读某个会话表的消息
/// @param tableName 会话表名称
- (BOOL)messageHaveReadAllWith:(NSString *)tableName;

/// 根据搜索内容查询聊天记录
/// @param searchStr 搜索内容
- (NSArray<NoaIMChatMessageModel *> *)searchChatMessageWith:(NSString *)searchStr;

/// 删除某个时间戳之前的所有消息(eg:timeValue为2023年1月1日10:01，则类似2023年1月1日10:00这样的消息都被删除)
/// @param timeValue 时间戳(毫秒)
/// @param tableName 会话表名称
- (BOOL)messageDeleteBeforTime:(long long)timeValue withTableName:(NSString *)tableName;

/// 删除群里某个群成员在本群发过的所有本地缓存的消息
/// @param tableName 表名称
/// @param memberId 群成员ID
- (BOOL)deleteGroupMemberAllSendChatMessageWith:(NSString *)tableName withMemberId:(NSString *)memberId;


@end

NS_ASSUME_NONNULL_END
