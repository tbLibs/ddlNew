//
//  NoaIMStickersPackageModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import <Foundation/Foundation.h>
#import "NoaIMStickersModel.h"
#import <MJExtension/MJExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMStickersPackageModel : NSObject

@property (nonatomic, copy) NSString *itemAssetCoverName;
@property (nonatomic, assign) BOOL isSelected;

@property (nonatomic, copy) NSString *coverFile;
@property (nonatomic, copy) NSString *stickersDes;
@property (nonatomic, copy) NSString *packageId;
@property (nonatomic, assign) BOOL isDownLoad;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, assign) NSInteger stickersCount;
@property (nonatomic, strong) NSArray * _Nullable stickersList;
@property (nonatomic, copy) NSString *stickersListJsonStr;
@property (nonatomic, copy) NSString *thumbUrl;
@property (nonatomic, assign) long long updateTime;
@property (nonatomic, copy) NSString *updateUserName;
@property (nonatomic, assign) NSInteger useCount;

@end

NS_ASSUME_NONNULL_END
