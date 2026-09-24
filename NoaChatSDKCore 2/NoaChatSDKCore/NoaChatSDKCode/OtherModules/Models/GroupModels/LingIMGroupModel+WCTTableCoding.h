//
//  LingIMGroupModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import <NoaChatCore/LingIMGroupModel.h>
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMGroupModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(groupId)
WCDB_PROPERTY(groupName)
WCDB_PROPERTY(groupAvatar)
WCDB_PROPERTY(msgTop)
WCDB_PROPERTY(msgNoPromt)
WCDB_PROPERTY(isGroupChat)
WCDB_PROPERTY(isNeedVerify)
WCDB_PROPERTY(isPrivateChat)
WCDB_PROPERTY(groupStatus)
WCDB_PROPERTY(leaveGroupStatus)
WCDB_PROPERTY(isMessageInform)
WCDB_PROPERTY(userGroupRole)
WCDB_PROPERTY(memberCount)
WCDB_PROPERTY(lastSyncMemberTime)
WCDB_PROPERTY(lastSyncActiviteScoreime)
WCDB_PROPERTY(isShowHistory)
WCDB_PROPERTY(groupInformStatus)
WCDB_PROPERTY(closeSearchUser)
WCDB_PROPERTY(canMsgTime)
WCDB_PROPERTY(isActiveEnabled)
WCDB_PROPERTY(isNetCall)

@end
