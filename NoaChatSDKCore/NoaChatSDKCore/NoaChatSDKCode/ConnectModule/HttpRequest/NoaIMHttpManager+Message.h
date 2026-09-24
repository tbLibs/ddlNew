//
//  NoaIMHttpManager+Message.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/20.
//

//获取会话列表
#define Get_Conversations_Url               @"/biz/dialogs/getDialogsPaged"
//删除某会话
#define Delete_ServerConversation_Url       @"/biz/dialogs/delDialog"
//某会话已读
#define Ack_Conversation_Read_Url           @"/biz/dialogs/settingReaded"
//会话-群聊 消息免打扰
#define Group_Conversation_Promt_Url        @"/biz/message/groupChatNoPromt"
//会话-群聊 置顶
#define Group_Conversation_Top_Url          @"/biz/message/groupMsgTop"
//会话-单聊 消息免打扰
#define Single_Conversation_Promt_Url       @"/biz/message/singleMessagePromt"
//会话-单聊 置顶
#define Single_Conversation_Top_Url         @"/biz/message/singleMessageTop"
//会话-标记未读 / 标记已读
#define Conversation_Readed_Url             @"/biz/dialogs/setReadTag"
//清空单聊/群聊的聊天记录
#define Clear_Single_MsgRecord_Url          @"/biz/message/clearMessage"
//查询 单聊 消息记录
#define Query_Single_MsgRecord_Url          @"/biz/message/findSingleMessage"
//查询 群聊 消息记录
#define Query_Group_MsgRecord_Url           @"/biz/message/findGroupMessage"
//查询 通知 离线消息记录
#define Query_OffLine_MsgRecord_Url         @"/biz/message/findServerOffLineMessage"
//消息转发
#define Forward_Message_Url                 @"/biz/message/messageForwarding"
//消息转发检查接受者是否合规
#define Forward_Compliance_Message_Url      @"/biz/message/messageForwardPrecheck"
//消息删除(单向/双向)
#define Delete_Message_Url                  @"/biz/message/deleteMsg"
//消息撤回
#define ReCall_Message_Url                  @"/biz/message/messageRecall"
//消息已读上报
#define Readed_Message_Url                  @"/biz/message/readMessage"
//获取多个群聊会话的最新消息
#define Message_LatestGroupMessages_Url     @"/biz/message/latestGroupMessages"
//获取多个单聊会话的最新消息
#define Message_LatestSingleMessages_Url    @"/biz/message/latestSingleMessages"
//推荐好友名片
#define Recomment_Friend_Card_Url           @"/biz/friend/recommentFriend"
//查询 定时删除消息 设置信息
#define Message_Time_Delete_Info_Url        @"/biz/schedule/query"
//设置 定时删除消息 功能
#define Message_Time_Delete_Set_Url         @"/biz/schedule/setDeletion"
//添加到 我的收藏
#define Message_Save_MyCollection_Url        @"/biz/collect/save"

//群发助手-配置群发标签和用户后获取群发组id
#define Group_Hair_Create_Hair_Group_Url        @"/biz/groupHair/createHairGroup"
//群发助手-发送群发消息
#define Group_Hair_Send_Hair_Message_Url        @"/biz/groupHair/sendHairMessage"
//群发助手-查询群发助手消息列表
#define Group_Hair_Get_Message_List_Url         @"/biz/groupHair/getMessageList"
//群发助手-删除群发消息
#define Group_Hair_Delete_Hair_Message_Url      @"/biz/groupHair/deleteHairMessage"
//群发助手-查询转发组成员列表
#define Group_Hair_Get_Group_Hair_User_List_Url @"/biz/groupHair/getGroupHairUserList"
//群发助手-查询转发消息失败的成员列表
#define Group_Hair_Get_Group_Hair_Error_User_List_Url       @"/biz/groupHair/getGroupHairErrorUserList"
//全部已读上报接口
#define Message_Read_All_Message       @"/biz/message/readAllMessage"

