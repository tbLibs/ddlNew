//
//  NoaChatMessageModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

#import "NoaChatMessageModel.h"
#import "NoaIMSDKManager+ChatMessage.h"

@implementation NoaChatMessageModel

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"ID" : @"id"
    };
}

#pragma mark - 根据聊天记录消息，获取数据库存储类型消息(短连接 接口 返回消息解析)
- (NoaIMChatMessageModel *)getChatMessageFromMessageRecordModel {
    if (self) {
        NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
        model.msgID = self.msgId;
        model.serviceMsgID = self.smsgId;
        model.chatType = self.ctype;
        model.messageType = self.mtype;
        model.fromID = self.fromUid;
        model.fromNickname = self.nick;
        model.fromIcon = self.icon;
        model.toID = self.toUid;
        model.isAck = self.isAck;
        model.isEncry = self.isEncry;
        model.snapchat = self.snapchat;
        model.sendTime = self.sendTime;
        model.messageSendType = CIMChatMessageSendTypeSuccess;//发送成功
        model.referenceMsgId = self.referenceMsgId;
        model.messageStatus = self.status;
        NSString * sessionID;

        //self.isRead我是否已读别人的消息，或者别人已读我发送的消息
        if (self.ctype == CIMChatType_SingleChat) {
            //单聊
            if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                //我发送的消息，默认我已读
                model.chatMessageReaded = YES;
                sessionID = self.toUid;

            }else {
                //别人发送的消息，我是否已读
                model.chatMessageReaded = self.isRead;
                sessionID = self.fromUid;
            }
            model.totalNeedReadCount = 1;
            model.haveReadCount = self.isRead ? 1 : 0;
        }else if (self.ctype == CIMChatType_GroupChat) {
            //群聊
            if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                //我发送的消息，默认我已读
                model.chatMessageReaded = YES;
            }else {
                //别人发送的消息，我是否已读
                model.chatMessageReaded = self.isRead;
            }
            model.totalNeedReadCount = self.totalNeedReadCount;
            model.haveReadCount = self.haveReadCount;
            sessionID = self.toUid;

        }else {
            CIMLog(@"FFF消息解析未实现的chatType类型:%ld",self.ctype);
        }
        
        model.currentVersionMessageOK = YES;
        NSDictionary *bodyDict = [self.body mj_JSONObject];
        
        switch (self.mtype) {
            case IMChatMessage_MessageType_TextMessage:
            {
                //0文本消息 赋值
                //{"ext":"","content":"1"}
                NoaIMChatMessageModel *chatTextMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                // 离线同步可能返回其他设备编辑后的正文，因此始终以服务端 body 为准。
                NSString *content = [bodyDict objectForKey:@"content"] ?: @"";
                model.textContent = content;
                model.textExt = [bodyDict objectForKey:@"ext"] ?: @"";
                model.translateContent = [bodyDict objectForKey:@"translate"] ?: @"";
                if ([chatTextMessage.textContent isEqualToString:content]) {
                    // 正文未变化时保留本机二次翻译状态，避免离线同步导致译文闪烁。
                    model.translateStatus = chatTextMessage.translateStatus;
                    model.againTranslateContent = chatTextMessage.againTranslateContent;
                    model.localTranslatedShown = chatTextMessage.localTranslatedShown;
                } else {
                    model.againTranslateContent = @"";
                    model.localTranslatedShown = 0;
                }
            }
                break;
            case IMChatMessage_MessageType_ImageMessage:
            {
                //1图片消息 赋值
                //{"ext":"","width":4032,"size":48771072,"name":"/zim/20221121/image/09a6c551bfaa4764912be30c42dc7fb2.jpg","height":3024}
                model.imgHeight = [[bodyDict objectForKey:@"height"] floatValue];
                model.imgWidth = [[bodyDict objectForKey:@"width"] floatValue];
                model.imgSize = [[bodyDict objectForKey:@"size"] floatValue];
                model.imgName = [bodyDict objectForKey:@"name"];
                model.thumbnailImg = [bodyDict objectForKey:@"iImg"];
                model.imgExt = [bodyDict objectForKey:@"ext"];
                
                if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                    //我发送的图片消息
                    NoaIMChatMessageModel *chatImageMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                    if (chatImageMessage) {
                        model.localImgName = chatImageMessage.localImgName;
                    }
                }
                
            }
                break;
            case IMChatMessage_MessageType_VideoMessage:
            {
                //2视频消息 赋值
                //{"ext":"","cWidth":960,"length":46,"name":"/zim/20221121/shortvideo/3555f47d12fa4610b72d91ee444106e6.mp4","cHeight":400,"cImg":"/zim/20221121/image/ad8bec9573a04163b40d1290a5d0eab0.jpg"}
                model.videoCover = [bodyDict objectForKey:@"cImg"];
                model.videoCoverH = [[bodyDict objectForKey:@"cHeight"] floatValue];
                model.videoCoverW = [[bodyDict objectForKey:@"cWidth"] floatValue];
                model.videoLength = [[bodyDict objectForKey:@"length"] floatValue];
                model.videoName = [bodyDict objectForKey:@"name"];
                model.videoExt = [bodyDict objectForKey:@"ext"];
                
                if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                    //我发送的视频消息
                    NoaIMChatMessageModel *chatVideoMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                    if (chatVideoMessage) {
                        model.localVideoName = chatVideoMessage.localVideoName;
                        model.localVideoCover = chatVideoMessage.localVideoCover;
                    }
                }
                
            }
                break;
            case IMChatMessage_MessageType_AtMessage:
            {
                //10 @ 消息 赋值
                //{"ext":"","atInfo":[{"uId":"1595959254546890753","uNick":"AAA"}],"content":"@AAA 123"}
                NoaIMChatMessageModel *chatAtMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                // @ 消息同样使用服务端最新正文和成员列表，支持离线编辑同步。
                NSString *content = [bodyDict objectForKey:@"content"] ?: @"";
                model.atContent = content;
                model.atTranslateContent = [bodyDict objectForKey:@"translate"] ?: @"";
                NSArray *atUserArr = [bodyDict objectForKey:@"atInfo"];
                NSMutableArray *atuserDicList = [NSMutableArray array];
                for (NSDictionary *dict in atUserArr) {
                    NSMutableDictionary *atUsersDict = [NSMutableDictionary dictionary];
                    [atUsersDict setValue:dict[@"uNick"] forKey:dict[@"uId"]];
                    
                    [atuserDicList addObject:atUsersDict];
                }
                model.atUsersInfoList = atuserDicList;
                model.atExt = [bodyDict objectForKey:@"ext"] ?: @"";
                if ([chatAtMessage.atContent isEqualToString:content]) {
                    model.translateStatus = chatAtMessage.translateStatus;
                    model.againAtTranslateContent = chatAtMessage.againAtTranslateContent;
                    model.localTranslatedShown = chatAtMessage.localTranslatedShown;
                } else {
                    model.againAtTranslateContent = @"";
                    model.localTranslatedShown = 0;
                }
            }
                break;
            case IMChatMessage_MessageType_BackMessage:
            {
                //8撤回消息 赋值
                //默认已读
                model.chatMessageReaded = YES;
                model.backDelServiceMsgID = [bodyDict objectForKey:@"sMsgId"];
                model.backDeleteExt = [bodyDict objectForKey:@"ext"];
                model.backDelInformSwitch = [[bodyDict objectForKey:@"informSwitch"] integerValue];
                model.backDelInformUidArray = [bodyDict objectForKey:@"informUid"];
            }
                break;
            case IMChatMessage_MessageType_StickersMessage:
            {
                //12表情消息 赋值
                model.stickersHeight = [[bodyDict objectForKey:@"height"] floatValue];
                model.stickersWidth = [[bodyDict objectForKey:@"width"] floatValue];
                model.stickersSize = [[bodyDict objectForKey:@"size"] floatValue];
                model.stickersName = [bodyDict objectForKey:@"name"];
                model.stickersId = [bodyDict objectForKey:@"id"];
                model.stickersThumbnailImg = [bodyDict objectForKey:@"thumbImg"];
                model.stickersImg = [bodyDict objectForKey:@"img"];
                model.isStickersSet = [[bodyDict objectForKey:@"isStickersSet"] boolValue];
                model.stickersExt = [bodyDict objectForKey:@"ext"];
                
                if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                    //我发送的图片消息
                    NoaIMChatMessageModel *chatImageMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                    if (chatImageMessage) {
                        model.localImgName = chatImageMessage.localImgName;
                    }
                }
            }
                break;
            case IMChatMessage_MessageType_GameStickersMessage:
            {
                //21游戏表情消息 赋值
                model.gameSticekersType = [[bodyDict objectForKey:@"type"] intValue];
                model.gameStickersResut = [bodyDict objectForKey:@"result"];
                model.gameStickersExt = [bodyDict objectForKey:@"ext"];
                
                NoaIMChatMessageModel *localGameStickersMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                if (localGameStickersMessage) {
                    model.isGameAnimationed = localGameStickersMessage.isGameAnimationed;
                }
            }
                break;
            case IMChatMessage_MessageType_BilateralDel:
            {
                //15双向删除消息 赋值
                //默认已读
                model.chatMessageReaded = YES;
                model.textExt = [bodyDict objectForKey:@"ext"];
            }
                break;
            case IMChatMessage_MessageType_FileMessage:
            {
                //5文件类型消息 赋值
                //{"ext":"","path":"/zim/20230411/fileb9ceb45d673f4a10b261f76791ab0dee.mp4","size":6595023,"name":"16088233319293214731681183385164-IMG_0008.mp4","type":"mp4"}
                model.fileName = [bodyDict objectForKey:@"name"];
                model.fileSize = [[bodyDict objectForKey:@"size"] floatValue];
                model.filePath = [bodyDict objectForKey:@"path"];
                model.fileType = [bodyDict objectForKey:@"type"];
                model.fileExt = [bodyDict objectForKey:@"ext"];
                NSRange range = [model.fileName rangeOfString:@"-"];
                if (range.length == 0) {
                    model.showFileName = model.fileName;
                } else {
                    model.showFileName = [model.fileName substringWithRange:NSMakeRange(range.location+1, model.fileName.length - (range.location+1))];
                }
            }
                break;
            case IMChatMessage_MessageType_VoiceMessage:
            {
                //4语音消息 赋值
                model.voiceLength = [[bodyDict objectForKey:@"length"] floatValue];
                model.voiceName = [bodyDict objectForKey:@"name"];
                model.voiceExt = [bodyDict objectForKey:@"ext"];
                if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                    //我发送的视频消息
                    NoaIMChatMessageModel *chatVoiceMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                    if (chatVoiceMessage) {
                        model.localVoiceName = chatVoiceMessage.localVoiceName;
                    }
                }
            
            }
                break;
            case IMChatMessage_MessageType_CardMessage:
            {
                //6名片消息 赋值
               //{"ext":"","headPicUrl":"/zim/avatar/b630c1a5b5df4c16b188312dd0b47cb7.png","nickName":"壹","name":"","userName":"KM111111","userId":"1635912256380682241","url":""}
                model.cardUrl = [bodyDict objectForKey:@"url"];
                model.cardName = [bodyDict objectForKey:@"name"];
                model.cardUserId = [bodyDict objectForKey:@"userId"];
                model.cardHeadPicUrl = [bodyDict objectForKey:@"headPicUrl"];
                model.cardNickName = [bodyDict objectForKey:@"nickName"];
                model.cardUserName = [bodyDict objectForKey:@"userName"];
                model.cardExt = [bodyDict objectForKey:@"ext"];
            }
                break;
            case IMChatMessage_MessageType_GroupNotice:
            {
                //16群公告类型消息 赋值
                //{"ext":"","content":"123456789","noticeId":"189"}
                model.groupNoticeContent = [bodyDict objectForKey:@"content"];
                model.groupNoticeTranslateContent = [bodyDict objectForKey:@"transContent"];
                model.groupNoticeID = [bodyDict objectForKey:@"noticeId"];
                model.groupNoticeExt = [bodyDict objectForKey:@"ext"];
            }
                break;
            case IMChatMessage_MessageType_Geomessage:
            {
                //18 消息记录消息 赋值
                model.geoLng = [bodyDict objectForKey:@"lng"];
                model.geoLat = [bodyDict objectForKey:@"lat"];
                model.geoName = [bodyDict objectForKey:@"name"];
                model.geoImg = [bodyDict objectForKey:@"cImg"];
                model.geoImgHeight = [[bodyDict objectForKey:@"cHeight"] floatValue];
                model.geoImgWidth = [[bodyDict objectForKey:@"cWidth"] floatValue];
                model.geoExt = [bodyDict objectForKey:@"ext"];
                model.geoDetails = [bodyDict objectForKey:@"details"];
                if ([self.fromUid isEqualToString:[DBTOOL myUserID]]) {
                    //我发送的图片消息
                    NoaIMChatMessageModel *chatImageMessage = [IMSDKManager toolGetOneChatMessageWithMessageID:self.msgId sessionID:sessionID];
                    if (chatImageMessage) {
                        model.localGeoImgName = chatImageMessage.localGeoImgName;
                    }
                }
            }
                break;
            case IMChatMessage_MessageType_ForwardMessage:
            {
                //18 多选-合并转发的 消息记录
                ForwardMessage *forwardMessage = [[ForwardMessage alloc] init];
                forwardMessage.type = [[bodyDict objectForKey:@"type"] intValue];
                forwardMessage.title = [bodyDict objectForKey:@"title"];
                forwardMessage.messageListArray = [self getIMChatMessageFormBodyArr:[bodyDict objectForKey:@"messageList"]];
                model.forwardMessageProtobuf = forwardMessage.delimitedData;
            }
                break;
            default:
            {
                model.currentVersionMessageOK = NO;
            }
                
                break;
        }
        return model;
    }else {
        return nil;
    }
}

