//
//  NoaIMMessageRemindTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/7.
//

#import "NoaIMMessageRemindTool.h"
#import <AudioToolbox/AudioToolbox.h>
#import "NoaIMSocketManager.h"
#import <AVFoundation/AVFoundation.h>
#import <MMKV/MMKV.h>
//单例
static dispatch_once_t onceToken;


@interface NoaIMMessageRemindTool ()

@property (nonatomic, copy) NSString *voiceSource;//自定义消息铃声资源
@property (nonatomic, copy) NSString *voiceExtension;//自定义消息铃声资源类型
@property (nonatomic, strong) IMMessage *lastMessage;//上一个提醒消息，用于防止快速连续接收到消息提示的问题


@end

@implementation NoaIMMessageRemindTool

#pragma mark - 单例
+ (instancetype)sharedManager {
    static NoaIMMessageRemindTool *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMMessageRemindTool sharedManager];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMMessageRemindTool sharedManager];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMMessageRemindTool sharedManager];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearManager{
    onceToken = 0;
}


#pragma mark - 消息提醒
- (void)messageRemindOpen:(BOOL)openRemind {
    [[MMKV defaultMMKV] setBool:openRemind forKey:@"RemindOpen"];
    
}

- (void)messageRemindVoiceOpen:(BOOL)openVoice {
    [[MMKV defaultMMKV] setBool:openVoice forKey:@"RemindVoiceOpen"];

}

- (void)messageRemindVibrationOpen:(BOOL)openVibration {
    [[MMKV defaultMMKV] setBool:openVibration forKey:@"RemindVibrationOpen"];

}

- (BOOL)messageRemindOpend {
    return [[MMKV defaultMMKV] getBoolForKey:@"RemindOpen"];
}

- (BOOL)messageRemindVoiceOpend {
    return [[MMKV defaultMMKV] getBoolForKey:@"RemindVoiceOpen"];
}

- (BOOL)messageRemindVibrationOpend {
    return [[MMKV defaultMMKV] getBoolForKey:@"RemindVibrationOpen"];
}

/// 自定义消息提醒铃声
- (void)messageRemindVoiceConfigWith:(NSString *)voiceSource extension:(NSString *)voiceExtension {
    _voiceSource = voiceSource;
    _voiceExtension = voiceExtension;
}

/// 接收消息提醒
- (void)messageRemindForReceiveMessage:(IMMessage *)message {
    switch (message.dataType) {
        case IMMessage_DataType_ImchatMessage://聊天类型消息
        {
            
            IMChatMessage *chatMessage = message.chatMessage;
            switch (chatMessage.mType) {
                case IMChatMessage_MessageType_TextMessage://文本消息
                case IMChatMessage_MessageType_ImageMessage://图片消息
                case IMChatMessage_MessageType_VideoMessage://视频消息
                case IMChatMessage_MessageType_VoiceMessage://视频消息
                case IMChatMessage_MessageType_FileMessage://视频消息
                case IMChatMessage_MessageType_StickersMessage://表情记录
                case IMChatMessage_MessageType_GameStickersMessage://游戏表情记录
                case IMChatMessage_MessageType_AtMessage://@消息
                case IMChatMessage_MessageType_CardMessage://名片消息
                case IMChatMessage_MessageType_Geomessage://地理位置消息
                case IMChatMessage_MessageType_ForwardMessage://消息记录
                {
                    if (![chatMessage.from isEqualToString:[SOCKETMANAGER socketUserID]]) {
                        //不是我发送的消息
                        IMChatMessage *lastChatMessage = _lastMessage.chatMessage;
                        if (chatMessage.sendTime - lastChatMessage.sendTime > 1000) {
                            //上次提示消息 和 这次接收到的消息 时间间隔
                            [self receiveMessageRemind];
                            _lastMessage = message;
                        }
                    }
                }
                    break;
                    
                default:
                    break;
            }
            
        }
            break;
            
        default:
            break;
    }
    
}

/// 接收消息提醒
- (void)messageRemindForMessage {
    [self receiveMessageRemind];
}

//消息提醒方式
- (void)receiveMessageRemind {
    BOOL remindOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindOpen"];
    if (remindOpen) {
        BOOL remindVoiceOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVoiceOpen"];
        BOOL remindVibrationOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVibrationOpen"];
        if (remindVoiceOpen) {
            //声音提示
            [self receiveMessageRemindVoice];
        }
        if (remindVibrationOpen) {
            //震动提示
            [self receiveMessageRemindVibration];
        }
    }
}

//声音提示消息
- (void)receiveMessageRemindVoice {
    // 要播放的音频文件地址
    //NSURL *audioPath = [[NSBundle mainBundle] URLForResource:@"sound" withExtension:@"caf"];
    if (_voiceSource.length > 0) {
        NSURL *voicePath = [[NSBundle mainBundle] URLForResource:_voiceSource withExtension:_voiceExtension];
        // 创建系统声音，同时返回一个ID
        SystemSoundID soundID;
        
        OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)(voicePath), &soundID);
        if (error != kAudioServicesNoError) {
            AudioServicesPlaySystemSound(soundID);
        }
    }else {
        AudioServicesPlaySystemSound(1004);
    }
}

//震动提示消息
- (void)receiveMessageRemindVibration {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}



@end
