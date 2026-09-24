//
//  LingIMUserModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "LingIMUserModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMUserModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(userUID)
WCDB_PROPERTY(userNickname)
WCDB_PROPERTY(userAccount)
WCDB_PROPERTY(userAvatar)
WCDB_PROPERTY(userRemark)
WCDB_PROPERTY(myFriend)
WCDB_PROPERTY(roleId)

@end
