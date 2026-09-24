//
//  NoaIMSDKManager+ChatMessage.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

// 聊天类型消息 处理

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (ChatMessage)

/// 发送聊天消息
/// @param message 聊天消息
- (void)toolSendChatMessageWith:(NoaIMChatMessageModel *)message;

/// 处理接收到的聊天消息
/// @param message 聊天消息
- (void)toolDealReceiveChatMessage:(IMMessage *)message;

/// 获取会话聊天历史记录
/// @param sessionID 会话对方ID(好友ID/群聊ID)
/// @param offset 开始取数据的位置
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID offset:(NSInteger)offset;

/// 获取会话聊天历史记录
/// @param sessionID 会话对方ID(好友ID/群聊ID)
/// @param limit 条数
/// @param offset 开始取数据的位置
- (NSArray *)toolReConnectGetChatMessageHistoryWith:(NSString *)sessionID limit:(NSInteger)limit offset:(NSInteger)offset;

/// 获取签到助手历史记录
/// @param sessionID 会话对方ID(100003)
/// @param offset 开始取数据的位置
- (NSArray *)toolGetSignInHistoryWith:(NSString *)sessionID offset:(NSInteger)offset;

/// 获取某类型的聊天历史记录
/// @param sessionID 会话ID
/// @param offset 开始读取数据的位置
/// @param messageType 消息类型
/// @param likeStr 文本搜索内容(需要过滤特殊字符)
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString * _Nullable)likeStr;

/// 获取指定用户发送的、某类型的聊天历史记录
/// @param sessionID 会话ID
/// @param offset 开始读取数据的位置
/// @param messageType 消息类型
/// @param likeStr 文本搜索内容(需要过滤特殊字符)
/// @param userIdList 发送者的uid
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID offset:(NSInteger)offset messageType:(NSArray *)messageType textMessageLike:(NSString * _Nullable)likeStr userIdList:(NSArray *)userIdList;

/// 获取某个时间范围内容的聊天历史记录
/// @param sessionID 会话ID
/// @param startTime 开始时间
/// @param endTime 结束时间(不包含结束时间消息)
- (NSArray *)toolGetChatMessageHistoryWith:(NSString *)sessionID startTime:(long long)startTime endTime:(long long)endTime;

/// 按中心消息ID取前后各N条图片/视频（总计不超过 before+after+1）
/// @param sessionID 会话ID
/// @param centerMsgId 中心消息msgID
/// @param beforeCount 前（更老）N条
/// @param afterCount 后（更新）N条
- (NSArray *)toolGetImageVideoAroundWith:(NSString *)sessionID centerMsgId:(NSString *)centerMsgId before:(NSInteger)beforeCount after:(NSInteger)afterCount;

/// 更新 或 新增 消息到 消息表
/// @param message 消息内容
- (BOOL)toolInsertOrUpdateChatMessageWith:(NoaIMChatMessageModel *)message;

/// 批量更新 或 新增 消息到 消息表
/// @param messageList 消息列表
- (void)toolInsertOrUpdateChatMessagesWith:(NSArray <NoaIMChatMessageModel *>*)messageList;

/// 删除数据库某消息
/// @param message 消息内容
- (BOOL)toolDeleteChatMessageWith:(NoaIMChatMessageModel *)message;

/// 撤回数据库某消息
/// @param message 消息内容
- (BOOL)toolBackDeleteChatMessageWith:(NoaIMChatMessageModel *)message;

/// 根据会话ID删除全部聊天数据
/// @param sessionID 会话ID
- (BOOL)toolDeleteAllChatMessageWith:(NSString *)sessionID;

/// 删除某个群的群成员在本群发的所有消息
/// @param memberID 群成员uid
/// @param groupID 群ID(会话ID)
- (BOOL)toolDeleteGroupMemberAllSendMessageWith:(NSString *)memberID groupID:(nonnull NSString *)groupID;


/// 根据某个消息ID获取消息
/// @param msgID 消息ID
/// @param sessionID 会话对方ID(好友ID/群聊ID)
- (NoaIMChatMessageModel *)toolGetOneChatMessageWithMessageID:(NSString *)msgID sessionID:(NSString *)sessionID;

/// 根据某个服务端消息ID获取消息
/// @param smsgID 服务端消息ID
/// @param sessionID 会话对方ID(好友ID/群聊ID)
- (NoaIMChatMessageModel *)toolGetOneChatMessageWithServiceMessageID:(NSString *)smsgID sessionID:(NSString *)sessionID;

