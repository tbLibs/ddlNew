//
//  NoaFloatMiniAppModel+WCTTableCoding.m
//  NoaChatSDKCore
//
//  Created by 郑开 on 2024/5/11.
//

#import "NoaFloatMiniAppModel+WCTTableCoding.h"

@implementation NoaFloatMiniAppModel (WCTTableCoding)


WCDB_IMPLEMENTATION(NoaFloatMiniAppModel)

WCDB_PRIMARY(floladId)//定义主键

WCDB_SYNTHESIZE(floladId)
WCDB_SYNTHESIZE(url)
WCDB_SYNTHESIZE(headerUrl)
WCDB_SYNTHESIZE(title)
  

@end
