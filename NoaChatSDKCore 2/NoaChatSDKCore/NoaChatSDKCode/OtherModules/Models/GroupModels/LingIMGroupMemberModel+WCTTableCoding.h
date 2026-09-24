//
//  LingIMGroupModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import <NoaChatCore/LingIMGroupMemberModel.h>
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMGroupMemberModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(userUid)
WCDB_PROPERTY(areMyFriend)
WCDB_PROPERTY(joinTime)
WCDB_PROPERTY(nicknameInGroup)
WCDB_PROPERTY(role)
WCDB_PROPERTY(userAvatar)
WCDB_PROPERTY(userName)
WCDB_PROPERTY(userNickname)
WCDB_PROPERTY(remarks)
WCDB_PROPERTY(descRemark)
WCDB_PROPERTY(disableStatus)
WCDB_PROPERTY(showName)
WCDB_PROPERTY(memberIsInGroup)
WCDB_PROPERTY(roleId)
WCDB_PROPERTY(isDel)
WCDB_PROPERTY(activityScroe)
WCDB_PROPERTY(latestUpdateTime)

@end
