//
//  LingIMFriendGroupModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

#import "LingIMFriendGroupModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMFriendGroupModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(ugUuid)
WCDB_PROPERTY(ugName)
WCDB_PROPERTY(ugUpdateDateTime)
WCDB_PROPERTY(ugOrder)
WCDB_PROPERTY(ugType)

@end
