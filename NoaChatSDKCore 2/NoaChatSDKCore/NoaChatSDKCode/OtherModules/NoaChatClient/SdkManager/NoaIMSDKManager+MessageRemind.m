//
//  NoaIMSDKManager+MessageRemind.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/7.
//

#import "NoaIMSDKManager+MessageRemind.h"
#import "NoaIMDBTool+Session.h"
#import <objc/runtime.h>

static const void *lastMessageKey = &lastMessageKey;

@interface NoaIMSDKManager ()

//上一条提醒的消息(runtime设置属性)
@property (nonatomic, strong) NoaIMChatMessageModel *lastMessage;

@end

@implementation NoaIMSDKManager (MessageRemind)

#pragma mark - 消息提醒
- (void)toolMessageReceiveRemindWith:(IMMessage *)message {
    //聊天消息
    if (message.dataType == IMMessage_DataType_ImchatMessage) {
        
        IMChatMessage *messageChat = message.chatMessage;
        
        NoaIMChatMessageModel *chatModel = [[LingIMModelTool sharedTool] getChatMessageModelFromIMChatMessage:messageChat];
        
        NSString *sessionID = [DBTOOL getSessionIDWith:chatModel];
        LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
        
        if (sessionModel && !sessionModel.sessionNoDisturb) {
            //没有开启消息免打扰
            cim_function_messageRemindForReceiveMessage(message);
        }
        
    }
    
}
#pragma mark - 消息提醒
- (void)toolMessageReceiveRemindWithChatMessage:(NoaIMChatMessageModel *)message {
    switch (message.messageType) {
        case CIMChatMessageType_TextMessage:
        case CIMChatMessageType_ImageMessage:
        case CIMChatMessageType_VideoMessage:
        case CIMChatMessageType_VoiceMessage:
        case CIMChatMessageType_FileMessage:
        case CIMChatMessageType_AtMessage:
        case CIMChatMessageType_CardMessage:
        case CIMChatMessageType_GeoMessage:
        case CIMChatMessageType_ForwardMessage:
        case CIMChatMessageType_StickersMessage:
        case CIMChatMessageType_GameStickersMessage:
        {
            NSString *sessionID = [DBTOOL getSessionIDWith:message];
            LingIMSessionModel *sessionModel = [DBTOOL checkMySessionWith:sessionID];
            
            //没有开启消息免打扰
            if (sessionModel && !sessionModel.sessionNoDisturb) {
                
                if (![message.fromID isEqualToString:[self myUserID]]) {
                    //不是我发送的消息
                    if (!self.lastMessage) {
                        //直接进行消息提醒
                        cim_function_messageRemind();
                        self.lastMessage = message;
                    }else {
                        if (message.sendTime - self.lastMessage.sendTime > 1000) {
                            //上次提示消息 和 这次接收到的消息 时间间隔
                            cim_function_messageRemind();
                            self.lastMessage = message;
                        }
                    }
                    
                }
                
            }
            
        }
            break;
            
        default:
            break;
    }
}

#pragma mark - 自定义消息提醒铃声
- (void)toolMessageReceiveRemindVoiceConfigWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension {
    cim_function_messageRemindVoiceConfig(voiceSource, voiceExtension);
}

#pragma mark - 消息提醒配置
- (void)toolMessageReceiveRemindOpen:(BOOL)remindOpen {
    cim_function_messageRemindOpen(remindOpen);
}

#pragma mark - 消息声音提醒
- (void)toolMessageReceiveRemindVoiceOpen:(BOOL)remindVoiceOpen {
    cim_function_messageRemindVoiceOpen(remindVoiceOpen);
}

#pragma mark - 消息震动提醒
- (void)toolMessageReceiveRemindVibrationOpen:(BOOL)remindVibrationOpen {
    cim_function_messageRemindVibrationOpen(remindVibrationOpen);
}

#pragma mark - 消息提醒状态
- (BOOL)toolMessageReceiveRemindOpend {
    return cim_function_messageRemindOpend();
}

#pragma mark - 消息声音提醒状态
- (BOOL)toolMessageReceiveRemindVoiceOpend {
    return cim_function_messageRemindVoiceOpend();
}

#pragma mark - 消息震动提醒状态
- (BOOL)toolMessageReceiveRemindVibrationOpend {
    return cim_function_messageRemindVibrationOpend();
}

#pragma mark - ******音视频通话提醒******
#pragma mark -音视频通话提醒铃声
- (void)toolMessageReceiveRemindForMediaCall {
    //设置为不息屏
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    cim_function_messageRemindForMediaCall();
}

#pragma mark -音视频通话自定义提醒铃声
- (void)toolMessageReceiveRemindVoiceConfigForMediaCallWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension {
    cim_function_messageRemindVoiceConfigForMediaCall(voiceSource, voiceExtension);
}

#pragma mark -音视频通话提醒铃声结束
- (void)toolMessageReceiveRemindEndForMediaCall {
    cim_function_messageRemindEndForMediaCall();
}


#pragma mark - runtime设置属性
- (NoaIMChatMessageModel *)lastMessage {
    return objc_getAssociatedObject(self, @selector(lastMessage));
}
- (void)setLastMessage:(NoaIMChatMessageModel *)lastMessage {
    objc_setAssociatedObject(self, @selector(lastMessage), lastMessage, OBJC_ASSOCIATION_RETAIN);
}

@end
