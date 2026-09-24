//
//  NoaIMHttpManager+Message.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/20.
//

#import "NoaIMHttpManager+Message.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Message)

#pragma mark - 获取在服务器保存的会话列表
- (void)MessageGetConversationsFromServer:(NSMutableDictionary * _Nullable)params
                         onSuccess:(LingIMSuccessCallback)onSuccess
                         onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Get_Conversations_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Get_Conversations_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 删除服务器端某个会话
- (void)MessageDeleteServerConversation:(NSMutableDictionary * _Nullable)params
                       onSuccess:(LingIMSuccessCallback)onSuccess
                       onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Delete_ServerConversation_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Delete_ServerConversation_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 指定会话的已读回执
- (void)MessageAckConversationRead:(NSMutableDictionary * _Nullable)params
                  onSuccess:(LingIMSuccessCallback)onSuccess
                  onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Ack_Conversation_Read_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Ack_Conversation_Read_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 会话-群聊 消息免打扰
- (void)MessageGroupConversationPromt:(NSMutableDictionary * _Nullable)params
                onSuccess:(LingIMSuccessCallback)onSuccess
                onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Conversation_Promt_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Conversation_Promt_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 会话-群聊 置顶
- (void)MessageGroupConversationTop:(NSMutableDictionary * _Nullable)params
              onSuccess:(LingIMSuccessCallback)onSuccess
              onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Conversation_Top_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Conversation_Top_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 会话-单聊 消息免打扰
- (void)MessageSingleConversationPromt:(NSMutableDictionary * _Nullable)params
                 onSuccess:(LingIMSuccessCallback)onSuccess
                 onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Single_Conversation_Promt_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Single_Conversation_Promt_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 会话-单聊 置顶
- (void)MessageSingleConversationTop:(NSMutableDictionary * _Nullable)params
               onSuccess:(LingIMSuccessCallback)onSuccess
               onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Single_Conversation_Top_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Single_Conversation_Top_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 会话- 标记未读/标记已读
- (void)MessageConversationReadedStatus:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Conversation_Readed_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Conversation_Readed_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 清空单聊/群聊的聊天记录
- (void)MessageClearChatMessageHistory:(NSMutableDictionary * _Nullable)params
                 onSuccess:(LingIMSuccessCallback)onSuccess
                 onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Clear_Single_MsgRecord_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Clear_Single_MsgRecord_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询 单聊 消息记录
- (void)MessageQuerySingleMsgRecord:(NSMutableDictionary * _Nullable)params
                   onSuccess:(LingIMSuccessCallback)onSuccess
                   onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Query_Single_MsgRecord_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Query_Single_MsgRecord_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询 群聊 消息记录
- (void)MessageQueryGroupMsgRecord:(NSMutableDictionary * _Nullable)params
                  onSuccess:(LingIMSuccessCallback)onSuccess
                  onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Query_Group_MsgRecord_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Query_Group_MsgRecord_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询 通知 离线消息记录
- (void)MessageQueryOfflineMsgRecord:(NSMutableDictionary * _Nullable)params
                    onSuccess:(LingIMSuccessCallback)onSuccess
                    onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Query_OffLine_MsgRecord_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Query_OffLine_MsgRecord_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 消息转发
- (void)MessageTranspondMessage:(NSData *)messageData
               onSuccess:(nullable LingIMSuccessCallback)onSuccess
               onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:messageData Url:Forward_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        // 消息转发保持http请求
        [self netRequestForwardWithPath:Forward_Message_Url paramData:messageData onSuccess:onSuccess onFailure:onFailure];
    }
}

/// 消息转发时检查接受者是否可进行转发
/// @param  params 接受者id数组json字符串
- (void)MessageTranspondComplianceMessage:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Forward_Compliance_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Forward_Compliance_Message_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 消息删除(单向/双向)
- (void)MessageDeleteMessage:(NSMutableDictionary * _Nullable)params
            onSuccess:(nullable LingIMSuccessCallback)onSuccess
            onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Delete_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Delete_Message_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 消息撤回
- (void)MessageRecallMessage:(NSMutableDictionary * _Nullable)params
            onSuccess:(nullable LingIMSuccessCallback)onSuccess
            onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:ReCall_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:ReCall_Message_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 发送消息已读
- (void)MessageReadedMessage:(NSMutableDictionary * _Nullable)params
            onSuccess:(LingIMSuccessCallback)onSuccess
            onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Readed_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Readed_Message_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取多个群聊会话的最新消息
