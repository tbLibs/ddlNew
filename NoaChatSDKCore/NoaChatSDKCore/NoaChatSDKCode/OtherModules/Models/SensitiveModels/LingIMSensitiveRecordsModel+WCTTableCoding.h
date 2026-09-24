//
//  LingIMSensitiveRecordsModel+WCTTableCoding.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/12.
//

#import "LingIMSensitiveRecordsModel.h"
#import <WCDBObjc/WCDBObjc.h>

@interface LingIMSensitiveRecordsModel (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(filterType)
WCDB_PROPERTY(keyId)
WCDB_PROPERTY(sceneType)
WCDB_PROPERTY(status)
WCDB_PROPERTY(updateTime)
WCDB_PROPERTY(wordText)
WCDB_PROPERTY(decodeWordText)


@end
