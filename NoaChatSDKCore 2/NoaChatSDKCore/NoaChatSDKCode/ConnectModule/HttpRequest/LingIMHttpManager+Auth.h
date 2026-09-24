//
//  NoaIMHttpManager+Auth.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

/** Auth */
//注册新用户
#define Auth_Register_Url               @"/auth/account/v2/register"
//获取图形验证码
#define Auth_Get_VerCode_Url            @"/auth/verification/createTextVerCode"
//用户登录V2
#define Auth_User_Login_V4_Url          @"/auth/account/v4/login"
//用户登录V3
#define Auth_User_Login_V5_Url          @"/auth/account/v5/login"
//退出登录
#define Auth_User_Logout_Url            @"/auth/account/outLogin"
//用户是否存在
#define Auth_User_Exist_Url             @"/auth/account/v2/checkUserExist"
//检查用户是否存在以及是否设置密码
#define Auth_User_Exist_HasPwd_Url      @"/auth/account/v2/checkUser"
//图形验证码验证
#define Auth_Ver_ImgCode_Url            @"/auth/verification/v2/checkVerification"
//短信/邮箱验证码V2
#define Auth_Phone_Email_VerCode_V2_Url @"/auth/account/v2/sendVerificationCode"
//短信/邮箱验证码V3
#define Auth_Phone_Email_VerCode_V3_Url @"/auth/account/v3/sendVerificationCode"
//校验 短信/邮箱验证码
#define Auth_Check_VerCode_Url          @"/auth/account/v2/verificationCode"
//获取加密密钥
#define Auth_Get_EncryptKey_Url         @"/auth/account/v2/generateEncryptKey"
//刷新token
#define Auth_Refresh_Token_Url          @"/auth/account/v2/autoToken"
//找回密码(重置密码)
#define Auth_Reset_Password_Url         @"/auth/account/resetPassword"
//账号注销(注销账号)
#define Auth_Account_Remove_Url         @"/auth/account/accountClose"
//扫码授权PC端登录
#define Auth_Scan_QRcode_Login_Url      @"/auth/web/login/scanEwmLogin"
//获取登录注册方式
#define Auth_Login_Register_Type_Url    @"/auth/account/getLoginTypes"
//申请解除封禁
#define Auth_User_Apply_Unban_Url       @"/auth/account/applyUnban"
//设置用户安全码
#define Auth_Save_Security_Code_Url     @"/auth/user/security/saveSecurityCode"
//修改用户安全码
#define Auth_Update_Security_Code_Url   @"/auth/user/security/updateSecurityCode"
//关闭用户安全码
#define Auth_Close_Security_Code_Url    @"/auth/user/security/closeSecurityCode"
//安全码登录验证
#define Auth_Security_Code_Login_Url    @"/auth/account/securityCodeLogin"

//检测用户是否是弱密码
#define Auth_Check_Password_Strength_Url  @"/auth/account/checkPassword"



#import <Foundation/Foundation.h>
#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (Auth)

/**
 @brief  获取图形验证码
 */
- (void)AuthGetImgVerCodeWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  获取短信/邮箱验证码 V2
 loginInfo  登录账号信息(用于获取验证码),邮箱/手机号
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
 type 验证码类型，1为注册 2为登录 3为找回密码
 areaCode 国家区号代码(NSString)  eq:+86
 */
- (void)AuthGetPhoneEmailVerCodeV2With:(NSMutableDictionary * _Nullable)params
                                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  获取短信/邮箱验证码 V3
 loginInfo  登录账号信息(用于获取验证码),邮箱/手机号
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
 type 验证码类型，1为注册 2为登录 3为找回密码
 areaCode 国家区号代码(NSString)  eq:+86
 */
- (void)AuthGetPhoneEmailVerCodeV3With:(NSMutableDictionary * _Nullable)params
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
- (void)AuthCheckPhoneEmailVerCodeWith:(NSMutableDictionary * _Nullable)params
                             onSuccess:(nullable LingIMSuccessCallback)onSuccess
                             onFailure:(nullable LingIMFailureCallback)onFailure;

/**
@brief  获取加密密钥
*/
- (void)AuthGetEncryptKeySuccess:(nullable LingIMSuccessCallback)onSuccess
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
- (void)AuthRegisterWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  用户登录 V4
  loginInfo  登录账号信息,可以是用户名，邮箱，手机号
  loginType  1是用户名，2是邮箱，3是手机号
  code 验证码
  encryptKey  加密key,需要请求[接口获取加密密钥]
  type  验证码类型，1为注册 2为登录 3为找回密码
  areaCode  国家区号代码 eq: @"+86"
  userPw  密码[加密key + 明文密码拼接后加密的密文]
