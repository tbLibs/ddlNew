//
//  LingIMTcpRequestModel.h
//  NoaChatSDKCore
//
//  Created by phl on 2025/6/25.
//

#import <Foundation/Foundation.h>
@class IMMessage;
/// 接受消息通知名称
extern NSNotificationName const _Nonnull kLingIMTcpReceiveMessageNotification;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LingRequestMethod) {
    /// GET请求
    LingRequestGet,
    /// POST请求
    LingRequestPost,
};

/// 接口请求成功回调
typedef void (^LingTcpRequestSuccessCallback)(id _Nullable data, NSString * _Nullable traceId);

/// 带有服务器时间的接口请求成功回调
typedef void (^LingTimeRequestSuccessCallback)(id _Nullable data, long long serviceTime);

/// 接口请求失败回调
typedef void (^LingIMTcpRequestFailureCallback)(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId);


@interface LingIMTcpRequestModel : NSObject

/// MARK: 回调方法
/// 成功回调
@property (nonatomic, copy, readonly) LingTcpRequestSuccessCallback successCallBack;

/// 带有时间的成功回调
@property (nonatomic, copy, readonly) LingTimeRequestSuccessCallback successTimeCallBack;

/// 失败回调
@property (nonatomic, copy, readonly) LingIMTcpRequestFailureCallback failureCallBack;

/// MARK: 记录的参数，用于消息重发

/// 消息id
@property (nonatomic, copy, readonly) NSString *msgId;

/// 记录当前请求的参数
@property (nonatomic, strong, readonly) id param;

/// 记录当前请求的url地址
@property (nonatomic, copy, readonly) NSString *url;

/// 记录当前请求的类型
@property (nonatomic, copy, readonly) NSString *methodString;

/// 记录当前请求的message对象(基类为IMMessage)
@property (nonatomic, strong, readonly) IMMessage *sendMessage;

/// 发送请求的时间
@property (nonatomic, strong, readonly) NSDate *sendDate;

/// 发送tcp消息请求(根据param参数、url组装成IMMessage)
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
+ (LingIMTcpRequestModel *)sendTcpRequestWithParam:(id)param
                                               Url:(NSString *)url
                                            Method:(LingRequestMethod)method
                                       SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                                       FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc;

/// 发送tcp消息请求
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 带有服务器时间的成功回调
///   - failureFunc: 失败的回调
+ (LingIMTcpRequestModel *)sendTimeRequestWithParam:(id)param
                                                Url:(NSString *)url
                                             Method:(LingRequestMethod)method
                                        SuccessFunc:(nullable LingTimeRequestSuccessCallback)successFunc
                                        FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc;

/// 发送tcp消息请求（根据param参数\url组装成IMMessage，配合alloc init使用）
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
- (void)sendTcpRequestWithParam:(id)param
                            Url:(NSString *)url
                         Method:(LingRequestMethod)method
                    SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                    FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc;

/// 发送tcp消息请求(根据外部已经组装好的IMMessage,发送协议)
/// - Parameters:
///   - message: 已经组装好的IMMessage(基类为IMMessage)
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
+ (LingIMTcpRequestModel *)sendTcpRequestWithIMMessage:(IMMessage *)message
                                           SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                                           FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc;

/// 发送tcp消息请求(根据外部已经组装好的IMMessage,发送协议，配合alloc init使用)
/// - Parameters:
///   - message: 已经组装好的IMMessage(基类为IMMessage)
///   - successFunc: 成功的回调
///   - failureFunc: 失败的回调
- (void)sendTcpRequestWithIMMessage:(IMMessage *)message
                        SuccessFunc:(nullable LingTcpRequestSuccessCallback)successFunc
                        FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc;

/// 发送tcp消息请求
/// - Parameters:
///   - param: 请求的参数
///   - url: 对应的http接口地址
///   - method: 对应的Http请求方式，如POST、GET
///   - successFunc: 带有服务器时间的成功回调
///   - failureFunc: 失败的回调
- (void)sendTimeRequestWithParam:(id)param
                             Url:(NSString *)url
                          Method:(LingRequestMethod)method
                     SuccessFunc:(nullable LingTimeRequestSuccessCallback)successFunc
                     FailureFunc:(nullable LingIMTcpRequestFailureCallback)failureFunc;

/// 在token更新完成后，更新token
- (void)refreshToken;

@end

NS_ASSUME_NONNULL_END