/// 获取某个会话的最新消息
/// @param sessionID 会话对方ID(好友ID/群聊ID)
- (NoaIMChatMessageModel *)toolGetLatestChatMessageWithSessionID:(NSString *)sessionID;
/// 根据某个服务端消息ID获取消息（排除删除和撤回的消息）
/// @param smsgID 服务端消息ID
/// @param sessionID 会话对方ID(好友ID/群聊ID)
- (NoaIMChatMessageModel *)toolGetOneChatMessageWithServiceMessageIDExcludeDeleted:(NSString *)smsgID sessionID:(NSString *)sessionID;

/// 消息已读
/// @param message 已读消息
- (BOOL)toolMessageHaveReadWith:(NoaIMChatMessageModel *)message;

/// 消息全部已读
/// @param sessionID 会话ID
- (BOOL)toolMessageHaveReadAllWith:(NSString *)sessionID;

/// 删除某会话的某个时间之前的全部消息
/// @param timeValue 时间戳(单位:毫秒)
/// @param sessionID 会话ID
- (BOOL)toolMessageDeleteBeforTime:(long long)timeValue withSessionID:(NSString *)sessionID;

/// 发送MMKV里未发送成功的消息
- (void)toolMMKVSendChatMessage;

#pragma mark - 根据搜索内容查询历史消息
- (NSArray <NoaIMChatMessageModel *> *)toolSearchMessageWith:(NSString *)searchStr;


/** NetWork */

/// 获取在服务器保存的会话列表
/// @param params 操作参数{ pageNumber:分页(1开始) pageSize:每页大小 pageStart:起始索引(0开始) userUid:操作用户 }
- (void)getConversationsFromServer:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除服务器端某个会话
/// @param params 操作参数{ peerUid:会话ID(用户/群组) userUid:操作用户 dialogType:0单聊1群聊 }
- (void)deleteServerConversation:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 指定会话的已读回执
/// @param params 操作参数{ peerUid:会话ID(用户/群组) userUid:操作用户 dialogType:0单聊1群聊 }
- (void)ackConversationRead:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 会话-群聊 消息免打扰
/// @param params 操作参数{groupId:群组ID,userUid:操作用户ID,status:会话免打扰状态(1:打开,0:关闭 默认0)}
- (void)groupConversationPromt:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 会话-群聊 置顶
/// @param params 操作参数{groupId:群组ID,userUid:操作用户ID,status:会话置顶状态(1:置顶,0:取消置顶 默认0)}
- (void)groupConversationTop:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 会话-单聊 消息免打扰
/// @param params 操作参数{friendUserUid:好友用户ID,userUid:操作用户ID,status:会话免打扰状态(1:打开,0:关闭 默认0)}
- (void)singleConversationPromt:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 会话-单聊 置顶
/// @param params 操作参数{friendUserUid:好友用户ID,userUid:操作用户ID,status:会话置顶状态(1:置顶,0:取消置顶 默认0)}
- (void)singleConversationTop:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 会话- 标记未读/标记已读
/// @param params 操作参数{peerUid:会话方用户ID/群组ID,userUid:操作用户ID,dialogType:会话类型(单聊为0/群聊为1), readTag: 会话读状态： 0:正常; 1:标记未读}
- (void)conversationReadedStatus:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 清空单聊/群聊的聊天记录
/// @param params 操作参数{chatType:聊天类型0单聊1群聊,userUid:操作用用户ID,receiveId:(好友ID/群ID)}
- (void)clearChatMessageHistory:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
    
/// 查询 单聊 消息记录
/// @param params 请求参数{fromUid:发送者用户ID(可选参数,相当好友用户ID),uid:查询者用户ID,sMsgId:服务端消息ID(如查询某条消息后多少条消息,则传该值。如查询最新消息,则不用传该值),pageSize:查询消息条数,pageNumber:当前页(1开始),isThanMsgId:是否查询小于传入的消息ID的消息记录 1:是 2:否、默认：否,endSMsgId:查询结束的消息ID(如果isThanMsgId传值为是该值则需要小于sMsgId，反之则需要大于sMsgId)}
- (void)querySingleMsgRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询 群聊 消息记录
/// @param params 请求参数{groupId:群组ID,uid:用户ID,sMsgId:服务端消息ID(如查询某条消息后多少条消息,则传该值。如查询最新消息,则不用传该值),pageSize:查询消息条数,pageNumber:当前页(1开始),isThanMsgId:是否查询小于传入的消息ID的消息记录 1:是 2:否、默认：否,endSMsgId:查询结束的消息ID(如果isThanMsgId传值为是该值则需要小于sMsgId，反之则需要大于sMsgId),uid:群成员用户ID(可选参数，该值如果传值将只查询该用户加入到群聊以后的消息,该值如果需要生效不能传endSMsgId值)}
- (void)queryGroupMsgRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询 通知 离线消息记录
/// @param params 请求参数 {uid:查询者用户ID,pageNumber:分页1,pageSize:查询消息条数,pageStart:起始索引0}
- (void)queryOfflineMsgRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 消息转发
/// @param  messageData 转发消息相关数据(Protobuf)
- (void)transpondMessage:(NSData *)messageData onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 消息转发-校验接受者
/// @param params 操作参数 待校验接受者id数组的json字符串
- (void)transpondComplianceMessage:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;


