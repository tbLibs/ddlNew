//
//  RecentsEmojiModel.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/27.
//

#import "RecentsEmojiModel+WCTTableCoding.h"
#import "RecentsEmojiModel.h"
#import <WCDBObjc/WCDBObjc.h>

@implementation RecentsEmojiModel

WCDB_IMPLEMENTATION(RecentsEmojiModel)

WCDB_SYNTHESIZE(emojiName)
WCDB_SYNTHESIZE(en)
WCDB_SYNTHESIZE(type)
WCDB_SYNTHESIZE(zhCN)
WCDB_SYNTHESIZE(zhTW)

@end
