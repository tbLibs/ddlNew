//
//  NoaIMStickersModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import "NoaIMStickersModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface NoaIMStickersModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(contentUrl)
WCDB_PROPERTY(fileName)
WCDB_PROPERTY(height)
WCDB_PROPERTY(stickersId)
WCDB_PROPERTY(isDeleted)
WCDB_PROPERTY(name)
WCDB_PROPERTY(size)
WCDB_PROPERTY(sort)
WCDB_PROPERTY(stickersKey)
WCDB_PROPERTY(stickersSetId)
WCDB_PROPERTY(thumbUrl)
WCDB_PROPERTY(type)
WCDB_PROPERTY(updateTime)
WCDB_PROPERTY(updateUserName)
WCDB_PROPERTY(userUid)
WCDB_PROPERTY(width)
WCDB_PROPERTY(isStickersSet)
@end
