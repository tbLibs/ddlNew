//
//  LingIMFriendModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/25.
//

#import "LingIMFriendModel+WCTTableCoding.h"
#import "LingIMFriendModel.h"
#import "LXChatEncrypt.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMFriendModel

WCDB_IMPLEMENTATION(LingIMFriendModel)

WCDB_PRIMARY(friendUserUID)//主键
WCDB_SYNTHESIZE(friendUserUID)
WCDB_SYNTHESIZE(userName)
WCDB_SYNTHESIZE(nickname)
WCDB_SYNTHESIZE(nicknamePinyin);
WCDB_SYNTHESIZE(avatar)
WCDB_SYNTHESIZE(msgTop)
WCDB_SYNTHESIZE(msgNoPromt)
WCDB_SYNTHESIZE(onlineStatus)
WCDB_SYNTHESIZE(remarks)
WCDB_SYNTHESIZE(remarksPinyin);
WCDB_SYNTHESIZE(descRemark)

WCDB_SYNTHESIZE(disableStatus)
WCDB_DEFAULT(disableStatus, -1)
WCDB_SYNTHESIZE(userType)
WCDB_DEFAULT(userType, -1)

WCDB_SYNTHESIZE(showName)
WCDB_SYNTHESIZE(ugUuid)
WCDB_SYNTHESIZE(roleId)
WCDB_SYNTHESIZE(canMsgTime)


-(NSString *)showName{
    if(self.remarks.length > 0){
        return self.remarks;
    }
    if(self.nickname.length > 0){
        return self.nickname;
    }
    return self.nickname;
}


@end
