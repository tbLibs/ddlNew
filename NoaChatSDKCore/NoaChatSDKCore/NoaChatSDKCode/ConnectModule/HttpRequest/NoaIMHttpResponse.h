//
//  NoaIMHttpResponse.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/19.
//

// SDK数据请求响应类

#import <Foundation/Foundation.h>

/// 封禁
//账号封禁
#define Auth_User_Account_Banned            40015   //此账号已封禁
//设备封禁
#define Auth_User_Device_Banned             40029   //此设备已被封禁
//IP封禁
#define Auth_User_IPAddress_Banned          40030   //此IP已被封禁

//密码连续3次错误，需要验证码校验
#define Auth_User_Get_Img_Code              40064   //密码连续3次错误，需要验证码校验

#define Auth_User_Banned_Five_Code          40045   //密码连续输入错误，请5分钟后重试

#define Auth_User_Banned_24Hour_Code        40062  //密码连续输入错误，请24小时后重试
//账号密码或验证码错误！
#define Auth_User_reGet_Img_Code            50002   //账号密码或验证码错误！

#define Auth_User_Capcha_Error_Code          51002   //阿里云验证异常，需进行二次验证
#define Auth_User_Capcha_TimeOut_Code        51006   //阿里云验证超时，展示图文验证码
#define Auth_User_Capcha_ChangeImgVer_Code   450010  //展示图文验证码

#define Auth_Original_Security_Code_Error_Code   40069  //原始安全码错误
#define Auth_Login_Security_Code_Error_Code      10009  //登录提示需要安全码，跳转到安全码输入界面
#define Auth_Login_SecurityCode_Has_Set_Error_Code          40067  //用户已设置安全码
#define Auth_Login_SecurityCode_No_Set_Error_Code           40075  //用户未设置安全码
#define Auth_Login_SecurityCode_Format_Error_Code           40070  //安全码由六位数字+字母组成
#define Auth_Login_SecurityCode_otherFormat_Error_Code      40071  //安全码由六位数字+字母组成
#define Auth_Login_SecurityCode_Expire_Error_Code           40072  //安全码登录已过期(停留时间过久~请重新登录)
#define Auth_Login_SecurityCode_Not_SameDevice_Error_Code   40073  //安全码登录不在同一台设备上(登录失败~请重新登录)


//账号密码或验证码错误！
#define Auth_User_Password_Error_Code                        40019   //密码不正确
#define Auth_User_Password_Account_Nonexistent_Code          2036    //账号不存在
#define Auth_User_Password_Email_Nonexistent_Code            50000   //邮箱不存在
#define Auth_User_Password_Phone_Nonexistent_Code            50001   //手机号不存在


// 网络请求状态码枚举
typedef NS_ENUM(NSUInteger, LingIMHttpResponseCode) {
    LingIMHttpResponseCodeSuccess = 10000,         //数据请求成功
    LingIMHttpResponseCodeTokenOutTime = 40035,    // 40035,身份信息已过期，请重新登录
    LingIMHttpResponseCodeTokenError = 40038,      //40038,身份信息验证失败
    LingIMHttpResponseCodeNotNetWork = 1009,      //没有网络
    LingIMHttpResponseCodeExamineStatus = 44016,//提交成功，系统稍后处理
    LingIMHttpResponseCodeNoneExamineStatus = 44017, //您已经提交过申请，请耐心等待审核
    LingIMHttpResponseTranslateYueeUnbindStatus = 40056,//未绑定阅译账号
    LingIMHttpResponseTranslateYueeNoBalanceStatus = 40422, //阅译账号余额不足
    LingIMHttpResponseCodeTokenDestroy = 40061, //用户Token销毁(被封禁了，直接退出账号，无任何提示信息)
    LingIMHttpResponseCodeUsedIpDisabled = 90018, //客户端当前IP不在白名单内，直接退出账号，无任何提示
    
    LingIMHttpResponseCodeOtherTokenError = 10002, //身份信息验证失败
    LingIMHttpResponseCodeNotAuth = 10005, //身份信息验证失败
    LingIMHttpResponseCodeTokenNull = 10007, //身份信息验证失败
};


NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpResponse : NSObject

@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) NSInteger code;
@property (nonatomic, strong) id data;
@property (nonatomic, copy) NSString *traceId;
@property (nonatomic, assign) BOOL isHttpSuccess;//是否成功

- (id)responseData;
- (void)setResponseData:(id)data;

@end

NS_ASSUME_NONNULL_END