/** 聊天界面-标签管理 */
//获取标签链接信息
#define Message_Chat_Tag_List_Url               @"/biz/tag/list"
//新增标签链接信息
#define Message_Add_Chat_Tag_Url                @"/biz/tag/add"
//更新标签链接信息
#define Message_Update_Chat_Tag_Url             @"/biz/tag/update"
//移除标签链接信息
#define Message_Remove_Chat_Tag_Url             @"/biz/tag/remove"
//长链接失败后消息发送接口
#define Message_Push_Msg_Url                    @"/biz/message/pushMsg"
//查询群置顶消息列表
#define Message_Query_Group_Top_Msg_Url             @"/biz/message/queryGroupTopMsgList"
//查询群消息是否可以置顶
#define Message_Query_Group_Msg_Status_Url             @"/biz/message/queryGroupMsgStatus"
//查询群置顶消息悬浮列表
#define Message_Query_Group_Top_Msgs_Url             @"/biz/message/queryGroupTopMsgs"
//编辑已发送消息
#define Message_Edit_One_Msg_Url                      @"/biz/message/editedOneMsg"

//查询个人置顶消息列表
#define Dialogs_Query_User_Top_Msgs_Url             @"/biz/dialogs/queryUserTopMsgs"
//查询群消息是否可以置顶
#define Dialogs_Query_User_Msg_Status_Url             @"/biz/dialogs/queryUserMsgStatus"
//查询群置顶消息悬浮列表
#define Dialogs_Set_Msg_Top_Url             @"/biz/dialogs/setMsgTop"
#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (Message)

/// 获取在服务器保存的会话列表
/// @param params 操作参数{ pageNumber:分页(1开始) pageSize:每页大小 pageStart:起始索引(0开始) userUid:操作用户 }
- (void)MessageGetConversationsFromServer:(NSMutableDictionary * _Nullable)params
                         onSuccess:(LingIMSuccessCallback)onSuccess
                         onFailure:(LingIMFailureCallback)onFailure;

/// 删除服务器端某个会话
/// @param params 操作参数{ peerUid:会话ID(用户/群组) userUid:操作用户 dialogType:0单聊1群聊 }
- (void)MessageDeleteServerConversation:(NSMutableDictionary * _Nullable)params
                       onSuccess:(LingIMSuccessCallback)onSuccess
                       onFailure:(LingIMFailureCallback)onFailure;

/// 指定会话的已读回执
/// @param params 操作参数{ peerUid:会话ID(用户/群组) userUid:操作用户 dialogType:0单聊1群聊 }
- (void)MessageAckConversationRead:(NSMutableDictionary * _Nullable)params
                  onSuccess:(LingIMSuccessCallback)onSuccess
                  onFailure:(LingIMFailureCallback)onFailure;

/// 会话-群聊 消息免打扰
/// @param params 操作参数{groupId:群组ID,userUid:操作用户ID,status:会话免打扰状态(1:打开,0:关闭 默认0)}
- (void)MessageGroupConversationPromt:(NSMutableDictionary * _Nullable)params
                onSuccess:(LingIMSuccessCallback)onSuccess
                onFailure:(LingIMFailureCallback)onFailure;

/// 会话-群聊 置顶
/// @param params 操作参数{groupId:群组ID,userUid:操作用户ID,status:会话置顶状态(1:置顶,0:取消置顶 默认0)}
- (void)MessageGroupConversationTop:(NSMutableDictionary * _Nullable)params
              onSuccess:(LingIMSuccessCallback)onSuccess
              onFailure:(LingIMFailureCallback)onFailure;

/// 会话- 标记未读/标记已读
/// @param params 操作参数{peerUid:会话方用户ID/群组ID,userUid:操作用户ID,dialogType:会话类型(单聊为0/群聊为1), readTag: 会话读状态： 0:正常; 1:标记未读}
- (void)MessageConversationReadedStatus:(NSMutableDictionary * _Nullable)params
                              onSuccess:(LingIMSuccessCallback)onSuccess
                              onFailure:(LingIMFailureCallback)onFailure;

/// 会话-单聊 消息免打扰
/// @param params 操作参数{friendUserUid:好友用户ID,userUid:操作用户ID,status:会话免打扰状态(1:打开,0:关闭 默认0)}
- (void)MessageSingleConversationPromt:(NSMutableDictionary * _Nullable)params
                 onSuccess:(LingIMSuccessCallback)onSuccess
                 onFailure:(LingIMFailureCallback)onFailure;

/// 会话-单聊 置顶
/// @param params 操作参数{friendUserUid:好友用户ID,userUid:操作用户ID,status:会话置顶状态(1:置顶,0:取消置顶 默认0)}
- (void)MessageSingleConversationTop:(NSMutableDictionary * _Nullable)params
               onSuccess:(LingIMSuccessCallback)onSuccess
               onFailure:(LingIMFailureCallback)onFailure;

