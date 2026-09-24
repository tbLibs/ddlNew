//
//  NoaIMSDKManager+Translate.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/22.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Translate)

//tools
#pragma mark -  将内容 拆分为 翻译内容  + at字符串 + 表情字符串 三部分
- (void)translationSplit:(NSString *)messageStr
              atUserList:(NSArray *)atUserList
                  finish:(void(^)(NSString * translationString,
                                  NSString * atString,
                                  NSString * emojiString))finish;

#pragma mark -  翻译接口调用
- (void)requestTranslateActionWithContent:(NSString *)content
                           atUserDictList:(NSArray *)atUserList
                                sessionId:(NSString *)sessionId
                              messageType:(CIMChatMessageType)messageType
                                  success:(void(^)(NSString  * _Nullable result))success
                                  failure:(void(^)(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId))failure;

/// 注册阅译账号并自动绑定
/// @param params {account:yuee账号, password:yuee密码}
- (void)imSdkTranslateRegisterBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 绑定阅译账号
/// @param params {account:yuee账号, password:yuee密码}
- (void)imSdkTranslateBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 解绑阅译账号
/// @param params {account:yuee账号}
- (void)imSdkTranslateUnBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 我绑定的阅译账号信息
/// @param params {userUid:操作用户ID}
- (void)imSdkTranslateGetYuueeAccountInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 调用阅译系统去翻译
/// @param params {channelCode:翻译通道编码, content:翻译内容, to:目标语种, userUid:用户的userUid}
- (void)imSdkTranslateYuueeContent:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取所有翻译通道和通道下的语种
/// @param params {userUid:操作用户ID}
- (void)imSdkTranslateGetChannelLanguage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取当前登录用户所有翻译配置
/// @param params {userUid:操作用户ID}
- (void)imSdkTranslateGetUserAllTranslateConfig:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 上传用户翻译配置
/// @param params {channel:翻译通道, dialogId:会话ID, id:用户翻译配置ID, level:级别：0：用户全局配置；1:会话级别, targetLang:目标语种, translateSwitch:翻译开关：0:关闭；1:打开, userUid:操作用户ID}
- (void)imSdkTranslateUploadNewTranslateConfig:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
