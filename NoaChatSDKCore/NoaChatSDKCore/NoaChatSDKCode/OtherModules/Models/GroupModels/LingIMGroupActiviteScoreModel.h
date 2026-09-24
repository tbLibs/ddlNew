//
//  LingIMGroupActiviteScoreModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2025/2/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LingIMGroupActiviteScoreModel : NSObject

@property (nonatomic, assign) NSInteger activityScore;//活跃积分
@property (nonatomic, assign) NSInteger dailyScore;//今日获取积分
@property (nonatomic, copy) NSString *memberUid;//群成员userId

@end

NS_ASSUME_NONNULL_END
