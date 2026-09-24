//
//  NoaIMChatMessageModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "NoaIMChatMessageModel+WCTTableCoding.h"
#import "NoaIMChatMessageModel.h"


@implementation NoaIMChatMessageModel

WCDB_IMPLEMENTATION(NoaIMChatMessageModel)

WCDB_PRIMARY(msgID)//定义主键

WCDB_SYNTHESIZE(currentVersionMessageOK)
// 把原来的 WCDB_SYNTHESIZE(messageStatus) 替换为带默认值的宏
WCDB_SYNTHESIZE(messageStatus)
WCDB_DEFAULT(messageStatus, 1)

WCDB_SYNTHESIZE(messageSendType)
WCDB_SYNTHESIZE(sendFailureReason)
WCDB_DEFAULT(sendFailureReason, 0)
WCDB_SYNTHESIZE(msgID)
WCDB_SYNTHESIZE(serviceMsgID)
WCDB_SYNTHESIZE(chatType)
WCDB_SYNTHESIZE(messageType)
WCDB_SYNTHESIZE(fromID)
WCDB_SYNTHESIZE(fromNickname)
WCDB_SYNTHESIZE(fromIcon)
WCDB_SYNTHESIZE(toID)
WCDB_SYNTHESIZE(isAck)
WCDB_SYNTHESIZE(isEncry)
WCDB_SYNTHESIZE(snapchat)
WCDB_SYNTHESIZE(sendTime)
WCDB_SYNTHESIZE(toSource)
WCDB_SYNTHESIZE(toUid)
WCDB_SYNTHESIZE(chatMessageReaded)
WCDB_SYNTHESIZE(haveReadCount)
WCDB_SYNTHESIZE(totalNeedReadCount)
WCDB_SYNTHESIZE(referenceMsgId)
WCDB_SYNTHESIZE(translateStatus)
WCDB_SYNTHESIZE(textContent)
WCDB_SYNTHESIZE(textExt)
WCDB_SYNTHESIZE(translateContent)
WCDB_SYNTHESIZE(againTranslateContent)

WCDB_SYNTHESIZE(imgHeight)
WCDB_SYNTHESIZE(thumbnailImg)
WCDB_SYNTHESIZE(imgWidth)
WCDB_SYNTHESIZE(imgSize)
WCDB_SYNTHESIZE(imgName)
WCDB_SYNTHESIZE(imgExt)
WCDB_SYNTHESIZE(localImgName)
WCDB_SYNTHESIZE(localthumbImgName)

WCDB_SYNTHESIZE(videoCover)
WCDB_SYNTHESIZE(videoCoverH)
WCDB_SYNTHESIZE(videoCoverW)
WCDB_SYNTHESIZE(videoCoverSize)
WCDB_SYNTHESIZE(videoLength)
WCDB_SYNTHESIZE(videoSize)
WCDB_SYNTHESIZE(videoName)
WCDB_SYNTHESIZE(videoExt)
WCDB_SYNTHESIZE(localVideoName)
WCDB_SYNTHESIZE(localVideoCover)

WCDB_SYNTHESIZE(voiceLength)
WCDB_SYNTHESIZE(voiceName)
WCDB_SYNTHESIZE(voiceExt)
WCDB_SYNTHESIZE(localVoiceName)
WCDB_SYNTHESIZE(localVoicePath)


WCDB_SYNTHESIZE(fileSize)
WCDB_SYNTHESIZE(fileName)
WCDB_SYNTHESIZE(filePath)
WCDB_SYNTHESIZE(fileType)
WCDB_SYNTHESIZE(fileExt)
WCDB_SYNTHESIZE(showFileName)

WCDB_SYNTHESIZE(backDelServiceMsgID)
WCDB_SYNTHESIZE(backDeleteExt)
WCDB_SYNTHESIZE(backDelInformSwitch)
WCDB_SYNTHESIZE(backDelInformUidArray)

