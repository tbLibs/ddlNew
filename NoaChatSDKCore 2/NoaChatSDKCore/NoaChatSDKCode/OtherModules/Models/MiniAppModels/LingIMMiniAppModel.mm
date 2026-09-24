//
//  LingIMMiniAppModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/21.
//

#import "LingIMMiniAppModel+WCTTableCoding.h"
#import "LingIMMiniAppModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMMiniAppModel

WCDB_IMPLEMENTATION(LingIMMiniAppModel)

WCDB_PRIMARY(qaUuid)//定义主键

WCDB_SYNTHESIZE(qaUuid)
WCDB_SYNTHESIZE(qaAppPic)
WCDB_SYNTHESIZE(qaAppUrl)
WCDB_SYNTHESIZE(qaName)
WCDB_SYNTHESIZE(qaPwdOpen)
WCDB_SYNTHESIZE(qaCreateDateTime)
WCDB_SYNTHESIZE(qaUpdateDateTime)
WCDB_SYNTHESIZE(qaOwnerUid)
  
@end
