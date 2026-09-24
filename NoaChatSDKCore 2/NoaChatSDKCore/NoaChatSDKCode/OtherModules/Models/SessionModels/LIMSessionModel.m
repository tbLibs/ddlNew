//
//  LIMSessionModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

#import "LIMSessionModel.h"
#import "LingIMSessionModel.h"
#import "NoaIMSDKManager+Session.h"
#import "NoaChatMessageModel.h"
#import "LIMMassMessageModel.h"

@implementation LIMSessionModel

- (NoaIMChatMessageModel *)sessionLatestMessage {
    if (self.messageDialogHistory && [self.messageDialogHistory isKindOfClass:[NSDictionary class]]) {
        NoaChatMessageModel *modelChat = [NoaChatMessageModel mj_objectWithKeyValues:self.messageDialogHistory];
        NoaIMChatMessageModel *chatMessage = [modelChat getChatMessageFromMessageRecordModel];
        return chatMessage;
    }
    return nil;
}

- (LIMMassMessageModel *)sessionLatestMassMessage {
    if (self.messageDialogHistory && [self.messageDialogHistory isKindOfClass:[NSDictionary class]]) {
        LIMMassMessageModel *massMessageModel = [LIMMassMessageModel mj_objectWithKeyValues:self.messageDialogHistory];
        return massMessageModel;
    }
    return nil;
}
- (LingIMSessionModel *)getSessionModel {
    LingIMSessionModel *model;
    if (IMSDKManager.lastSyncSessionTime != 0) {
        model = [IMSDKManager toolCheckMySessionWith:self.peerUid];
        if (!model) {
            model = [LingIMSessionModel new];
            
            //对固定不变的内容赋值
            if (self.dialogType == 0) {
                //单聊
                model.sessionType = CIMSessionTypeSingle;
            }else if (self.dialogType == 1) {
                //群聊
                model.sessionType = CIMSessionTypeGroup;
                //普通群聊
                model.sessionGroupType = CIMGroupTypeNormal;
            }else if (self.dialogType == 3) {
                //群发助手
                model.sessionType = CIMSessionTypeMassMessage;
            }else if (self.dialogType == 5) {
                if ([self.peerUid isEqualToString:@"100008"]) {
                    //系统消息(群助手)
                    model.sessionType = CIMSessionTypeSystemMessage;
                }
                if ([self.peerUid isEqualToString:@"100009"])
                {
                    //系统消息(支付通知)
                    model.sessionType = CIMSessionTypePaymentAssistant;
                }
            }else {
                //占位值
                model.sessionType = CIMSessionTypeDefault;
                CIMLog(@"新增的 未解析 会话类型:%ld", self.dialogType);
            }
            
            model.sessionID = self.peerUid;
            model.sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],self.peerUid];
            CIMLog(@"sessionTableName = %@",model.sessionTableName);

        }
    } else {
        if (!model) {
            
            model = [LingIMSessionModel new];
            
            //对固定不变的内容赋值
            if (self.dialogType == 0) {
                //单聊
                model.sessionType = CIMSessionTypeSingle;
            }else if (self.dialogType == 1) {
                //群聊
                model.sessionType = CIMSessionTypeGroup;
                //普通群聊
                model.sessionGroupType = CIMGroupTypeNormal;
            }else if (self.dialogType == 3) {
                //群发助手
                model.sessionType = CIMSessionTypeMassMessage;
            }else if (self.dialogType == 5) {
                if ([self.peerUid isEqualToString:@"100008"]) {
                    //系统消息(群助手)
                    model.sessionType = CIMSessionTypeSystemMessage;
                }
                if ([self.peerUid isEqualToString:@"100009"])
                {
                    //系统消息(支付通知)
                    model.sessionType = CIMSessionTypePaymentAssistant;
                }
            }else {
                //占位值
                model.sessionType = CIMSessionTypeDefault;
                CIMLog(@"新增的 未解析 会话类型:%ld", self.dialogType);
            }
            
            model.sessionID = self.peerUid;
            model.sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],self.peerUid];
            CIMLog(@"sessionTableName = %@",model.sessionTableName);

        }
    }
    
    //更新可变的内容
    if([self.remarks isEqualToString:@""] || !self.remarks){
        model.sessionName = self.userName;
    }else{
        model.sessionName = self.remarks;
    }
    
    model.sessionStatus = 1;
    model.sessionAvatar = self.avatar;
    model.sessionTop = self.pinnedTime > 0 ? YES : NO;
    model.sessionNoDisturb = self.dnd;
    model.sessionTopTime = self.pinnedTime;
    model.sessionLatestServerMsgID = self.lastMsgId;
    model.sessionUnreadCount = self.unReadCount > 0 ? self.unReadCount : 0;
    if (self.dialogTime > model.sessionLatestTime) {
        model.sessionLatestTime = self.dialogTime;
    }
    
    return model;
}

@end
