//
//  NoaIMStickersPackageModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import "NoaIMStickersPackageModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface NoaIMStickersPackageModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(coverFile)
WCDB_PROPERTY(stickersDes)
WCDB_PROPERTY(packageId)
WCDB_PROPERTY(isDownLoad)
WCDB_PROPERTY(isDeleted)
WCDB_PROPERTY(name)
WCDB_PROPERTY(status)
WCDB_PROPERTY(stickersCount)
//WCDB_PROPERTY(stickersList)
WCDB_PROPERTY(stickersListJsonStr)
WCDB_PROPERTY(thumbUrl)
WCDB_PROPERTY(updateTime)
WCDB_PROPERTY(updateUserName)
WCDB_PROPERTY(useCount)

@end