/** 将历史消息记录中字典格式数据转换成IMChatMessage 只用于转发消息记录中的messageList */
- (NSMutableArray <IMChatMessage *> *)getIMChatMessageFormBodyArr:(NSArray *)bodyMessageArr {
    NSMutableArray <IMChatMessage *> *imChatMessageArr = [[NSMutableArray alloc] init];
    
    for (NSDictionary *dict in bodyMessageArr) {
        NSInteger mType = [[dict objectForKey:@"mType_"] integerValue];
        NSDictionary *bodyDict = (NSDictionary *)[dict objectForKey:@"body_"];
        
        IMChatMessage *imChatMessage = [[IMChatMessage alloc] init];
        imChatMessage.cType = [[dict objectForKey:@"cType_"] integerValue];
        imChatMessage.deviceType = [dict objectForKey:@"deviceType_"];
        imChatMessage.deviceUuid = [dict objectForKey:@"deviceUuid_"];
        imChatMessage.from = [dict objectForKey:@"from_"];
        imChatMessage.icon = [dict objectForKey:@"icon_"];
        imChatMessage.isAck = [[dict objectForKey:@"isAck_"] integerValue];
        imChatMessage.isEncry = [[dict objectForKey:@"isEncry_"] boolValue];
        imChatMessage.mType = [[dict objectForKey:@"mType_"] integerValue];
        imChatMessage.msgId = [dict objectForKey:@"msgId_"];
        imChatMessage.nick = [dict objectForKey:@"nick_"];
        imChatMessage.referenceMsgId = [dict objectForKey:@"referenceMsgId_"];
        imChatMessage.sMsgId = [dict objectForKey:@"sMsgId_"];
        imChatMessage.sendTime = [[dict objectForKey:@"sendTime_"] longLongValue];
        imChatMessage.sessionId = [dict objectForKey:@"sessionId_"];
        imChatMessage.snapchat = [[dict objectForKey:@"snapchat_"] integerValue];
        imChatMessage.toSource = [dict objectForKey:@"toSource_"];
        imChatMessage.toUid = [dict objectForKey:@"toUid_"];
        imChatMessage.to = [dict objectForKey:@"to_"];
        
        switch (mType) {
            case IMChatMessage_MessageType_TextMessage:
            {
                //0文本消息 赋值
                //{"ext_":"","content_":"1"}
                imChatMessage.textMessage.content = [bodyDict objectForKey:@"content_"];
                imChatMessage.textMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_ImageMessage:
            {
                //1图片消息 赋值
                //{"ext":"","width":4032,"size":48771072,"name":"/zim/20221121/image/09a6c551bfaa4764912be30c42dc7fb2.jpg","height":3024}
                imChatMessage.imageMessage.height = [[bodyDict objectForKey:@"height_"] floatValue];
                imChatMessage.imageMessage.width = [[bodyDict objectForKey:@"width_"] floatValue];
                imChatMessage.imageMessage.size = [[bodyDict objectForKey:@"size_"] floatValue];
                imChatMessage.imageMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.imageMessage.iImg = [bodyDict objectForKey:@"iImg_"];
                imChatMessage.imageMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_StickersMessage:
            {
                //12表情消息 赋值
                imChatMessage.stickersMessage.height = [[bodyDict objectForKey:@"height_"] floatValue];
                imChatMessage.stickersMessage.width = [[bodyDict objectForKey:@"width_"] floatValue];
                imChatMessage.stickersMessage.size = [[bodyDict objectForKey:@"size_"] floatValue];
                imChatMessage.stickersMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.stickersMessage.id_p = [bodyDict objectForKey:@"id_"];
                imChatMessage.stickersMessage.thumbImg = [bodyDict objectForKey:@"thumbImg_"];
                imChatMessage.stickersMessage.img = [bodyDict objectForKey:@"img_"];
                imChatMessage.stickersMessage.isStickersSet = [[bodyDict objectForKey:@"isStickersSet_"] boolValue];
                imChatMessage.stickersMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_GameStickersMessage:
            {
                //21游戏表情消息 赋值
                imChatMessage.gameStickersMessage.type = [[bodyDict objectForKey:@"type_"] intValue];
                imChatMessage.gameStickersMessage.result = [bodyDict objectForKey:@"result_"];
                imChatMessage.gameStickersMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
                
                
            case IMChatMessage_MessageType_VideoMessage:
            {
                //2视频消息 赋值
                //{"ext":"","cWidth":960,"length":46,"name":"/zim/20221121/shortvideo/3555f47d12fa4610b72d91ee444106e6.mp4","cHeight":400,"cImg":"/zim/20221121/image/ad8bec9573a04163b40d1290a5d0eab0.jpg"}
                imChatMessage.videoMessage.cImg = [bodyDict objectForKey:@"cImg_"];
                imChatMessage.videoMessage.cHeight = [[bodyDict objectForKey:@"cHeight_"] floatValue];
                imChatMessage.videoMessage.cWidth = [[bodyDict objectForKey:@"cWidth_"] floatValue];
                imChatMessage.videoMessage.length = [[bodyDict objectForKey:@"length_"] floatValue];
                imChatMessage.videoMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.videoMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_AtMessage:
            {
                //10 @ 消息 赋值
                //{"ext":"","atInfo":[{"uId":"1595959254546890753","uNick":"AAA"}],"content":"@AAA 123"}
                imChatMessage.atMessage.content = [bodyDict objectForKey:@"content_"];
                imChatMessage.atMessage.atInfoArray = [bodyDict objectForKey:@"atInfo_"];
                imChatMessage.atMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_FileMessage:
            {
                //5文件类型消息 赋值
                //{"ext":"","path":"/zim/20230411/fileb9ceb45d673f4a10b261f76791ab0dee.mp4","size":6595023,"name":"16088233319293214731681183385164-IMG_0008.mp4","type":"mp4"}
                imChatMessage.fileMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.fileMessage.size = [[bodyDict objectForKey:@"size_"] floatValue];
                imChatMessage.fileMessage.path = [bodyDict objectForKey:@"path_"];
                imChatMessage.fileMessage.type = [bodyDict objectForKey:@"type_"];
                imChatMessage.fileMessage.ext = [bodyDict objectForKey:@"ext_"];
                /*
                NSRange range = [model.fileName rangeOfString:@"-"];
                if (range.length == 0) {
                    model.showFileName = model.fileName;
                } else {
                    model.showFileName = [model.fileName substringWithRange:NSMakeRange(range.location+1, model.fileName.length - (range.location+1))];
                }
                */
            }
                break;
            case IMChatMessage_MessageType_VoiceMessage:
            {
                //4语音消息 赋值
                imChatMessage.voiceMessage.length = [[bodyDict objectForKey:@"length_"] floatValue];
                imChatMessage.voiceMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.voiceMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_CardMessage:
            {
                //6名片消息 赋值
               //{"ext":"","headPicUrl":"/zim/avatar/b630c1a5b5df4c16b188312dd0b47cb7.png","nickName":"壹","name":"","userName":"KM111111","userId":"1635912256380682241","url":""}
                imChatMessage.cardMessage.URL = [bodyDict objectForKey:@"url_"];
                imChatMessage.cardMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.cardMessage.userId = [bodyDict objectForKey:@"userId_"];
                imChatMessage.cardMessage.headPicURL = [bodyDict objectForKey:@"headPicUrl_"];
                imChatMessage.cardMessage.nickName = [bodyDict objectForKey:@"nickName_"];
                imChatMessage.cardMessage.userName = [bodyDict objectForKey:@"userName_"];
                imChatMessage.cardMessage.ext = [bodyDict objectForKey:@"ext_"];
            }
                break;
            case IMChatMessage_MessageType_Geomessage:
            {
                //18 消息记录消息 赋值
                imChatMessage.geoMessage.lng = [bodyDict objectForKey:@"lng_"];
                imChatMessage.geoMessage.lat = [bodyDict objectForKey:@"lat_"];
                imChatMessage.geoMessage.name = [bodyDict objectForKey:@"name_"];
                imChatMessage.geoMessage.cImg = [bodyDict objectForKey:@"cImg_"];
                imChatMessage.geoMessage.cHeight = [[bodyDict objectForKey:@"cHeight_"] floatValue];
                imChatMessage.geoMessage.cWidth = [[bodyDict objectForKey:@"cWidth_"] floatValue];
                imChatMessage.geoMessage.ext = [bodyDict objectForKey:@"ext_"];
                imChatMessage.geoMessage.details = [bodyDict objectForKey:@"details_"];
            }
                break;
            case IMChatMessage_MessageType_ForwardMessage:
            {
                //18 多选-合并转发的 消息记录
                imChatMessage.forwardMessage.type = [[bodyDict objectForKey:@"type_"] intValue];
                imChatMessage.forwardMessage.title = [bodyDict objectForKey:@"title_"];
                imChatMessage.forwardMessage.messageListArray = [self getIMChatMessageFormBodyArr:[bodyDict objectForKey:@"messageList_"]];
            }
                break;
                
            default:
                break;
        }
        [imChatMessageArr addObject:imChatMessage];
    }
    
    return imChatMessageArr;
}


@end