/// 清空单聊/群聊的聊天记录
/// @param params 操作参数{chatType:聊天类型0单聊1群聊,userUid:操作用用户ID,receiveId:(好友ID/群ID)}
- (void)MessageClearChatMessageHistory:(NSMutableDictionary * _Nullable)params
                 onSuccess:(LingIMSuccessCallback)onSuccess
                 onFailure:(LingIMFailureCallback)onFailure;
    
/// 查询 单聊 消息记录
/// @param params 请求参数{fromUid:发送者用户ID(可选参数,相当好友用户ID),uid:查询者用户ID,sMsgId:服务端消息ID(如查询某条消息后多少条消息,则传该值。如查询最新消息,则不用传该值),pageSize:查询消息条数,pageNumber:当前页,isThanMsgId:是否查询小于传入的消息ID的消息记录 1:是 2:否、默认：否,endSMsgId:查询结束的消息ID(如果isThanMsgId传值为是该值则需要小于sMsgId，反之则需要大于sMsgId)}
- (void)MessageQuerySingleMsgRecord:(NSMutableDictionary * _Nullable)params
                   onSuccess:(LingIMSuccessCallback)onSuccess
                   onFailure:(LingIMFailureCallback)onFailure;

/// 查询 群聊 消息记录
/// @param params 请求参数{groupId:群组ID,uid:用户ID,sMsgId:服务端消息ID(如查询某条消息后多少条消息,则传该值。如查询最新消息,则不用传该值),pageSize:查询消息条数,pageNumber:当前页,isThanMsgId:是否查询小于传入的消息ID的消息记录 1:是 2:否、默认：否,endSMsgId:查询结束的消息ID(如果isThanMsgId传值为是该值则需要小于sMsgId，反之则需要大于sMsgId),uid:群成员用户ID(可选参数，该值如果传值将只查询该用户加入到群聊以后的消息,该值如果需要生效不能传endSMsgId值)}
- (void)MessageQueryGroupMsgRecord:(NSMutableDictionary * _Nullable)params
                  onSuccess:(LingIMSuccessCallback)onSuccess
                  onFailure:(LingIMFailureCallback)onFailure;

/// 查询 通知 离线消息记录
/// @param params 请求参数 {uid:查询者用户ID,pageNumber:分页1,pageSize:查询消息条数,pageStart:起始索引0}
- (void)MessageQueryOfflineMsgRecord:(NSMutableDictionary * _Nullable)params
                    onSuccess:(LingIMSuccessCallback)onSuccess
                    onFailure:(LingIMFailureCallback)onFailure;

/// 消息转发
/// @param  messageData 转发消息相关数据(Protobuf)
- (void)MessageTranspondMessage:(NSData *)messageData
               onSuccess:(nullable LingIMSuccessCallback)onSuccess
               onFailure:(nullable LingIMFailureCallback)onFailure;

/// 消息转发时检查接受者是否可进行转发
/// @param  params 接受者id数组json字符串
- (void)MessageTranspondComplianceMessage:(NSMutableDictionary * _Nullable)params
               onSuccess:(nullable LingIMSuccessCallback)onSuccess
               onFailure:(nullable LingIMFailureCallback)onFailure;


/// 消息删除(单向/双向)
/// @param params 操作参数{ chatType:聊天类型(1:群聊 0：单聊)，msgId:消息ID(前端消息ID)，operationStatus:1单向删除,2双向删除，receiveId:会话id(sessionId)，sMsgId:消息ID(服务消息ID)，userUid:用户ID不可为空 }
- (void)MessageDeleteMessage:(NSMutableDictionary * _Nullable)params
            onSuccess:(nullable LingIMSuccessCallback)onSuccess
            onFailure:(nullable LingIMFailureCallback)onFailure;

/// 消息撤回
/// @param params 操作参数{ chatType:聊天类型(1:群聊 0：单聊)，userUid:操作用户ID，operateNick:操作用户昵称，receiveId:接收方ID(群聊ID/好友ID)，sMsgId:服务端消息ID，status :消息的状态：1-正常，2-撤回，3-删除，uid:用户ID(消息发送者) }
- (void)MessageRecallMessage:(NSMutableDictionary * _Nullable)params
            onSuccess:(nullable LingIMSuccessCallback)onSuccess
            onFailure:(nullable LingIMFailureCallback)onFailure;

