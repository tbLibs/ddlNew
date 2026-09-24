//
//  RecentsEmojiModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/27.
//

#import <Foundation/Foundation.h>

@interface RecentsEmojiModel : NSObject

@property (nonatomic, copy) NSString *emojiName;
@property (nonatomic, copy) NSString *en;
@property(nonatomic, assign) NSInteger type;
@property (nonatomic, copy) NSString *zhCN;
@property (nonatomic, copy) NSString *zhTW;

@end