/// 消息删除(单向/双向)
/// @param params 操作参数{ chatType:聊天类型(1:群聊 0：单聊)，msgId:消息ID(前端消息ID)，operationStatus:1单向删除,2双向删除，receiveId:会话id(sessionId)，sMsgId:消息ID(服务消息ID)，userUid:用户ID不可为空 }
- (void)deleteMessage:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 消息撤回
/// @param params 操作参数{ chatType:聊天类型(1:群聊 0：单聊)，userUid:操作用户ID，operateNick:操作用户昵称，receiveId:接收方ID(群聊ID/好友ID)，sMsgId:服务端消息ID，status :消息的状态：1-正常，2-撤回，3-删除，uid:用户ID(消息发送者) }
- (void)recallMessage:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 发送消息已读
/// @param params 操作参数{userUid:操作用户ID,chatType:聊天类型(0单聊,1群聊),smsgId:服务端消息ID,sendMsgUserUid:消息发送方ID,groupId:群聊ID}
- (void)readedMessage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取多个群聊会话的最新消息
/// @param params 操作参数{limit:返回消息个数,peerUidList:[会话ID],userUid:操作用户ID}
- (void)messageGetLatestForGroupSessionsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取多个单聊会话的最新消息
/// @param params 操作参数{limit:返回消息个数,peerUidList:[会话ID],userUid:操作用户ID}
- (void)messageGetLatestForSingleSessionsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取聊天消息历史记录
/// @param sessionID 会话ID
/// @param chatType 会话类型
/// @param serviceMsgID 服务端消息ID；上拉更旧时作为游标（配合 isThanMsgId=1）。为空则先本地后同步最新一页
/// @param offset 本地 DB 偏移量
/// @param pageNum 兼容旧分页计数（游标模式下服务端固定 pageNumber=1）
- (void)messageGetHistoryRecordWith:(NSString *)sessionID chatType:(CIMChatType)chatType serviceMsgID:(NSString * _Nullable)serviceMsgID offset:(NSInteger)offset pageNum:(NSInteger)pageNum historyList:(LingIMChatMessageHistoryBlock)block;

/// 获取重连聊天消息历史记录（按游标补「更新」缺口）
/// @param sessionID 会话ID
/// @param chatType 会话类型
/// @param messageId 本地最新消息的 serviceMsgID（优先），用于 isThanMsgId=2 拉更新消息
/// @param lastMessageId 本地最旧消息的 serviceMsgID（可选，兼容旧调用）
/// @param offset 偏移量(获取偏移量之后的数据)
- (void)messageReConnectGetHistoryRecordWith:(NSString *)sessionID chatType:(CIMChatType)chatType lastMessageId:(NSString *)lastMessageId messageId:(NSString *)messageId offset:(NSInteger)offset historyList:(LingIMReConnectMessageHistoryBlock)block;

/// 获取签到助手历史记录
/// @param sessionID 会话ID- 100003
/// @param offset 偏移量(获取偏移量之后的数据)
- (NSArray *)messageGetSignInHistoryRecordWith:(NSString *)sessionID offset:(NSInteger)offset;

