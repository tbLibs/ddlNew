//
//  LingIMSessionModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "LingIMSessionModel+WCTTableCoding.h"
#import "LingIMSessionModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMSessionModel

WCDB_IMPLEMENTATION(LingIMSessionModel)

WCDB_PRIMARY(sessionID)//主键
WCDB_SYNTHESIZE(sessionID)
WCDB_SYNTHESIZE(sessionName)
WCDB_SYNTHESIZE(sessionAvatar)
WCDB_SYNTHESIZE(sessionType)
WCDB_SYNTHESIZE(sessionGroupType)
WCDB_SYNTHESIZE(sessionTop)
WCDB_SYNTHESIZE(sessionNoDisturb)
WCDB_SYNTHESIZE(readTag)
WCDB_SYNTHESIZE(sessionTopTime)
WCDB_SYNTHESIZE(sessionUnreadCount)
WCDB_SYNTHESIZE(sessionTableName)
WCDB_SYNTHESIZE(sessionLatestTime)
WCDB_SYNTHESIZE(sessionLatestServerMsgID)
WCDB_SYNTHESIZE(draftDict)
WCDB_SYNTHESIZE(sessionStatus)
//WCDB_SYNTHESIZ, sessionLatestMessage)
WCDB_SYNTHESIZE(lastSendMsgTime)
WCDB_SYNTHESIZE(roleId)
WCDB_SYNTHESIZE(isReceiveAutoTranslate)
WCDB_SYNTHESIZE(receiveTranslateChannel)
WCDB_SYNTHESIZE(receiveTranslateChannelName)
WCDB_SYNTHESIZE(receiveTranslateLanguage)
WCDB_SYNTHESIZE(receiveTranslateLanguageName)
WCDB_SYNTHESIZE(isSendAutoTranslate)
WCDB_SYNTHESIZE(sendTranslateChannel)
WCDB_SYNTHESIZE(sendTranslateChannelName)
WCDB_SYNTHESIZE(sendTranslateLanguage)
WCDB_SYNTHESIZE(sendTranslateLanguageName)
WCDB_SYNTHESIZE(translateConfigId)


- (instancetype)copyWithZone:(NSZone *)zone {
    
    LingIMSessionModel *model = [[LingIMSessionModel allocWithZone:zone] init];
    model.sessionID = self.sessionID;
    model.sessionName = self.sessionName;
    model.sessionAvatar = self.sessionAvatar;
    model.sessionType = self.sessionType;
    model.sessionGroupType = self.sessionGroupType;
    model.sessionTop = self.sessionTop;
    model.sessionNoDisturb = self.sessionNoDisturb;
    model.readTag = self.readTag;
    model.sessionTableName = self.sessionTableName;
    model.sessionTopTime = self.sessionTopTime;
    model.sessionUnreadCount = self.sessionUnreadCount;
    model.sessionLatestTime = self.sessionLatestTime;
    model.sessionLatestServerMsgID = self.sessionLatestServerMsgID;
    model.draftDict = self.draftDict;
    model.sessionStatus = self.sessionStatus;
    model.sessionLatestMessage = self.sessionLatestMessage;
    model.sessionLatestMassMessage = self.sessionLatestMassMessage;
    model.isSelected = self.isSelected;
    model.lastSendMsgTime = self.lastSendMsgTime;
    model.roleId = self.roleId;
    model.isSendAutoTranslate = self.isSendAutoTranslate;
    model.sendTranslateChannel = self.sendTranslateChannel;
    model.sendTranslateChannelName = self.sendTranslateChannelName;
    model.sendTranslateLanguage = self.sendTranslateLanguage;
    model.sendTranslateLanguageName = self.sendTranslateLanguageName;
    model.isReceiveAutoTranslate = self.isReceiveAutoTranslate;
    model.receiveTranslateChannel = self.receiveTranslateChannel;
    model.receiveTranslateChannelName = self.receiveTranslateChannelName;
    model.receiveTranslateLanguage = self.receiveTranslateLanguage;
    model.receiveTranslateLanguageName = self.receiveTranslateLanguageName;
    model.translateConfigId = self.translateConfigId;

    return model;
    
}

- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [self copyWithZone:zone];
}
@end
