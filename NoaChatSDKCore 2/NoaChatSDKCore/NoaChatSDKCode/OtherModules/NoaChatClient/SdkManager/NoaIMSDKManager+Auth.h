//
//  NoaIMSDKManager+Auth.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Auth)

/**
 @brief  获取图形验证码
 */
- (void)authGetImgVerCodeWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  获取短信/邮箱验证码
 loginInfo  登录账号信息(用于获取验证码),邮箱/手机号
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
 type 验证码类型，1为注册 2为登录 3为找回密码
 areaCode 国家区号代码(NSString)  eq:+86
 */
- (void)authGetPhoneEmailVerCodeWith:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  校验 短信/邮箱验证码
 loginInfo  登录账号信息(用于获取验证码),邮箱/手机号
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
 type 验证码类型，1为注册 2为登录 3为找回密码
 areaCode 手机国家区号，+86
 code 验证码
 */
- (void)authCheckPhoneEmailVerCodeWith:(NSMutableDictionary * _Nullable)params
                             onSuccess:(nullable LingIMSuccessCallback)onSuccess
                             onFailure:(nullable LingIMFailureCallback)onFailure;

/**
@brief  获取加密密钥
*/
- (void)authGetEncryptKeySuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  注册新用户
 loginInfo  用户名
 loginType  1是用户名，2是邮箱，3是手机号
 code 短信/邮箱验证码
 type 验证码类型，1为注册 2为登录 3为找回密码
 encryptKey  加密key,需要请求[接口获取加密密钥]
 nickName  用户昵称
 registerType 注册类型：1：普通注册 2：H5邀请注册
 userPw  密码[加密key + 明文密码拼接后加密的密文]
 */
- (void)authRegisterWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  用户登录
  loginInfo  登录账号信息,可以是用户名，邮箱，手机号
  loginType  1是用户名，2是邮箱，3是手机号
  code 验证码
  encryptKey  加密key,需要请求[接口获取加密密钥]
  type  验证码类型，1为注册 2为登录 3为找回密码
  areaCode  国家区号代码 eq: @"+86"
  userPw  密码[加密key + 明文密码拼接后加密的密文]
*/
- (void)authUserLoginWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
@brief  用户退出登录
*/
- (void)authUserLogoutWith:(NSMutableDictionary * _Nullable)params
                 onSuccess:(nullable LingIMSuccessCallback)onSuccess
                 onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  用户是否存在
 loginInfo  登录账号信息(邮箱/手机号/账号)
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
*/
- (void)authUserExistWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  检查用户是否存在以及是否设置密码
 loginInfo  登录账号信息(邮箱/手机号/账号)
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
*/
- (void)authUserExistAndHasPwdWith:(NSMutableDictionary * _Nullable)params
                         onSuccess:(nullable LingIMSuccessCallback)onSuccess
                         onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  验证码验证是否正确
 code 图形验证码
*/
- (void)authUserVerCodeWith:(NSMutableDictionary * _Nullable)params
                  onSuccess:(nullable LingIMSuccessCallback)onSuccess
                  onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  找回密码(重置密码)
 loginInfo  登录账号信息(用于获取验证码),邮箱/手机号
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
 code  验证码
 encryptKey  加密key,需要请求[接口获取加密密钥]
 userPw  密码[加密key + 明文密码拼接后加密的密文]
 type 验证码类型，1为注册 2为登录 3为找回密码
 */
- (void)authResetPasswordWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  账号注销
 areaCode  手机国家区号，+86
 encryptKey  加密key,需要请求[接口获取加密密钥]
 loginInfo  登录账号信息，手机号/邮箱/账号
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
 userPw  密码[加密key + 明文密码拼接后加密的密文]
 
 */
- (void)authDeleteAccountWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  扫码授权PC端登录
 deviceUuid  二维码解析出来的 需要登录的设备id
 ewmKey  本次扫码的二维码唯一ID
 step      扫码后的操作状态 1:确认2:取消
 userUid  扫码的用户ID
 */
- (void)authScanQrCodeForPCLoginWith:(NSMutableDictionary * _Nullable)params
                           onSuccess:(nullable LingIMSuccessCallback)onSuccess
                           onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  获取登录注册方式
 */
- (void)authGetLoginAndRegisterTypeOnSuccess:(nullable LingIMSuccessCallback)onSuccess
                                   onFailure:(nullable LingIMFailureCallback)onFailure;


/**
 @brief  申请解禁
 banType  封禁类型（1: 账户；2：IP; 3: 设备);
 code  封禁类型对应识别码: 账号名、IP、设备号(UUID)
 */
- (void)authApplyUnBandWith:(NSMutableDictionary * _Nullable)params
                  onSuccess:(nullable LingIMSuccessCallback)onSuccess
                  onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  设置用户安全码
 encryptKey  加密key,需要请求[接口获取加密密钥]
 securityCode 安全码, 需使用加密key加密
 userUid  用户ID
 */
- (void)authSaveSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  修改用户安全码
 encryptKey  加密key,需要请求[接口获取加密密钥]
 securityCode 安全码, 需使用加密key加密
 userUid  用户ID
 originalSecurityCode  原始安全码, 需使用加密key加密
 */
- (void)authUpdatecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  关闭用户安全码
 userUid  用户ID
 originalSecurityCode  原始安全码, 需使用加密key加密
 */
- (void)authCloseSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  安全码登录验证
 scKey  scKey, 传入登录接口返回key
 securityCode 安全码, 需使用加密key加密
 userUid  用户ID
 */
- (void)authSecurityCodeLoginWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure;

/// 获取当前用户的信任设备列表。
/// @param params 请求参数，userUid 为当前登录用户 UID
/// @param onSuccess 成功回调，data 为设备字典数组
/// @param onFailure 失败回调，返回业务错误码、错误信息和链路 ID
- (void)authTrustedDeviceListWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure;

/// 验证登录密码并剔除指定信任设备。
/// @param params 请求参数，包含 userUid、deviceUuid、deviceType、passwd 和 encryptKey
/// @param onSuccess 成功回调，设备会话已由服务端撤销
/// @param onFailure 失败回调，返回业务错误码、错误信息和链路 ID
- (void)authTrustedDeviceRevokeWith:(NSMutableDictionary * _Nullable)params
                          onSuccess:(nullable LingIMSuccessCallback)onSuccess
                          onFailure:(nullable LingIMFailureCallback)onFailure;

/// 验证登录密码并清除指定信任设备的异常标记。
/// @param params 请求参数，包含 deviceUuid 和经过 MD5 处理的 passwd
/// @param onSuccess 成功回调，服务端已清除目标设备的异常标记
/// @param onFailure 失败回调，返回业务错误码、错误信息和链路 ID
- (void)authTrustedDeviceClearAnomalyWith:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  检测用户是否是弱密码
 password 密码(只有登录时传入)
*/
- (void)authCheckPasswordStrengthWith:(NSMutableDictionary * _Nullable)params
                              onSuccess:(nullable LingIMSuccessCallback)onSuccess
                              onFailure:(nullable LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