/// 推荐好友名片
/* @param params 操作参数
 {
 "friendUserId": "",  #名片用户ID
 "receiveUsers": [
         {
                 "chatType": "SINGLE_CHAT", #推荐类型（好友或群）
                 "friendIdOrGroupId": ""
           },
         {
                 "chatType": "GROUP_CHAT",
                 "friendIdOrGroupId": "3396"
         }
 ],
 "userUid": "" #操作用户
}
*/
- (void)MessageUserCardRecommend:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 查询 定时删除消息 功能的 设置信息
/// @param params 操作参数 {dialogType:会话类型0单聊1群聊, peerUid:会话ID(好友ID或群组ID), userUid:操作用户ID}
- (void)MessageTimeDeleteInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 设置 定时删除消息 功能
/// @param params 操作参数 {dialogType:会话类型0单聊1群聊, peerUid:会话ID(好友ID或群组ID), freq:频率0关闭 1 7 30(天), userUid:操作用户ID}
- (void)MessageTimeDeleteSetWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 添加消息到 "我的收藏"
/// @param params 操作参数 {msgId:消息ID, userUid:操作用户ID}
- (void)MessageCollectionSave:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 群发助手-创建消息转发组
/// @param params 操作参数 {label:标签名字 userUidList:接收消息用户数组 userUid:操作用户ID}
- (void)GroupHairCreateHairGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群发助手-发送群发消息
/// @param params 操作参数 {labelId:群发组ID body:消息体(参考protobuf Json格式字符串)(只支持文本、图片、视频、文件) mtype:消息类型(0文本1图片2视频5文件) userUid:操作用户ID}
- (void)GroupHairSendHairMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群发助手-获取群发消息列表
/// @param params 操作参数 {pageNumber:起始页(从1开始) pageSize:每页数据大小 pageStart:起始索引(从0开始) userUid:操作用户ID}
- (void)GroupHairGetMessageListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群发助手-删除群发消息
/// @param params 操作参数 {taskId:任务ID userUid:操作用户ID}
- (void)GroupHairDeleteHairMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群发助手-查询群发消息的成员列表
/// @param params 操作参数 {labelId:群发组ID pageNumber:起始页(从1开始) pageSize:每页数据大小 pageStart:起始索引(从0开始) taskId:群发任务Id userUid:操作用户ID}
- (void)GroupHairGetGroupHairUserListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 群发助手-查询群发消息的发送失败成员列表
/// @param params 操作参数 {labelId:群发组ID pageNumber:起始页(从1开始) pageSize:每页数据大小 pageStart:起始索引(从0开始) taskId:群发任务Id userUid:操作用户ID}
- (void)GroupHairGetGroupHairErrorUserListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 聊天标签-获取标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagType:标签类型：1单聊 2群聊 userUId:操作用户ID}
- (void)MessageChatTagListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 聊天标签-新增标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagIcon:标签图标(传空字符串) tagId:标签id(传0) tagName:标签名称 tagType:标签类型：1单聊 2群聊 tagUrl:链接地址 userUId:操作用户ID}
- (void)MessageChatTagAddWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 聊天标签-更新标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagIcon:标签图标(传空字符串) tagId:标签id tagName:标签名称 tagType:标签类型：1单聊 2群聊 tagUrl:链接地址 userUId:操作用户ID}
- (void)MessageChatTagUpdateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 聊天标签-移除标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagId:标签id tagType:标签类型：1单聊 2群聊 userUId:操作用户ID}
- (void)MessageChatTagRemoveWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 全部已读上报
/// @param params 操作参数 {userUId:操作用户ID}
- (void)MessageReadAllMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


/// 长链接失败后发送消息
/// @param params params
/// @param onSuccess success
/// @param onFailure failure
- (void)MessagePushMsg:(NSData * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询群置顶消息列表
/// @param params 操作参数 {groupId:群组ID, userUid:操作用户ID, pageNumber:起始页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始)}
- (void)MessageQueryGroupTopMsgListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询群消息是否可以置顶
/// @param params 操作参数 {groupId:群组ID, smsgId:服务端消息ID, userUid:操作用户ID}
- (void)MessageQueryGroupMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询群置顶消息悬浮列表
/// @param params 操作参数 {groupId:群组ID, userUid:操作用户ID}
- (void)MessageQueryGroupTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询个人消息是否可以置顶
/// @param params 操作参数 {userUid:操作用户ID, friendUid:好友ID, smsgId:服务端消息ID}
- (void)MessageQueryUserMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 设置/取消 消息置顶
/// @param params 操作参数 {userUid:操作用户ID, friendUid:好友ID, smsgId:服务端消息ID, msgStatus:消息状态(1 全局置顶，2用户个人置顶，3取消全局置顶，4取消个人置顶)}
- (void)MessageSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询个人置顶消息列表
/// @param params 操作参数 {userUid:操作用户ID, type:为0时，查询悬浮的10条记录；1，查询全部的个人当前会话的所有置顶消息列表, friendUid:好友ID}
- (void)MessageQueryUserTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 编辑已发送消息。
/// @param messageData 包含原消息 ID、消息类型和新正文的 Protobuf 数据。
- (void)editMessage:(NSData *)messageData onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
