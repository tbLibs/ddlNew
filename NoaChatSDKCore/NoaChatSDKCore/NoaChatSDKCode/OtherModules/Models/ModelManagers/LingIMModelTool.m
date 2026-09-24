//
//  LingIMModelTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "LingIMModelTool.h"
#import "NoaIMDBTool.h"
#import "NoaIMSocketManagerTool.h"
//同步服务端时间
#import "ZDateRequestTool.h"

//单例
static dispatch_once_t onceToken;

@interface LingIMModelTool ()

@end

@implementation LingIMModelTool
#pragma mark - 单例
+ (instancetype)sharedTool {
    static LingIMModelTool *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [LingIMModelTool sharedTool];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [LingIMModelTool sharedTool];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [LingIMModelTool sharedTool];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearTool {
    onceToken = 0;
}

#pragma mark - 将IMChatMessage转换为数据库存储的LingIMChatMessageModel(长连接接收到消息解析)
- (NoaIMChatMessageModel *)getChatMessageModelFromIMChatMessage:(IMChatMessage *)message {
    if (message) {
        NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
        model.msgID = message.msgId;
        model.serviceMsgID = message.sMsgId;
        model.chatType = message.cType;
        model.messageType = message.mType;
        model.fromID = message.from;
        model.fromNickname = message.nick;
        model.fromIcon = message.icon;
        model.toID = message.to;
        model.isAck = message.isAck;
        model.isEncry = message.isEncry;
        model.snapchat = message.snapchat;
        model.sendTime = message.sendTime;
        model.referenceMsgId = message.referenceMsgId;
        model.toSource = message.toSource;
        
        if ([message.from isEqualToString:[DBTOOL myUserID]]) {
            //我发送的消息，默认已读
            model.chatMessageReaded = YES;
        }else {
            //别人发送的消息，默认未读
            model.chatMessageReaded = NO;
        }
        
        model.currentVersionMessageOK = YES;
        model.messageStatus = 1;//接收到的消息，默认是正常消息
        
        switch (message.mType) {
            case IMChatMessage_MessageType_TextMessage:
            {
                //0文本消息
                model.textContent = message.textMessage.content;
                model.translateContent = message.textMessage.translate;
                model.againTranslateContent = @"";
                model.textExt = message.textMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_ImageMessage:
            {
                //1图片消息
                model.imgHeight = message.imageMessage.height;
                model.imgWidth = message.imageMessage.width;
                model.imgSize = message.imageMessage.size;
                model.imgName = message.imageMessage.name;
                model.thumbnailImg = message.imageMessage.iImg;
                model.imgExt = message.imageMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_VideoMessage:
            {
                //2视频消息
                model.videoCover = message.videoMessage.cImg;
                model.videoCoverH = message.videoMessage.cHeight;
                model.videoCoverW = message.videoMessage.cWidth;
                model.videoLength = message.videoMessage.length;
                model.videoName = message.videoMessage.name;
                model.videoExt = message.videoMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_VoiceMessage:
            {
                //4音频消息
                model.voiceLength = message.voiceMessage.length;
                model.voiceName = message.voiceMessage.name;
                model.voiceExt = message.voiceMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_FileMessage:
            {
                //5文件消息
                model.fileName = message.fileMessage.name;
                model.filePath = message.fileMessage.path;
                model.fileType = message.fileMessage.type;
                model.fileSize = message.fileMessage.size;
                model.fileExt = message.fileMessage.ext;
                NSRange range = [message.fileMessage.name rangeOfString:@"-"];
                if (range.length == 0) {
                    model.showFileName = message.fileMessage.name;
                } else {
                    model.showFileName = [message.fileMessage.name substringWithRange:NSMakeRange(range.location+1, message.fileMessage.name.length - (range.location+1))];
                }
            }
                break;
            case IMChatMessage_MessageType_CardMessage:
            {
                //6名片消息
                model.cardUrl = message.cardMessage.URL;
                model.cardName = message.cardMessage.name;
                model.cardUserId = message.cardMessage.userId;
                model.cardHeadPicUrl = message.cardMessage.headPicURL;
                model.cardNickName = message.cardMessage.nickName;
                model.cardUserName = message.cardMessage.userName;
                model.cardExt = message.cardMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_Geomessage:
            {
                //3地理位置消息
                model.geoLng = message.geoMessage.lng;
                model.geoLat = message.geoMessage.lat;
                model.geoName = message.geoMessage.name;
                model.geoImg = message.geoMessage.cImg;
                model.geoImgHeight = message.geoMessage.cHeight;
                model.geoImgWidth = message.geoMessage.cWidth;
                model.geoExt = message.geoMessage.ext;
                model.geoDetails = message.geoMessage.details;
            }
                break;
            case IMChatMessage_MessageType_StickersMessage:
            {
                //12表情消息
                model.stickersHeight = message.stickersMessage.height;
                model.stickersWidth = message.stickersMessage.width;
                model.stickersSize = message.stickersMessage.size;
                model.stickersName = message.stickersMessage.name;
                model.stickersId = message.stickersMessage.id_p;
                model.stickersThumbnailImg = message.stickersMessage.thumbImg;
                model.stickersImg = message.stickersMessage.img;
                model.isStickersSet = message.stickersMessage.isStickersSet;
                model.stickersExt = message.stickersMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_GameStickersMessage:
            {
                //21游戏表情消息
                model.gameSticekersType = message.gameStickersMessage.type;
                model.gameStickersResut = message.gameStickersMessage.result;
                model.gameStickersExt = message.gameStickersMessage.ext;
            }
                break;
            case IMChatMessage_MessageType_ForwardMessage:
            {
                //18 消息记录消息
                model.forwardMessageProtobuf = message.forwardMessage.delimitedData;
                model.forwardMessage = message.forwardMessage;
            }
                break;
            case IMChatMessage_MessageType_BackMessage:
            {
                //8撤回消息(BackDelMessage解析)
                model.backDelServiceMsgID = message.backDelMessage.sMsgId;
                model.backDeleteExt = message.backDelMessage.ext;
                model.backDelInformSwitch = message.backDelMessage.informSwitch;
                model.backDelInformUidArray = message.backDelMessage.informUidArray;
                model.chatMessageReaded = YES;//默认已读
            }
                break;
                
            case IMChatMessage_MessageType_BilateralDel:
            {
                //15双向删除消息(BackDelMessage解析)
                model.backDelServiceMsgID = message.backDelMessage.sMsgId;
                model.backDeleteExt = message.backDelMessage.ext;
                model.chatMessageReaded = YES;//默认已读
            }
                break;
            case IMChatMessage_MessageType_AtMessage:
            {
                //10 @消息
                model.atContent = message.atMessage.content;
                model.atTranslateContent = message.atMessage.translate;
                model.againAtTranslateContent = @"";
                model.atExt = message.atMessage.ext;
                
                NSMutableArray *atUserDicList = [NSMutableArray array];
                for (AtInfo *info in message.atMessage.atInfoArray) {
                    NSMutableDictionary *atUsersDict = [NSMutableDictionary dictionary];
                    [atUsersDict setValue:info.uNick forKey:info.uId];
                    
                    [atUserDicList addObject:atUsersDict];
                }
                model.atUsersInfoList = atUserDicList;
                
                //处理At消息，将消息atContent中的 \vUID\v 替换 为 @nickName  方便显示
                NSString *atContetnStr = [NSString stringWithString:model.atTranslateContent.length > 0 ? model.atTranslateContent : model.atContent];
                for (NSDictionary *atUserDic in model.atUsersInfoList) {
                    NSArray *atKeyArr = [atUserDic allKeys];
                    NSString *atKey = (NSString *)[atKeyArr firstObject];
         
                    if ([atKey isEqualToString:[DBTOOL myUserID]]) {
                        if ([message.from isEqualToString:[DBTOOL myUserID]]) {
                            atContetnStr = [atContetnStr stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\v%@\v", atKey] withString:@"@我自己"];
                        } else {
                            atContetnStr = [atContetnStr stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\v%@\v", atKey] withString:@"@我"];
                        }
                    } else if ([atKey isEqualToString:@"-1"]) {
                        atContetnStr = [atContetnStr stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\v%@\v", atKey] withString:@"@所有人"];
                    } else {
                        atContetnStr = [atContetnStr stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\v%@\v", atKey] withString:[NSString stringWithFormat:@"@%@", [atUserDic objectForKey:atKey]]];
                    }
                }
                model.showContent = atContetnStr;
                
            }
                break;
                
            case IMChatMessage_MessageType_GroupNotice:
            {
                //16 群组公告消息
                model.groupNoticeContent = message.groupNotice.content;
                model.groupNoticeTranslateContent = message.groupNotice.transContent;
                model.groupNoticeID = message.groupNotice.noticeId;
                model.groupNoticeExt = message.groupNotice.ext;
            }
                break;
            case IMChatMessage_MessageType_NetCallMessage:
            {
                //20音视频通话消息
                model.chatMessageReaded = YES;//默认已读
                //消息发送者 都以 音视频发起者的名义来处理
                if (![message.from isEqualToString:message.netCallMessage.roomCreateUser]) {
                    model.fromID = message.to;
                    model.toID = message.from;
                }
                model.netCallRoomCreateUser = message.netCallMessage.roomCreateUser;
                model.netCallId = message.netCallMessage.callId;
                model.netCallRoomId = message.netCallMessage.roomId;
                model.netCallToken = message.netCallMessage.token;
                model.netCallType = message.netCallMessage.callType;
                model.netCallTimeout = message.netCallMessage.timeout;
                model.netCallChatType = message.netCallMessage.chatType;
                model.netCallStatus = message.netCallMessage.status;
                model.netCallDuration = message.netCallMessage.duration;
                model.netCallRoomUsers = message.netCallMessage.roomUsersArray;
                model.netCallOperationUsers = message.netCallMessage.operationUsersArray;
            }
                break;
                
            default:
            {
                model.currentVersionMessageOK = NO;
                CIMLog(@"ChatMessage有未解析的messageType:%d",message.mType);
            }
                break;
        }
        
        return model;
    }else {
        return nil;
    }
}
#pragma mark - 将LingIMChatMessageModel转换为发送消息的IMChatMessage
- (IMChatMessage *)getChatMessageModelFromLingIMChatMessageModel:(NoaIMChatMessageModel *)message {
    
    //IMChatMessage的bodyOneOfCase字段会在配置好消息的时候，自动生成
    
    IMChatMessage *chatMessage = [[IMChatMessage alloc] init];
    
    chatMessage.deviceType = @"IOS";
    chatMessage.deviceUuid = [FCUUID uuidForDevice];
    chatMessage.msgId = message.msgID;
    chatMessage.cType = (ChatType)message.chatType;
    chatMessage.mType = (IMChatMessage_MessageType)message.messageType;
    chatMessage.isAck = message.isAck;
    chatMessage.from = message.fromID;
    chatMessage.nick = message.fromNickname;
    chatMessage.icon = message.fromIcon;
    chatMessage.to = message.toID;
    // 发包时间：有校准则用校准时间；未校准用本地已写入的 sendTime，避免发出异常小时间戳
    BOOL synced = [NSDate hasValidServerTimeSync];
    long long calibrated = [NSDate safeCurrentServerMillisecondTime];
    if (synced) {
        chatMessage.sendTime = calibrated;
    } else if (message.sendTime > 0) {
        chatMessage.sendTime = message.sendTime;
    } else {
        chatMessage.sendTime = calibrated;
    }
    chatMessage.sessionId = [NoaIMSocketManagerTool sharedManager].socketUUID;
    
    CIMLog(@"[MsgTime] send wire local=%lld calibrated=%lld used=%lld synced=%d delta=%lld",
           message.sendTime, calibrated, chatMessage.sendTime, synced, chatMessage.sendTime - message.sendTime);
    if (message.referenceMsgId.length > 0) {
        //引用类型消息
        chatMessage.referenceMsgId = message.referenceMsgId;
    }
    
    switch (message.messageType) {
        case CIMChatMessageType_TextMessage:
        {
            //文本消息
            chatMessage.textMessage.content = message.textContent;
            chatMessage.textMessage.translate = message.translateContent;
            chatMessage.textMessage.ext = message.textExt;
        }
            break;
        case CIMChatMessageType_ImageMessage:
        {
            //图片消息
            chatMessage.imageMessage.width = message.imgWidth;
            chatMessage.imageMessage.height = message.imgHeight;
            chatMessage.imageMessage.size = message.imgSize;
            chatMessage.imageMessage.name = message.imgName;
            chatMessage.imageMessage.iImg = message.thumbnailImg;
            
        }
            break;
        case CIMChatMessageType_StickersMessage:
        {
            //表情消息
            chatMessage.stickersMessage.height = message.stickersHeight;
            chatMessage.stickersMessage.width = message.stickersWidth;
            chatMessage.stickersMessage.size = message.stickersSize;
            chatMessage.stickersMessage.name = message.stickersName;
            chatMessage.stickersMessage.id_p = message.stickersId;
            chatMessage.stickersMessage.thumbImg = message.stickersThumbnailImg;
            chatMessage.stickersMessage.img = message.stickersImg;
            chatMessage.stickersMessage.isStickersSet = message.isStickersSet;
            chatMessage.stickersMessage.ext = message.stickersExt;
        }
            break;
        case CIMChatMessageType_GameStickersMessage:
        {
            //游戏表情消息
            chatMessage.gameStickersMessage.type = message.gameSticekersType;
            chatMessage.gameStickersMessage.result = message.gameStickersResut;
            chatMessage.gameStickersMessage.ext = message.gameStickersExt;
        }
            break;
        case CIMChatMessageType_VideoMessage:
        {
            //视频消息
            chatMessage.videoMessage.cImg = message.videoCover;
            chatMessage.videoMessage.cWidth = message.videoCoverW;
            chatMessage.videoMessage.cHeight = message.videoCoverH;
            chatMessage.videoMessage.length = message.videoLength;
            chatMessage.videoMessage.name = message.videoName;
            chatMessage.videoMessage.ext = message.videoExt;
        }
            break;
        case CIMChatMessageType_VoiceMessage:
        {
            //语音消息
            chatMessage.voiceMessage.length = message.voiceLength;
            chatMessage.voiceMessage.name = message.voiceName;
            chatMessage.voiceMessage.ext = message.voiceExt;
        }
            break;
        case CIMChatMessageType_FileMessage:
        {
            //文件消息
            chatMessage.fileMessage.size = message.fileSize;
            chatMessage.fileMessage.name = message.fileName;
            chatMessage.fileMessage.path = message.filePath;
            chatMessage.fileMessage.type = message.fileType;
            chatMessage.fileMessage.ext = message.fileExt;
        }
            break;
        case CIMChatMessageType_AtMessage:
        {
            //At消息
            chatMessage.atMessage.content = message.atContent;
            chatMessage.atMessage.translate = message.atTranslateContent;
            chatMessage.atMessage.ext = message.atExt;
            NSMutableArray *atInfoArray = [NSMutableArray array];
            for (NSDictionary *atUserDic in message.atUsersInfoList) {
                NSArray *atKeyArr = [atUserDic allKeys];
                NSString *uid = (NSString *)[atKeyArr firstObject];
            
                AtInfo *info = [[AtInfo alloc] init];
                info.uId = uid;
                info.uNick = [atUserDic objectForKey:uid];
                [atInfoArray addObject:info];
            }
            chatMessage.atMessage.atInfoArray = atInfoArray;
        }
            break;
        case CIMChatMessageType_CardMessage:
        {
            //名片消息
            chatMessage.cardMessage.URL = message.cardUrl;
            chatMessage.cardMessage.name = message.cardName;
            chatMessage.cardMessage.userId = message.cardUserId;
            chatMessage.cardMessage.headPicURL = message.cardHeadPicUrl;
            chatMessage.cardMessage.nickName = message.cardNickName;
            chatMessage.cardMessage.userName = message.cardUserName;
            chatMessage.cardMessage.ext = message.cardExt;
        }
            break;
        case CIMChatMessageType_GeoMessage:
        {
            //地理位置消息
            chatMessage.geoMessage.lng = message.geoLng;
            chatMessage.geoMessage.lat = message.geoLat;
            chatMessage.geoMessage.name = message.geoName;
            chatMessage.geoMessage.cImg = message.geoImg;
            chatMessage.geoMessage.cHeight = message.geoImgHeight;
            chatMessage.geoMessage.cWidth = message.geoImgWidth;
            chatMessage.geoMessage.ext = message.geoExt;
            chatMessage.geoMessage.details = message.geoDetails;
        }
            break;
        case CIMChatMessageType_ForwardMessage:
        {
            //合并转发-消息记录
            chatMessage.forwardMessage = message.forwardMessage;
        }
            break;
        case CIMChatMessageType_HaveReadMessage:
        {
            chatMessage.haveReadMessage.sMsgIdArray = message.sMsgIdArray;
        }
        default:
            break;
    }
    return chatMessage;
}

#pragma mark -  汉字转拼音
- (NSString *)chineseTransformWithCharacters:(NSString *)chineseCharacters {
    if ([chineseCharacters length]) {
        CFStringRef hanzi = (__bridge CFStringRef)(chineseCharacters);
        
        CFMutableStringRef string = CFStringCreateMutableCopy(NULL, 0, hanzi);
        
        // Boolean CFStringTransform(CFMutableStringRef string, CFRange *range, CFStringRef transform, Boolean reverse);
        //string 为要转换的字符串
        // range 要转换的范围，NULL 则为全部
        //transform 要进行怎么样的转换    //kCFStringTransformMandarinLatin 将汉字转拼音
        //reverse 是否支持逆向转换
        CFStringTransform(string, NULL, kCFStringTransformMandarinLatin, NO);
        
        //kCFStringTransformStripDiacritics去掉声调
        CFStringTransform(string, NULL, kCFStringTransformStripDiacritics, NO);
        
        NSString * pinyin = (NSString *) CFBridgingRelease(string);
        //将中间分隔符号去掉
        pinyin = [pinyin stringByReplacingOccurrencesOfString:@" " withString: @""];
        
        return pinyin;
    }else {
        return @"";
    }
}

@end
