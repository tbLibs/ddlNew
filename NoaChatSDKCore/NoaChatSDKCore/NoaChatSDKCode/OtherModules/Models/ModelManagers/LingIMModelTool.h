//
//  LingIMModelTool.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

// model转换工具

#import <Foundation/Foundation.h>
#import "NoaIMSDK.h"//sdk头文件

#import "NoaIMChatMessageModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface LingIMModelTool : NSObject
#pragma mark - 单例
+ (instancetype)sharedTool;
//单例一般不需要清空，但是在执行某些功能的时候，防止数据更换不及时，可以清空一下
- (void)clearTool;

#pragma mark - ******业务******
/// 将IMChatMessage转换为数据库存储的LingIMChatMessageModel
/// @param message 聊天消息
- (NoaIMChatMessageModel *)getChatMessageModelFromIMChatMessage:(IMChatMessage *)message;

/// 将LingIMChatMessageModel转换为发送消息的IMChatMessage
/// @param message 聊天消息
- (IMChatMessage *)getChatMessageModelFromLingIMChatMessageModel:(NoaIMChatMessageModel *)message;



/// 汉字转拼音
/// @param chineseCharacters 汉字内容
- (NSString *)chineseTransformWithCharacters:(NSString *)chineseCharacters;

@end

NS_ASSUME_NONNULL_END
