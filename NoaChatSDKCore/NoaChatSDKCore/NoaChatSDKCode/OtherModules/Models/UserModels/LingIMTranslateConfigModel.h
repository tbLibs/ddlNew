//
//  LingIMTranslateConfigModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/11/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LingIMTranslateConfigModel : NSObject

@property(nonatomic, copy) NSString *channel;//翻译通道
@property(nonatomic, copy) NSString *channelName;//翻译通道Name
@property(nonatomic, copy) NSString *dialogId;//会话ID
@property(nonatomic, copy) NSString *configId;//用户翻译配置ID
@property (nonatomic, assign) NSInteger level;//级别：0：用户全局配置；1:会话级别
@property(nonatomic, copy) NSString *targetLang;//翻译目标语种
@property(nonatomic, copy) NSString *targetLangName;//翻译目标语种Name
@property (nonatomic, assign) NSInteger translateSwitch;//翻译开关：0:关闭；1:打开
@property(nonatomic, copy) NSString *userUid;//用户UserID
@property(nonatomic, copy) NSString *receiveChannel;//接收配置通道
@property(nonatomic, copy) NSString *receiveChannelName;//接收配置通道名称
@property(nonatomic, copy) NSString *receiveTargetLang;//接收配置目标语种
@property(nonatomic, copy) NSString *receiveTargetLangName;//接收配置目标语种名称
@property (nonatomic, assign) NSInteger receiveTranslateSwitch;//接收配置翻译开关：0:关闭；1:打开


@end

NS_ASSUME_NONNULL_END
