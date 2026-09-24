//
//  LingIMSensitiveRecordsModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/12.
//

#import "LingIMSensitiveRecordsModel+WCTTableCoding.h"
#import "LingIMSensitiveRecordsModel.h"
#import "LXChatEncrypt.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation LingIMSensitiveRecordsModel

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"keyId" : @"id",
    };
}

WCDB_IMPLEMENTATION(LingIMSensitiveRecordsModel)

WCDB_PRIMARY(keyId)//主键

WCDB_SYNTHESIZE(filterType)
WCDB_SYNTHESIZE(keyId)
WCDB_SYNTHESIZE(sceneType)
WCDB_SYNTHESIZE(status)
WCDB_SYNTHESIZE(updateTime)
WCDB_SYNTHESIZE(wordText)
WCDB_SYNTHESIZE(decodeWordText)

- (void)setWordText:(NSString *)wordText {
    _wordText = wordText;
    if (_wordText.length > 0) {
        //现将wordText密文解密存入decodeWordText
        _decodeWordText = [LXChatEncrypt method2:_wordText];
    }
}
  
@end
