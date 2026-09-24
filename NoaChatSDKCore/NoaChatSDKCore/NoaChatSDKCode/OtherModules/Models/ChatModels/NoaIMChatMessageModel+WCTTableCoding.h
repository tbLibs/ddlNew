//
//  NoaIMChatMessageModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "NoaIMChatMessageModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface NoaIMChatMessageModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(currentVersionMessageOK)
WCDB_PROPERTY(messageStatus)
WCDB_PROPERTY(messageSendType)
WCDB_PROPERTY(sendFailureReason)
WCDB_PROPERTY(msgID)
WCDB_PROPERTY(serviceMsgID)
WCDB_PROPERTY(chatType)
WCDB_PROPERTY(messageType)
WCDB_PROPERTY(fromID)
WCDB_PROPERTY(fromNickname)
WCDB_PROPERTY(fromIcon)
WCDB_PROPERTY(toID)
WCDB_PROPERTY(isAck)
WCDB_PROPERTY(isEncry)
WCDB_PROPERTY(snapchat)
WCDB_PROPERTY(sendTime)
WCDB_PROPERTY(toSource)
WCDB_PROPERTY(toUid)
WCDB_PROPERTY(chatMessageReaded)
WCDB_PROPERTY(haveReadCount)
WCDB_PROPERTY(totalNeedReadCount)
WCDB_PROPERTY(referenceMsgId)
WCDB_PROPERTY(translateStatus)
WCDB_PROPERTY(textContent)
WCDB_PROPERTY(textExt)
WCDB_PROPERTY(translateContent)
WCDB_PROPERTY(againTranslateContent)
WCDB_PROPERTY(imgHeight)
WCDB_PROPERTY(thumbnailImg)
WCDB_PROPERTY(imgWidth)
WCDB_PROPERTY(imgSize)
WCDB_PROPERTY(imgName)
WCDB_PROPERTY(imgExt)
WCDB_PROPERTY(localImgName)
WCDB_PROPERTY(localthumbImgName)

WCDB_PROPERTY(videoCover)
WCDB_PROPERTY(videoCoverH)
WCDB_PROPERTY(videoCoverW)
WCDB_PROPERTY(videoCoverSize)
WCDB_PROPERTY(videoLength)
WCDB_PROPERTY(videoSize)
WCDB_PROPERTY(videoName)
WCDB_PROPERTY(videoExt)
WCDB_PROPERTY(localVideoName)
WCDB_PROPERTY(localVideoCover)

WCDB_PROPERTY(voiceLength)
WCDB_PROPERTY(voiceName)
WCDB_PROPERTY(voiceExt)
WCDB_PROPERTY(localVoiceName)
WCDB_PROPERTY(localVoicePath)

WCDB_PROPERTY(fileSize)
WCDB_PROPERTY(fileName)
WCDB_PROPERTY(filePath)
WCDB_PROPERTY(fileType)
WCDB_PROPERTY(fileExt)
WCDB_PROPERTY(showFileName)

WCDB_PROPERTY(backDelServiceMsgID)
WCDB_PROPERTY(backDeleteExt)
WCDB_PROPERTY(backDelInformSwitch)
WCDB_PROPERTY(backDelInformUidArray)

WCDB_PROPERTY(atContent)
WCDB_PROPERTY(atUsersInfoList)
WCDB_PROPERTY(atUsersDict)
WCDB_PROPERTY(atExt)
WCDB_PROPERTY(showContent)
WCDB_PROPERTY(atTranslateContent)
WCDB_PROPERTY(againAtTranslateContent)
WCDB_PROPERTY(showTranslateContent)

WCDB_PROPERTY(groupNoticeContent)
WCDB_PROPERTY(groupNoticeTranslateContent)
WCDB_PROPERTY(groupNoticeID)
WCDB_PROPERTY(groupNoticeExt)

//WCDB_PROPERTY(callType)

WCDB_PROPERTY(serverMessageProtobuf)

WCDB_PROPERTY(cardUrl)
WCDB_PROPERTY(cardName)
WCDB_PROPERTY(cardUserId)
WCDB_PROPERTY(cardHeadPicUrl)
WCDB_PROPERTY(cardNickName)
WCDB_PROPERTY(cardUserName)
WCDB_PROPERTY(cardExt)

WCDB_PROPERTY(geoLng)
WCDB_PROPERTY(geoLat)
WCDB_PROPERTY(geoName)
WCDB_PROPERTY(geoImg)
WCDB_PROPERTY(geoImgHeight)
WCDB_PROPERTY(geoImgWidth)
WCDB_PROPERTY(geoExt)
WCDB_PROPERTY(geoDetails)
WCDB_PROPERTY(localGeoImgName)

WCDB_PROPERTY(forwardMessageProtobuf)

WCDB_PROPERTY(systemNoticeTitle)
WCDB_PROPERTY(systemNoticeContent)
WCDB_PROPERTY(systemNoticeImages)

WCDB_PROPERTY(netCallRoomCreateUser)
WCDB_PROPERTY(netCallId)
WCDB_PROPERTY(netCallRoomId)
WCDB_PROPERTY(netCallToken)
WCDB_PROPERTY(netCallType)
WCDB_PROPERTY(netCallTimeout)
WCDB_PROPERTY(netCallChatType)
WCDB_PROPERTY(netCallStatus)
WCDB_PROPERTY(netCallDuration)

WCDB_PROPERTY(stickersHeight)
WCDB_PROPERTY(stickersWidth)
WCDB_PROPERTY(stickersSize)
WCDB_PROPERTY(stickersName)
WCDB_PROPERTY(stickersId)
WCDB_PROPERTY(stickersThumbnailImg)
WCDB_PROPERTY(stickersImg)
WCDB_PROPERTY(isStickersSet)
WCDB_PROPERTY(stickersExt)

WCDB_PROPERTY(gameSticekersType)
WCDB_PROPERTY(gameStickersResut)
WCDB_PROPERTY(gameStickersExt)
WCDB_PROPERTY(isGameAnimationed)

WCDB_PROPERTY(localTranslatedShown)

@end
