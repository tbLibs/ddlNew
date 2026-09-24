//
//  LingIMMiniAppModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/21.
//

#import "LingIMMiniAppModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMMiniAppModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(qaUuid)
WCDB_PROPERTY(qaAppPic)
WCDB_PROPERTY(qaAppUrl)
WCDB_PROPERTY(qaName)
WCDB_PROPERTY(qaPwdOpen)
WCDB_PROPERTY(qaCreateDateTime)
WCDB_PROPERTY(qaUpdateDateTime)
WCDB_PROPERTY(qaOwnerUid)

@end
