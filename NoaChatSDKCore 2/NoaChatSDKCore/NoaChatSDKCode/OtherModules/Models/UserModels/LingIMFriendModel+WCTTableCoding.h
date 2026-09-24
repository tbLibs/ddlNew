//
//  LingIMFriendModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "LingIMFriendModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMFriendModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(friendUserUID)
WCDB_PROPERTY(userName)
WCDB_PROPERTY(nickname)
WCDB_PROPERTY(nicknamePinyin);
WCDB_PROPERTY(avatar)
WCDB_PROPERTY(msgTop)
WCDB_PROPERTY(msgNoPromt)
WCDB_PROPERTY(onlineStatus)
WCDB_PROPERTY(remarks)
WCDB_PROPERTY(remarksPinyin);
WCDB_PROPERTY(descRemark)
WCDB_PROPERTY(disableStatus)
WCDB_PROPERTY(userType)
WCDB_PROPERTY(showName)
WCDB_PROPERTY(ugUuid)
WCDB_PROPERTY(roleId)
WCDB_PROPERTY(canMsgTime)


@end
