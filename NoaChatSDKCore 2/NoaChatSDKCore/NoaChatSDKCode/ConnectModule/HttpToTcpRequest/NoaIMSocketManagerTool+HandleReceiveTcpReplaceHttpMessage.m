//
//  NoaIMSocketManagerTool+HandleReceiveTcpReplaceHttpMessage.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/8/25.
//

#import "NoaIMSocketManagerTool+HandleReceiveTcpReplaceHttpMessage.h"

// 工具类
#import "LingIMTcpCommonTool.h"

// code码判断
#import "NoaIMHttpResponse.h"

// 宏定义
#import "LingIMMacorHeader.h"

// 用于mj_objectWithKeyValues
#import <MJExtension/MJExtension.h>

// 短连接转长连接消息处理类
#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"

// 头文件
#import "NoaIMSDKManager.h"

#import "NoaLocalLogger.h"

/// 接受消息通知名称
extern NSNotificationName const _Nonnull kLingIMTcpReceiveMessageNotification;

@implementation NoaIMSocketManagerTool (HandleReceiveTcpReplaceHttpMessage)

/// MARK: 接收消息处理
- (void)receiveTcpReplaceHttpMessageDealWith:(IMMessage *)receiveMessage {
    CIMLog(@"[TCP请求追踪] 接收到消息类型为:%d", receiveMessage.dataType);
    if (receiveMessage.dataType != IMMessage_DataType_ResponseMessage) {
        // 只处理短连接转长连接消息
        return;
    }
    [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 🔄 接收到ResponseMessage - requestId:%@, status:%d，response:%@",
                  receiveMessage.responseMessage.requestId, receiveMessage.responseMessage.status, receiveMessage.responseMessage]];
    
    // 接收到短连接转长连接消息
    [[NSNotificationCenter defaultCenter] postNotificationName:kLingIMTcpReceiveMessageNotification object:receiveMessage];
    [self receiveResponseMessage:receiveMessage];
    
    // 延迟检查是否有请求匹配到这个响应
    NSString *responseId = receiveMessage.responseMessage.requestId;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CIMLog(@"[TCP请求追踪] 🔍 响应处理检查 - requestId:%@ (1秒后检查是否被正确处理)", responseId);
    });
}


/// MARK: 短连接转长连接消息处理
/// 处理短连接转长连接返回消息
/// - Parameter message: 短连接转长连接消息返回的数据
- (void)receiveResponseMessage:(IMMessage *)message {
    if (message.responseMessage.status != 200) {
        // 消息报错
        return;
    }
    
    // 收到成功消息，直接将其通过通知传递给请求处理类(LingIMTcpRequestModel)
    id data = [LingIMTcpCommonTool jsonDecode:message.responseMessage.body];
    if (data && [data isKindOfClass:[NSDictionary class]]) {
        NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:data];
        if (resp.isHttpSuccess) {
           // 收到成功消息(此处暂不处理，发送了通知消息通过LingIMTcpRequestModel+HandleReceiveMessage类处理了)
        }else {
            // 收到失败类，处理失败后
            [self handleFailureWithResponse:resp];
        }
    }
}

/// 处理失败消息
/// - Parameter response: 短连接转长连接，失败信息
- (void)handleFailureWithResponse:(NoaIMHttpResponse *)response {
    NSInteger code = response.code;
    if (code == LingIMHttpResponseCodeTokenOutTime ||
        code == LingIMHttpResponseCodeTokenError ||
        code == LingIMHttpResponseCodeOtherTokenError ||
        code == LingIMHttpResponseCodeNotAuth ||
        code == LingIMHttpResponseCodeTokenNull) {
//        // token已过期，需要自动更新一次token
//        self.isTokenExpired = YES;
//        CIMLog(@"[短连接转长连接测试] handleFailureWithResponse失败参数中返回token已过期");
        // 接收到短连接转长连接消息
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] handleFailureWithResponse失败参数中返回token已过期, code = %ld。 准备与上次刷新token时间进行比较", response.code]];
    } else if (code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
        //执行用户 强制下线 代理回调
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] handleFailureWithResponse失败参数中返回token销毁，强制退出, code = %ld", response.code]];
        if ([self.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
            [self.userDelegate noaSdkUserForceLogout:999 message:@""];
        }
        
        [self releaseAllCacheRequest];
    } else if (code == LingIMHttpResponseCodeUsedIpDisabled) {
        //执行用户 强制下线 代理回调并给出提示语
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] handleFailureWithResponse失败参数中返回用户强制下线，强制退出, code = %ld", response.code]];
        if ([self.userDelegate respondsToSelector:@selector(noaSdkUserForceLogout:message:)]) {
            [self.userDelegate noaSdkUserForceLogout:LingIMHttpResponseCodeUsedIpDisabled message:response.message];
        }
        
        [self releaseAllCacheRequest];
    } else {
        // 其他处理(此处暂不处理，发送了通知消息通过LingIMTcpRequestModel+HandleReceiveMessage类处理了)
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] handleFailureWithResponse失败参数中返回其他异常, code = %ld", response.code]];
        [self releaseAllCacheRequest];
    }
}

@end
