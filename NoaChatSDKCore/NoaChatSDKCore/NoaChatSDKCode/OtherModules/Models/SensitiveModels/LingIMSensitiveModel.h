//
//  LingIMSensitiveModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/5.
//

#import <Foundation/Foundation.h>
#import "LingIMSensitiveRecordsModel.h"
#import <MJExtension/MJExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface LingIMSensitiveModel : NSObject

@property (nonatomic, strong) NSArray <LingIMSensitiveRecordsModel *> *records;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) NSInteger size;
@property (nonatomic, assign) NSInteger current;
@property (nonatomic, strong) NSDictionary *orders;
@property (nonatomic, assign) BOOL hitCount;
@property (nonatomic, assign) BOOL searchCount;
@property (nonatomic, assign) NSInteger pages;

@end

NS_ASSUME_NONNULL_END
