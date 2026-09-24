//
//  LingIMGroupModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "LingIMGroupModel+WCTTableCoding.h"
#import <NoaChatCore/LingIMGroupModel.h>
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMGroupModel

WCDB_IMPLEMENTATION(LingIMGroupModel)

WCDB_PRIMARY(groupId)//主键

WCDB_SYNTHESIZE(groupId)
WCDB_SYNTHESIZE(groupName)
WCDB_SYNTHESIZE(groupAvatar)
WCDB_SYNTHESIZE(msgTop)
WCDB_SYNTHESIZE(msgNoPromt)
WCDB_SYNTHESIZE(isGroupChat)
WCDB_SYNTHESIZE(isNeedVerify)
WCDB_SYNTHESIZE(isPrivateChat)
WCDB_SYNTHESIZE(groupStatus)
WCDB_SYNTHESIZE(leaveGroupStatus)
WCDB_SYNTHESIZE(isMessageInform)
WCDB_SYNTHESIZE(userGroupRole)
WCDB_SYNTHESIZE(memberCount)
WCDB_SYNTHESIZE(lastSyncMemberTime)
WCDB_SYNTHESIZE(lastSyncActiviteScoreime)
WCDB_SYNTHESIZE(isShowHistory)
WCDB_SYNTHESIZE(groupInformStatus)
WCDB_SYNTHESIZE(closeSearchUser)
WCDB_SYNTHESIZE(canMsgTime)
WCDB_SYNTHESIZE(isActiveEnabled)
WCDB_SYNTHESIZE(isNetCall)



@end