WCDB_SYNTHESIZE(atContent)
WCDB_SYNTHESIZE(atUsersInfoList)
WCDB_SYNTHESIZE(atUsersDict)
WCDB_SYNTHESIZE(atExt)
WCDB_SYNTHESIZE(showContent)
WCDB_SYNTHESIZE(atTranslateContent)
WCDB_SYNTHESIZE(againAtTranslateContent)
WCDB_SYNTHESIZE(showTranslateContent)

WCDB_SYNTHESIZE(groupNoticeContent)
WCDB_SYNTHESIZE(groupNoticeTranslateContent)
WCDB_SYNTHESIZE(groupNoticeID)
WCDB_SYNTHESIZE(groupNoticeExt)

//WCDB_SYNTHESIZ, callType)

WCDB_SYNTHESIZE(serverMessageProtobuf)

WCDB_SYNTHESIZE(cardUrl)
WCDB_SYNTHESIZE(cardName)
WCDB_SYNTHESIZE(cardUserId)
WCDB_SYNTHESIZE(cardHeadPicUrl)
WCDB_SYNTHESIZE(cardNickName)
WCDB_SYNTHESIZE(cardUserName)
WCDB_SYNTHESIZE(cardExt)

WCDB_SYNTHESIZE(geoLng)
WCDB_SYNTHESIZE(geoLat)
WCDB_SYNTHESIZE(geoName)
WCDB_SYNTHESIZE(geoImg)
WCDB_SYNTHESIZE(geoImgHeight)
WCDB_SYNTHESIZE(geoImgWidth)
WCDB_SYNTHESIZE(geoExt)
WCDB_SYNTHESIZE(geoDetails)
WCDB_SYNTHESIZE(localGeoImgName)

WCDB_SYNTHESIZE(forwardMessageProtobuf)


WCDB_SYNTHESIZE(systemNoticeTitle)
WCDB_SYNTHESIZE(systemNoticeContent)
WCDB_SYNTHESIZE(systemNoticeImages)

WCDB_SYNTHESIZE(netCallRoomCreateUser)
WCDB_SYNTHESIZE(netCallId)
WCDB_SYNTHESIZE(netCallRoomId)
WCDB_SYNTHESIZE(netCallToken)
WCDB_SYNTHESIZE(netCallType)
WCDB_SYNTHESIZE(netCallTimeout)
WCDB_SYNTHESIZE(netCallChatType)
WCDB_SYNTHESIZE(netCallStatus)
WCDB_SYNTHESIZE(netCallDuration)

WCDB_SYNTHESIZE(stickersHeight)
WCDB_SYNTHESIZE(stickersWidth)
WCDB_SYNTHESIZE(stickersSize)
WCDB_SYNTHESIZE(stickersName)
WCDB_SYNTHESIZE(stickersId)
WCDB_SYNTHESIZE(stickersThumbnailImg)
WCDB_SYNTHESIZE(stickersImg)
WCDB_SYNTHESIZE(isStickersSet)
WCDB_SYNTHESIZE(stickersExt)

WCDB_SYNTHESIZE(gameSticekersType)
WCDB_SYNTHESIZE(gameStickersResut)
WCDB_SYNTHESIZE(gameStickersExt)
WCDB_SYNTHESIZE(isGameAnimationed)

WCDB_SYNTHESIZE(localTranslatedShown)


//获得系统通知消息内容
- (IMServerMessage *)serverMessage {
    if (self.serverMessageProtobuf) {
        GPBCodedInputStream *stream = [GPBCodedInputStream streamWithData:self.serverMessageProtobuf];
        IMServerMessage *message = [IMServerMessage parseDelimitedFromCodedInputStream:stream extensionRegistry:nil error:nil];
        return message;
    }
    return nil;
}

//获得系统通知消息内容
- (ForwardMessage *)forwardMessage {
    if (_forwardMessage != nil) {
        return _forwardMessage;
    } else {
        if (self.forwardMessageProtobuf) {
            GPBCodedInputStream *stream = [GPBCodedInputStream streamWithData:self.forwardMessageProtobuf];
            ForwardMessage *message = [ForwardMessage parseDelimitedFromCodedInputStream:stream extensionRegistry:nil error:nil];
            return message;
        }
        return nil;
    }
}
  
@end
