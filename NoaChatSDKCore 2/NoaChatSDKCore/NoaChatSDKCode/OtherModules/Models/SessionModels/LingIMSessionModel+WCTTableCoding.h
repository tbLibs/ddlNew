//
//  LingIMSessionModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "LingIMSessionModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMSessionModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(sessionID)
WCDB_PROPERTY(sessionName)
WCDB_PROPERTY(sessionAvatar)
WCDB_PROPERTY(sessionType)
WCDB_PROPERTY(sessionGroupType)
WCDB_PROPERTY(sessionTop)
WCDB_PROPERTY(sessionNoDisturb)
WCDB_PROPERTY(readTag)
WCDB_PROPERTY(sessionTopTime)
WCDB_PROPERTY(sessionUnreadCount)
WCDB_PROPERTY(sessionTableName)
WCDB_PROPERTY(sessionLatestTime)
WCDB_PROPERTY(sessionLatestServerMsgID)
WCDB_PROPERTY(draftDict)
WCDB_PROPERTY(sessionStatus)
WCDB_PROPERTY(lastSendMsgTime)
WCDB_PROPERTY(roleId)
WCDB_PROPERTY(isReceiveAutoTranslate)
WCDB_PROPERTY(receiveTranslateChannel)
WCDB_PROPERTY(receiveTranslateChannelName)
WCDB_PROPERTY(receiveTranslateLanguage)
WCDB_PROPERTY(receiveTranslateLanguageName)
WCDB_PROPERTY(isSendAutoTranslate)
WCDB_PROPERTY(sendTranslateChannel)
WCDB_PROPERTY(sendTranslateChannelName)
WCDB_PROPERTY(sendTranslateLanguage)
WCDB_PROPERTY(sendTranslateLanguageName)
WCDB_PROPERTY(translateConfigId)


@end