/// 发送消息已读
/// @param params 操作参数{userUid:操作用户ID,chatType:聊天类型(0单聊,1群聊),smsgId:服务端消息ID,sendMsgUserUid:消息发送方ID,groupId:群聊ID}
- (void)MessageReadedMessage:(NSMutableDictionary * _Nullable)params
            onSuccess:(LingIMSuccessCallback)onSuccess
            onFailure:(LingIMFailureCallback)onFailure;

/// 获取多个群聊会话的最新消息
/// @param params 操作参数 {limit:返回消息个数,peerUidList:[会话ID],userUid:操作用户ID}
- (void)MessageGetGroupSessionsLatestMessages:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取多个单聊会话的最新消息
/// @param params 操作参数 {limit:返回消息个数,peerUidList:[会话ID],userUid:操作用户ID}
- (void)MessageGetSingleSessionsLatestMessages:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 推荐好友名片
/* @param params 操作参数 {
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
- (void)MessageRecommentFriendCard:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;


/// 查询 定时删除消息 功能的 设置信息
/// @param params 操作参数 {dialogType:会话类型0单聊1群聊, peerUid:会话ID(好友ID或群组ID), userUid:操作用户ID}
- (void)MessageTimeDeleteInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 设置 定时删除消息 功能
/// @param params 操作参数 {dialogType:会话类型0单聊1群聊, peerUid:会话ID(好友ID或群组ID), freq:频率0关闭 1 7 30(天), userUid:操作用户ID}
- (void)MessageTimeDeleteSetWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 添加消息到 "我的收藏"
/// @param params 操作参数 {msgId:消息ID, userUid:操作用户ID}
- (void)MessageSaveCollectionWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

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

/// 获取标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagType:标签类型：1单聊 2群聊 userUId:操作用户ID}
- (void)MessageGetChatTagListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 新增标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagIcon:标签图标(传空字符串) tagId:标签id(传0) tagName:标签名称 tagType:标签类型：1单聊 2群聊     tagUrl:链接地址 userUId:操作用户ID}
- (void)MessageAddChatTagWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 更新标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagIcon:标签图标(传空字符串) tagId:标签id tagName:标签名称 tagType:标签类型：1单聊 2群聊 tagUrl:链接地址 userUId:操作用户ID}
- (void)MessageUpdateChatTagWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 移除标签链接信息
/// @param params 操作参数 {dialog:会话好友id，或者群组id tagId:标签id tagType:标签类型：1单聊 2群聊 userUId:操作用户ID}
- (void)MessageRemoveChatTagWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 全部已读上报接口
/// @param params 操作参数 {userUId:操作用户ID}
- (void)MessageReadAllMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 长链接失败后消息发送接口
/// @param params params
/// @param onSuccess success
/// @param onFailure failure
- (void)MessagePushMsg:(NSData * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
/// 查询群置顶消息列表
/// @param params 操作参数 {groupId:群组ID, userUid:操作用户ID, pageNumber:起始页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始)}
- (void)MessageQueryGroupTopMsgListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询群消息是否可以置顶
/// @param params 操作参数 {groupId:群组ID, msgId:消息ID, userUid:操作用户ID}
- (void)MessageQueryGroupMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询群置顶消息悬浮列表
/// @param params 操作参数 {groupId:群组ID, userUid:操作用户ID}
- (void)MessageQueryGroupTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询个人置顶消息列表
/// @param params 操作参数 {userUid:操作用户ID, type:为0时，查询悬浮的10条记录；1，查询全部的个人当前会话的所有置顶消息列表, friendUid:好友ID}
- (void)MessageQueryUserTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 查询个人消息是否可以置顶
/// @param params 操作参数 {userUid:操作用户ID, friendUid:好友ID, smsgId:服务端消息ID}
- (void)MessageQueryUserMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 设置/取消 消息置顶
/// @param params 操作参数 {userUid:操作用户ID, friendUid:好友ID, smsgId:服务端消息ID, msgStatus:消息状态(1 全局置顶，2用户个人置顶，3取消全局置顶，4取消个人置顶)}
- (void)MessageSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 编辑已发送消息。
/// @param messageData 原消息标识与编辑后正文组成的 Protobuf 数据。
- (void)MessageEditOneMsgWith:(NSData *)messageData onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end



NS_ASSUME_NONNULL_END
