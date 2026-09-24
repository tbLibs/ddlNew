//
//  NoaIMChatMessageModel+WCTColumnCoding.mm
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/26.
//

#import "NoaIMChatMessageModel.h"
#import <Foundation/Foundation.h>
#import <WCDBObjc/WCDBObjc.h>

@interface NoaIMChatMessageModel (WCTColumnCoding) <WCTColumnCoding>
@end

@implementation NoaIMChatMessageModel (WCTColumnCoding)

//+ (instancetype)unarchiveWithWCTValue:(NSString *)value
//{
//    if (value) {
//        @try {
//            LingIMChatMessageModel *model = [LingIMChatMessageModel mj_objectWithKeyValues:value];
//            return model;
//        } @catch (NSException *exception) {
//            NSLog(@"CIMMessageModel exception:%@",[exception description]);
//        } @finally {
//            //CIMLog(@"始终执行的语句");
//            //不管什么情况都会执行，包括 try catch 里面用了 return.
//            //此处不能用return，否则会有程序退出的危险
//        }
//    }
//    return nil;
//}
//
//- (NSString *)archivedWCTValue
//{
//    NSString *jsonStr = [self mj_JSONString];
//    return [NSString stringWithString:jsonStr];
//}
//
//+ (WCTColumnType)columnTypeForWCDB
//{
//    return WCTColumnTypeString;
//}

+ (instancetype)unarchiveWithWCTValue:(NSData *)value
{
    if (value) {
        @try {
            NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData:value];
            NoaIMChatMessageModel *model = [NoaIMChatMessageModel mj_objectWithKeyValues:dict];
            return model;
        } @catch (NSException *exception) {
            NSLog(@"CIMMessageModel exception:%@",[exception description]);
        } @finally {
            //CIMLog(@"始终执行的语句");
            //不管什么情况都会执行，包括 try catch 里面用了 return.
            //此处不能用return，否则会有程序退出的危险
        }
    }
    return nil;
}

- (NSData *)archivedWCTValue
{
    NSDictionary *modelDict = [self mj_JSONObject];
    NSData *modelData = [NSKeyedArchiver archivedDataWithRootObject:modelDict];
    return modelData;
}

+ (WCTColumnType)columnTypeForWCDB
{
    return WCTColumnTypeData;
}

@end
