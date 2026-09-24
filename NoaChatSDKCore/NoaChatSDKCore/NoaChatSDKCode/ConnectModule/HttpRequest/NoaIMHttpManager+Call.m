//
//  NoaIMHttpManager+Call.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/1/5.
//

#import "NoaIMHttpManager+Call.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Call)

#pragma mark -用户发起音视频请求(告知对方，用户想要和对方进行音视频通话)
- (void)callRequestCallWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Request_Call_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Request_Call_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 用户响应对方发来的音视频请求(用户接收到对方发来的音视频通话的请求，进入音视频相关的UI，告知对方waiting等待用户接通音视频通话)
- (void)callReceiveCallWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Receive_Call_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Receive_Call_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 用户接受对方发来的音视频请求(告知对方accept用户接通了音视频通话)
- (void)callAcceptCallWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Accept_Call_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Accept_Call_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 用户确认音视频会话，创建房间(用户接收到对方已经接受了这次音视频通话，进行房间的创建)
- (void)callConfirmCallWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Confirm_Call_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Confirm_Call_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 用户结束/音视频会话(告知对方，用户结束或拒绝与对方的音视频通话)
- (void)callDiscardCallWith:(NSMutableDictionary *)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Discard_Call_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Discard_Call_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - ******多人音视频接口名称******
#pragma mark - 用户发起多人音视频通话请求(告知对方，用户想要和对方进行音视频通话)
- (void)callGroupRequestCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Group_Request_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Group_Request_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 用户接受对方发来的多人音视频请求
- (void)callGroupAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Group_Accept_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Group_Accept_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 邀请加入多人音视频通话
- (void)callGroupInviteCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Group_Invite_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Group_Invite_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 主动加入多人音视频通话
- (void)callGroupJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Group_Join_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Group_Join_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 结束多人音视频通话
- (void)callGroupDiscardCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Group_Discard_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Group_Discard_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 获得当前群通话信息(多人通话状态)
- (void)callGroupStateCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Phone_Group_GetChatCall_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Phone_Group_GetChatCall_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - <<<<<<音视频通话通用接口-即构>>>>>>

#pragma mark - 发起者创建音视频通话
- (void)userCreateCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Create_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Create_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 发起者取消通话(通话未接听)
- (void)userCancelCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Cancel_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Cancel_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 被邀请者接听通话
- (void)userAcceptCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Accept_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Accept_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 被邀请者拒绝通话(通话未接听)
- (void)userRejectCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Reject_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Reject_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 挂断通话
- (void)userHangUpCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Hang_Up_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Hang_Up_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 群聊 主动加入某个音视频通话
- (void)userJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Join_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Join_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
    
}

#pragma mark - 群聊 邀请加入某个音视频通话
- (void)userInviteToCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_Invite_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_Invite_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 群聊 获取某个群 当前正在进行的音视频通话信息(判断是否有正在进行的音视频通话)
- (void)userGetGroupCallInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_GroupCallInfo_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_GroupCallInfo_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 根据callId获取某个用户的token鉴权信息
- (void)userGetCallInfoTokenWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_CallInfoToken_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_CallInfoToken_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 音视频通话确认完成了整个加入流程
- (void)userConfirmJoinCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (params) {
        if (kAllHttpRequestUseTcp) {
            [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_ConfirmJoin_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
        }else {
            [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_ConfirmJoin_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
        }
    }
}

#pragma mark - 音视频通话心跳接口
- (void)userHeartbeatCallWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Call_HheartBeat_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Call_HheartBeat_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}
@end
