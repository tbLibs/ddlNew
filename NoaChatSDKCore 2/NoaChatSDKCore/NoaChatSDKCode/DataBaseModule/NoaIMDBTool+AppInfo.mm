//
//  NoaIMDBTool+AppInfo.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

#import "NoaIMDBTool+AppInfo.h"
#import <WCDBObjc/WCDBObjc.h>
#import "LingIMSensitiveRecordsModel+WCTTableCoding.h"//敏感词信息

@implementation NoaIMDBTool (AppInfo)

/// 获取本地缓存的 敏感词(开启状态) 数据
- (NSArray<LingIMSensitiveRecordsModel *> *)getLocalSensitiveWithTableName:(NSString *)tableName {
    
    return [self.noaChatDB getObjectsOfClass:LingIMSensitiveRecordsModel.class fromTable:tableName where: LingIMSensitiveRecordsModel.status == 0];
}

@end
