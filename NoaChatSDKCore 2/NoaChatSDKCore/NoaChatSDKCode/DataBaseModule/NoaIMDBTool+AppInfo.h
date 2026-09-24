//
//  NoaIMDBTool+AppInfo.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

#import "NoaIMDBTool.h"
#import "LingIMSensitiveRecordsModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMDBTool (AppInfo)

/// 获取本地缓存的 敏感词(开启状态) 数据
- (NSArray<LingIMSensitiveRecordsModel *> *)getLocalSensitiveWithTableName:(NSString *)tableName;

@end

NS_ASSUME_NONNULL_END
