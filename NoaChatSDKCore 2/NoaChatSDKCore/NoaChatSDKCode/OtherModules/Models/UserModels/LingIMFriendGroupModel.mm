//
//  LingIMFriendGroupModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

#import "LingIMFriendGroupModel+WCTTableCoding.h"
#import "LingIMFriendGroupModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMFriendGroupModel

WCDB_IMPLEMENTATION(LingIMFriendGroupModel)

WCDB_PRIMARY(ugUuid)//主键

WCDB_SYNTHESIZE(ugUuid)
WCDB_SYNTHESIZE(ugName)
WCDB_SYNTHESIZE(ugUpdateDateTime)
WCDB_SYNTHESIZE(ugOrder)
WCDB_SYNTHESIZE(ugType)
  
@end
