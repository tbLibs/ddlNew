//
//  NoaIMStickersModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/30.
//

#import <Foundation/Foundation.h>

@interface NoaIMStickersModel : NSObject

@property (nonatomic, copy) NSString *assetAddIcon;

@property (nonatomic, copy) NSString *contentUrl;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, assign) float height;
@property (nonatomic, copy) NSString *stickersId;
@property (nonatomic, assign) BOOL isDeleted;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) float size;
@property (nonatomic, assign) long long sort;
@property (nonatomic, copy) NSString *stickersKey;
@property (nonatomic, copy)NSString *stickersSetId;
@property (nonatomic, copy) NSString *thumbUrl;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign) long long updateTime;
@property (nonatomic, copy) NSString *updateUserName;
@property (nonatomic, copy) NSString *userUid;
@property (nonatomic, assign) float width;
@property (nonatomic, assign) BOOL isStickersSet;

@end

