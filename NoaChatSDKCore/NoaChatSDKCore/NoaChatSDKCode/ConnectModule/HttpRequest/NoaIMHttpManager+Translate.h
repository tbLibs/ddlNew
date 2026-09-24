//
//  NoaIMHttpManager+Translate.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/22.
//


//注册阅译账号并自动绑定
#define Translate_register_bind_account      @"/biz/translate/register"
//绑定阅译账号
#define Translate_bind_account               @"/biz/translate/binding"
//解绑阅译账号
#define Translate_unbind_account             @"/biz/translate/unbinding"
//我绑定的阅译账号信息
#define Translate_account_info               @"/biz/translate/account/info"
//调用阅译系统去翻译
#define Translate_yuuee_content              @"/biz/translate/translate"
//获取所有翻译通道和通道下的语种
#define Translate_Get_Channel_Language       @"/biz/translate/channelConfig"
//获取当前登录用户所有翻译配置
#define Translate_Get_All_Config             @"/biz/userTranslate/all"
//上传用户翻译配置
#define Translate_Uplaod_New_Config          @"/biz/userTranslate/uploadConfig"


#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (Translate)

/// 注册阅译账号并自动绑定
/// @param params {account:yuee账号, password:yuee密码}
- (void)translateRegisterBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 绑定阅译账号
/// @param params {account:yuee账号, password:yuee密码}
- (void)translateBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 解绑阅译账号
/// @param params {account:yuee账号}
- (void)translateUnBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 我绑定的阅译账号信息
/// @param params {userUid:操作用户ID}
- (void)translateGetYuueeAccountInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 调用阅译系统去翻译
/// @param params {channelCode:翻译通道编码, content:翻译内容, to:目标语种, userUid:用户的userUid}
- (void)translateYuueeContent:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取所有翻译通道和通道下的语种
/// @param params {userUid:操作用户ID}
- (void)translateGetChannelLanguage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取当前登录用户所有翻译配置
/// @param params {userUid:操作用户ID}
- (void)translateGetUserAllTranslateConfig:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 上传用户翻译配置
/// @param params {channel:翻译通道, dialogId:会话ID, id:用户翻译配置ID, level:级别：0：用户全局配置；1:会话级别, targetLang:目标语种, translateSwitch:翻译开关：0:关闭；1:打开, userUid:操作用户ID}
- (void)translateUploadNewTranslateConfig:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


@end

NS_ASSUME_NONNULL_END
