//
//  NoaFloatMiniAppModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by 郑开 on 2024/5/11.
//

#import "NoaFloatMiniAppModel.h"
#import <WCDBObjc/WCDBObjc.h>



@interface NoaFloatMiniAppModel (WCTTableCoding)<WCTTableCoding>

WCDB_PROPERTY(floladId);
WCDB_PROPERTY(url);
WCDB_PROPERTY(headerUrl);
WCDB_PROPERTY(title);

@end