*/
- (void)AuthUserLoginV4With:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  用户登录 V5
  loginInfo  登录账号信息,可以是用户名，邮箱，手机号
  loginType  1是用户名，2是邮箱，3是手机号
  code 验证码
  encryptKey  加密key,需要请求[接口获取加密密钥]
  type  验证码类型，1为注册 2为登录 3为找回密码
  areaCode  国家区号代码 eq: @"+86"
  userPw  密码[加密key + 明文密码拼接后加密的密文]
*/
- (void)AuthUserLoginV5With:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
@brief  用户退出登录
*/
- (void)AuthUserLogoutWith:(NSMutableDictionary * _Nullable)params
                 onSuccess:(nullable LingIMSuccessCallback)onSuccess
                 onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  用户是否存在
 loginInfo  登录账号信息(邮箱/手机号/账号)
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
*/
- (void)AuthUserExistWith:(NSMutableDictionary * _Nullable)params
                onSuccess:(nullable LingIMSuccessCallback)onSuccess
                onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  检查用户是否存在以及是否设置密码
 loginInfo  登录账号信息(邮箱/手机号/账号)
 loginType  类型枚举,1是用户名，2是邮箱，3是手机号
*/
- (void)AuthUserExistAndHasPwdWith:(NSMutableDictionary * _Nullable)params
                         onSuccess:(nullable LingIMSuccessCallback)onSuccess
                         onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  验证码验证是否正确
 code 图形验证码
*/
- (void)AuthUserVerCodeWith:(NSMutableDictionary * _Nullable)params
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
- (void)AuthResetPasswordWith:(NSMutableDictionary * _Nullable)params
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
- (void)AuthDeleteAccountWith:(NSMutableDictionary * _Nullable)params
                    onSuccess:(nullable LingIMSuccessCallback)onSuccess
                    onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  扫码授权PC端登录
 deviceUuid  二维码解析出来的 需要登录的设备id
 ewmKey  本次扫码的二维码唯一ID
 step      扫码后的操作状态 1:确认2:取消
 userUid  扫码的用户ID
 */
- (void)AuthScanQrCodeForPCLoginWith:(NSMutableDictionary * _Nullable)params
                           onSuccess:(nullable LingIMSuccessCallback)onSuccess
                           onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  获取登录注册方式
 */
- (void)AuthGetLoginAndRegisterTypeOnSuccess:(nullable LingIMSuccessCallback)onSuccess
                                   onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  申请解禁
 banType  封禁类型（1: 账户；2：IP; 3: 设备);
 code  封禁类型对应识别码: 账号名、IP、设备号(UUID)
 */
- (void)AuthUserApplyUnBandWith:(NSMutableDictionary * _Nullable)params
                      onSuccess:(nullable LingIMSuccessCallback)onSuccess
                      onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  设置用户安全码
 encryptKey  加密key,需要请求[接口获取加密密钥]
 securityCode 安全码, 需使用加密key加密    
 userUid  用户ID
 */
- (void)AuthSaveSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  修改用户安全码
 encryptKey  加密key,需要请求[接口获取加密密钥]
 securityCode 安全码, 需使用加密key加密
 userUid  用户ID
 originalSecurityCode  原始安全码, 需使用加密key加密
 */
- (void)AuthUpdatecurityCodeWith:(NSMutableDictionary * _Nullable)params
                       onSuccess:(nullable LingIMSuccessCallback)onSuccess
                       onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  关闭用户安全码
 userUid  用户ID
 originalSecurityCode  原始安全码, 需使用加密key加密
 */
- (void)AuthCloseSecurityCodeWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief  安全码登录验证
 scKey  scKey, 传入登录接口返回key
 securityCode 安全码, 需使用加密key加密
 userUid  用户ID
 */
- (void)AuthSecurityCodeLoginWith:(NSMutableDictionary * _Nullable)params
                        onSuccess:(nullable LingIMSuccessCallback)onSuccess
                        onFailure:(nullable LingIMFailureCallback)onFailure;




/**
 @brief  检测用户是否是弱密码
 password 密码(只有登录时传入)
*/
- (void)AuthCheckPasswordStrengthWith:(NSMutableDictionary * _Nullable)params
                              onSuccess:(nullable LingIMSuccessCallback)onSuccess
                              onFailure:(nullable LingIMFailureCallback)onFailure;
@end

NS_ASSUME_NONNULL_END
