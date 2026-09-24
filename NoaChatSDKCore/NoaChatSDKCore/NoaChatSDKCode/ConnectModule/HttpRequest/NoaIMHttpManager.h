//
//  NoaIMHttpManager.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/19.
//

// SDK数据请求类

#define IMSDKHTTPTOOL [NoaIMHttpManager sharedManager]

// 是否将除了竞速、消息转发以外的所有Http接口都使用tcp发送(0：走http 1:走tcp)
#define kAllHttpRequestUseTcp 1

//刷新token
#define Auth_Refresh_Token_Url          @"/auth/account/v2/autoToken"

#import <AFNetworking/AFNetworking.h>
#import "NoaIMHttpResponse.h"
#import "NSDate+LingIMDateTime.h"
//代理
#import "LingIMProtocol.h"
//同步服务端时间
#import "ZDateRequestTool.h"


//接口请求成功回调
typedef void (^LingIMSuccessCallback)(id _Nullable data, NSString * _Nullable traceId);

//接口请求失败回调
typedef void (^LingIMFailureCallback)(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId);

//带有服务器时间的接口请求成功回调
typedef void (^LingIMSuccessWithTimeCallback)(id _Nullable data, long long serviceTime);

//网络请求类型枚举
typedef NS_ENUM(NSUInteger, LingIMHttpRequestType) {
    LingIMHttpRequestTypePOST = 1,        //POST请求
    LingIMHttpRequestTypeGET = 2,         //GET请求
};

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager : AFHTTPSessionManager

//全局通用的正在自动刷新token的标志(0未开始token自动更新1正在刷新token)
//@property (nonatomic, assign) NSInteger commonAutoToken;

@property (atomic, strong, nullable) NSBlockOperation * refreshTokenOpeartion;
@property (atomic, strong, nullable) NSBlockOperation * updateBaseHostOpeartion;

@property (nonatomic, strong, nullable)NSData * cerData;
@property (nonatomic, strong, nullable)NSData * p12Data;
@property (nonatomic, copy)NSString * p12pwd;

@property (nonatomic, strong)NSOperationQueue *netWorkingQueue;

/** 单例 */
+ (instancetype)sharedManager;

- (void)stopAllRequest;

//用户代理
@property (nonatomic, weak) id <NoaUserDelegate> userDelegate;

/// 通用数据请求接口
/// @param type 数据请求类型：POST / GET
/// @param path 数据请求地址
/// @param parameters 数据请求参数
/// @param onSuccess 数据请求成功回调
/// @param onFailure 数据请求失败回调
- (void)netRequestWithType:(LingIMHttpRequestType)type path:(NSString *)path parameters:(NSDictionary * _Nullable)parameters onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/** 消息转发接口专用，提交数据方式和别的不一样，历史(有消息后台)遗留问题*/
/// 消息转发接口
/// @param path 数据请求地址
/// @param paramData 数据请求参数
/// @param onSuccess 数据请求成功回调
/// @param onFailure 数据请求失败回调
- (void)netRequestForwardWithPath:(NSString *)path paramData:(NSData * _Nullable)paramData onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 长链接失败后,发送消息接口
/// @param path 数据请求地址
/// @param paramData 数据请求参数
/// @param onSuccess 数据请求成功回调
/// @param onFailure 数据请求失败回调
- (void)netRequestMessagePushWithPath:(NSString *)path paramData:(NSData *)paramData onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 通用带有服务器时间返回的数据请求接口
/// @param type 数据请求类型：POST / GET
/// @param path 数据请求地址
/// @param parameters 数据请求参数
/// @param onSuccess 数据请求成功回调
/// @param onFailure 数据请求失败回调
- (void)netRequestWithServiceTimeWithType:(LingIMHttpRequestType)type path:(NSString *)path parameters:(NSDictionary * _Nullable)parameters onSuccess:(LingIMSuccessWithTimeCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 通用的 请求地址是否为完整地址的请求
/// - Parameters:
///   - fullPath: 请求地址，需要判断是否是完整的请求地址
///   - medth: 请求方式
///   - parameters: 请求参数
///   - onSuccess: 请求成功回调
///   - onFailure: 请求失败回调
- (void)netRequestWorkCommonBaseUrl:(NSString *)baseUrl Path:(NSString *)path medth:(LingIMHttpRequestType)medth parameters:(NSDictionary *)parameters onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 刷新token
- (void)authRefreshTokenOnSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

#pragma mark - 配置网络请求库实现双向认证证书配置
//配置confighttpSessionManagerSecurityPolicy的安全策略
- (void)confighttpSessionManagerCerAndP12CerIsIPAddress:(BOOL)isIPAddress;

#pragma mark - SDK层，token刷新
- (void)refreshAuthToken;
@end

NS_ASSUME_NONNULL_END

