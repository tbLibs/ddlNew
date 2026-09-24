//
//  NoaFloatMiniAppModel.h
//  NoaChatSDKCore
//
//  Created by 郑开 on 2024/5/11.
//

#import <Foundation/Foundation.h>


@interface NoaFloatMiniAppModel : NSObject

/// 悬浮id
@property (nonatomic, copy) NSString * floladId;

/// 页面地址
@property (nonatomic, copy) NSString * url;

/// 头像地址
@property (nonatomic, copy) NSString * headerUrl;

/// 标题
@property (nonatomic, copy) NSString * title;

@end