- (void)MessageGetGroupSessionsLatestMessages:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_LatestGroupMessages_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_LatestGroupMessages_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取多个单聊会话的最新消息
- (void)MessageGetSingleSessionsLatestMessages:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_LatestSingleMessages_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_LatestSingleMessages_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 推荐好友名片
- (void)MessageRecommentFriendCard:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Recomment_Friend_Card_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Recomment_Friend_Card_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询 定时删除消息 功能的 设置信息
- (void)MessageTimeDeleteInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTimeRequestWithParam:params Url:Message_Time_Delete_Info_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithServiceTimeWithType:LingIMHttpRequestTypePOST path:Message_Time_Delete_Info_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 设置 定时删除消息 功能
- (void)MessageTimeDeleteSetWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTimeRequestWithParam:params Url:Message_Time_Delete_Set_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithServiceTimeWithType:LingIMHttpRequestTypePOST path:Message_Time_Delete_Set_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 添加消息到 "我的收藏"
- (void)MessageSaveCollectionWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Save_MyCollection_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Save_MyCollection_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群发助手-创建消息转发组
- (void)GroupHairCreateHairGroupWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Hair_Create_Hair_Group_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Hair_Create_Hair_Group_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群发助手-发送群发消息
- (void)GroupHairSendHairMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Hair_Send_Hair_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Hair_Send_Hair_Message_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群发助手-获取群发消息列表
- (void)GroupHairGetMessageListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Hair_Get_Message_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Hair_Get_Message_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群发助手-删除群发消息
- (void)GroupHairDeleteHairMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Hair_Delete_Hair_Message_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Hair_Delete_Hair_Message_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群发助手-查询群发消息的成员列表
- (void)GroupHairGetGroupHairUserListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Hair_Get_Group_Hair_User_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Hair_Get_Group_Hair_User_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 群发助手-查询群发消息的发送失败成员列表
- (void)GroupHairGetGroupHairErrorUserListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Group_Hair_Get_Group_Hair_Error_User_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Group_Hair_Get_Group_Hair_Error_User_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取标签链接信息
- (void)MessageGetChatTagListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Chat_Tag_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Chat_Tag_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 新增标签链接信息
- (void)MessageAddChatTagWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Add_Chat_Tag_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Add_Chat_Tag_Url parameters:params onSuccess:onSuccess onFailure:onFailure];        
    }
}

#pragma mark - 更新标签链接信息
- (void)MessageUpdateChatTagWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Update_Chat_Tag_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Update_Chat_Tag_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 移除标签链接信息
- (void)MessageRemoveChatTagWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Remove_Chat_Tag_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Remove_Chat_Tag_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
#pragma mark - 全部已读上报接口
- (void)MessageReadAllMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Read_All_Message Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Read_All_Message parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

- (void)MessagePushMsg:(NSData * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    // 保持HTTP接口不变
    [self netRequestMessagePushWithPath:Message_Push_Msg_Url paramData:params onSuccess:onSuccess onFailure:onFailure];
}
#pragma mark - 查询群置顶消息列表
- (void)MessageQueryGroupTopMsgListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Query_Group_Top_Msg_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Query_Group_Top_Msg_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询群消息是否可以置顶
- (void)MessageQueryGroupMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Query_Group_Msg_Status_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Query_Group_Msg_Status_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询群置顶消息悬浮列表
- (void)MessageQueryGroupTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Message_Query_Group_Top_Msgs_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Message_Query_Group_Top_Msgs_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询个人置顶消息列表
- (void)MessageQueryUserTopMsgsWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Dialogs_Query_User_Top_Msgs_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Dialogs_Query_User_Top_Msgs_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 查询个人消息是否可以置顶
- (void)MessageQueryUserMsgStatusWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Dialogs_Query_User_Msg_Status_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Dialogs_Query_User_Msg_Status_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 设置/取消 消息置顶
- (void)MessageSetMsgTopWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Dialogs_Set_Msg_Top_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Dialogs_Set_Msg_Top_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 编辑已发送消息
- (void)MessageEditOneMsgWith:(NSData *)messageData onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    // 编辑消息沿用消息类 Protobuf 请求，确保文本、@ 信息和翻译字段原样传输。
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:messageData Url:Message_Edit_One_Msg_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        return;
    }
    [self netRequestForwardWithPath:Message_Edit_One_Msg_Url paramData:messageData onSuccess:onSuccess onFailure:onFailure];
}

@end
