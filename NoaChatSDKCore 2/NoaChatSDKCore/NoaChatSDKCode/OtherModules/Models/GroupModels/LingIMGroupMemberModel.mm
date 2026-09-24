//
//  LingIMGroupModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/7.
//

#import "LingIMGroupMemberModel+WCTTableCoding.h"
#import <NoaChatCore/LingIMGroupMemberModel.h>
#import "LXChatEncrypt.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMGroupMemberModel

WCDB_IMPLEMENTATION(LingIMGroupMemberModel)

WCDB_PRIMARY(userUid)//主键

WCDB_SYNTHESIZE(userUid)
WCDB_SYNTHESIZE(areMyFriend)
WCDB_SYNTHESIZE(joinTime)
WCDB_SYNTHESIZE(nicknameInGroup)
WCDB_SYNTHESIZE(role)
WCDB_SYNTHESIZE(userAvatar)
WCDB_SYNTHESIZE(userName)
WCDB_SYNTHESIZE(userNickname)
WCDB_SYNTHESIZE(remarks)
WCDB_SYNTHESIZE(descRemark)
WCDB_SYNTHESIZE(disableStatus)
WCDB_SYNTHESIZE(memberIsInGroup)
WCDB_SYNTHESIZE(showName)
WCDB_SYNTHESIZE(roleId)
WCDB_SYNTHESIZE(isDel)
WCDB_SYNTHESIZE(activityScroe)
WCDB_SYNTHESIZE(latestUpdateTime)


-(NSString *)showName{
    if(self.remarks.length > 0){
        return self.remarks;
    }
    if(self.nicknameInGroup.length > 0){
        return self.nicknameInGroup;
    }
    return self.userNickname;
}


@end
