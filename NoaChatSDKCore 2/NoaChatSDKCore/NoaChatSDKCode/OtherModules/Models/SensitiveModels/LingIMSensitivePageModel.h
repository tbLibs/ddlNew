//
//  LingIMSensitivePageModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

#import <Foundation/Foundation.h>
#import "LingIMSensitiveModel.h"
#import <MJExtension/MJExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface LingIMSensitivePageModel : NSObject

@property (nonatomic, strong) LingIMSensitiveModel *page;
@property (nonatomic, copy) NSString *updateTime;//更新日期时间

@end

NS_ASSUME_NONNULL_END
