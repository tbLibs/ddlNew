//
//  LIMMediaCallRoomInfoModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/2/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LIMMediaCallRoomInfoModel : NSObject
@property (nonatomic, copy) NSString *endpoint;//房间地址
@property (nonatomic, copy) NSString *room;//房间id
@property (nonatomic, copy) NSString *token;//房间token
@end

NS_ASSUME_NONNULL_END
