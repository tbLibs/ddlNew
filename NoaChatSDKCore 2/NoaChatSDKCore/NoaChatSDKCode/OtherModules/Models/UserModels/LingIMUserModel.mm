//
//  LingIMUserModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "LingIMUserModel+WCTTableCoding.h"
#import "LingIMUserModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMUserModel

WCDB_IMPLEMENTATION(LingIMUserModel)

WCDB_PRIMARY(userUID)//主键
WCDB_SYNTHESIZE(userUID)
WCDB_SYNTHESIZE(userNickname)
WCDB_SYNTHESIZE(userAccount)
WCDB_SYNTHESIZE(userAvatar)
WCDB_SYNTHESIZE(userRemark)
WCDB_SYNTHESIZE(myFriend)
WCDB_SYNTHESIZE(roleId)

  
@end
