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

//******1定义一个全局静态变量指针用于保存当前类的地址(在C方法中调用OC)
static NoaIMMessageRemindTool *selfClass = nil;

@interface NoaIMMessageRemindTool ()
{
    SystemSoundID mediaCallSoundID;//音视频通话铃声标记
}

@property (nonatomic, copy) NSString *voiceSource;//自定义消息铃声资源
@property (nonatomic, copy) NSString *voiceExtension;//自定义消息铃声资源类型
@property (nonatomic, strong) IMMessage *lastMessage;//上一个提醒消息，用于防止快速连续接收到消息提示的问题

@property (nonatomic, copy) NSString *voiceSourceMediaCall;//自定义音视频通话提醒铃声资源
@property (nonatomic, copy) NSString *voiceExtensionMediaCall;//自定义音视频通话提醒铃声类型

@end

@implementation NoaIMMessageRemindTool

#pragma mark - 单例
+ (instancetype)sharedManager {
    static NoaIMMessageRemindTool *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        //******2函数指针指向自己
        selfClass = _manager;
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

#pragma mark - 音视频通话提醒
/// 音视频通话提醒铃声
- (void)messageRemindForMediaCall {
    BOOL remindOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindOpen"];
    
    if (remindOpen) {
        
        BOOL remindVoiceOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVoiceOpen"];
        if (remindVoiceOpen) {
            //声音提示
            [self receiveMessageRemindVoiceForMediaCall];
        }
        
        BOOL remindVibrationOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVibrationOpen"];
        if (remindVibrationOpen) {
            //震动提示
            [self receiveMessageRemindVibrationForMediaCall];
        }
        
    }
}

/// 音视频通话自定义提醒铃声
- (void)messageRemindVoiceConfigForMediaCallWith:(NSString * _Nullable)voiceSource extension:(NSString * _Nullable)voiceExtension {
    _voiceSourceMediaCall = voiceSource;
    _voiceExtensionMediaCall = voiceExtension;
}

/// 音视频通话提醒铃声结束
- (void)messageRemindEndForMediaCall {
    //停止震动响应
    BOOL remindVibrationOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVibrationOpen"];
    if (remindVibrationOpen) {
        AudioServicesDisposeSystemSoundID(kSystemSoundID_Vibrate);
        AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate);
        //******在停止震动时候我们需要调用[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(triggerShake)object:nil];  停止之前可能的回调；这两个方法的成对使用既好用又简便，对于需要定时调用的场景很适合，也免去维护定时器的麻烦。
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(receiveMessageRemindVibrationForMediaCall) object:nil];
    }
    
    //停止声音响应
    BOOL remindVoiceOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVoiceOpen"];
    if (remindVoiceOpen) {
        AudioServicesDisposeSystemSoundID(mediaCallSoundID);
        AudioServicesRemoveSystemSoundCompletion(mediaCallSoundID);
    }
}

/// 音视频通话之铃声提醒
- (void)receiveMessageRemindVoiceForMediaCall {
    // 要播放的音频文件地址
    if (_voiceSource.length > 0) {
        
        NSURL *voicePath = [[NSBundle mainBundle] URLForResource:_voiceSourceMediaCall withExtension:_voiceExtensionMediaCall];
        // 创建系统声音，同时返回一个ID
        SystemSoundID soundID = 0;
        
        OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)(voicePath), &soundID);
        
        if (error != kAudioServicesNoError) {
            AudioServicesAddSystemSoundCompletion(soundID, NULL, NULL, voiceCompleteCallBack, NULL);
            AudioServicesPlaySystemSound(soundID);
            mediaCallSoundID = soundID;
        }
    }else {
        AudioServicesAddSystemSoundCompletion(1004, NULL, NULL, voiceCompleteCallBack, NULL);
        AudioServicesPlaySystemSound(1004);
        mediaCallSoundID = 1004;
    }
}

/// 音视频通话之震动提醒
- (void)receiveMessageRemindVibrationForMediaCall {
    AudioServicesAddSystemSoundCompletion(kSystemSoundID_Vibrate, NULL, NULL, vibrationCompleteCallBack, NULL);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

/// 铃声结束后回调
void voiceCompleteCallBack(SystemSoundID sound,void * clientData) {
    BOOL remindVoiceOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVoiceOpen"];
    if (remindVoiceOpen) {
        AudioServicesPlaySystemSound(sound);
    }
}

/// 震动结束后回调
void vibrationCompleteCallBack(SystemSoundID sound,void * clientData) {
    BOOL remindVibrationOpen = [[MMKV defaultMMKV] getBoolForKey:@"RemindVibrationOpen"];
    if (remindVibrationOpen) {
        //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        //******在c回调里面通过单例（全局变量性质的指针）调用到oc的方法进行[self performSelector:@selector(receiveMessageRemindVibrationForMediaCall) withObject:nil afterDelay:0.5]
        [selfClass performSelector:@selector(receiveMessageRemindVibrationForMediaCall) withObject:nil afterDelay:0.5];
    }
}

@end
