//
//  LingIMTcpRequestModel+HandleReceiveMessage.m
//  NoaChatSDKCore
//
//  Created by phl on 2025/6/27.
//

#import "LingIMTcpRequestModel+HandleReceiveMessage.h"
// code码判断
#import "NoaIMHttpResponse.h"

#import <MJExtension/MJExtension.h>

#import "LingIMTcpCommonTool.h"

// probuf文件
#import "LingImmessage.pbobjc.h"

// 宏定义
#import "LingIMMacorHeader.h"

// 头文件
#import "NoaIMSDKManager.h"

// 时间转换
#import "NSDate+LingIMDateTime.h"

#import "NoaLocalLogger.h"

#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"

@implementation LingIMTcpRequestModel (HandleReceiveMessage)

/// MARK: 接收消息处理
- (void)receiveMessageDealWith:(IMMessage *)message {
    if (message.responseMessage.status != 200) {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] 当前消息状态为%d，走失败回调", message.responseMessage.status]];
        // 消息报错
        if (self.failureCallBack) {
            self.failureCallBack(0, @"", self.msgId);
        }
        return;
    }
    
    NSDictionary *dateDic = [LingIMTcpCommonTool jsonDecode: message.responseMessage.extension];
    
    long long serviceDateValue = 0;
    if ([dateDic objectForKey:@"date"]) {
        NSString *date = [dateDic objectForKey:@"date"];
        NSDate *serviceDate = [NSDate dateFromRFC822String:date];
        serviceDateValue = [serviceDate timeIntervalSince1970] * 1000;
    }
    
    id data = [LingIMTcpCommonTool jsonDecode:message.responseMessage.body];
    if ([self.url isEqualToString:@"/auth/account/v2/autoToken"]) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 获取到token返回消息：%@", data]];
    }
    if (data && [data isKindOfClass:[NSDictionary class]]) {
        NoaIMHttpResponse *resp = [NoaIMHttpResponse mj_objectWithKeyValues:data];
        if (resp.isHttpSuccess) {
            [self handleSuccessData:resp.data serviceDateValue:serviceDateValue];
        }else {
            [self handleFailureWithResponse:resp];
        }
    }
   
}

/// 处理成功消息
/// - Parameter data: 成功消息返回的数据
- (void)handleSuccessData:(id)data
         serviceDateValue:(long long)serviceDateValue {
    if (!data) {
        if (self.successCallBack) {
            self.successCallBack(data, self.msgId);
        }
        
        if (self.successTimeCallBack) {
            self.successTimeCallBack(data, serviceDateValue);
        }
        return;
    }
    
    id respData = [LingIMTcpCommonTool responseDataDescryptWithDataString:data url:self.url];
    if (respData != nil) {
        [NoaLocalLogger info:[NSString stringWithFormat:@"[短连接转长连接] 消息解析成功，消息id = %@, respData = %@", self.msgId, respData]];
        if (self.successCallBack) {
            self.successCallBack(respData, self.msgId);
        }
        
        if (self.successTimeCallBack) {
            self.successTimeCallBack(data, serviceDateValue);
        }
    }else {
        [NoaLocalLogger error:[NSString stringWithFormat:@"[短连接转长连接] 消息解析respData为nil，消息id = %@", self.msgId]];
        if ([self.url containsString:@"/dns/report"]) {
            if (self.failureCallBack) {
                self.failureCallBack(0, @"", self.msgId);
            }
        }else {
            if (self.failureCallBack) {
                self.failureCallBack(0, @"网络异常~", self.msgId);
            }
        }
    }
}

/// 处理失败消息
/// - Parameter code: 失败错误码
- (void)handleFailureWithResponse:(NoaIMHttpResponse *)response {
    NSInteger code = response.code;
    if (code == LingIMHttpResponseCodeTokenOutTime ||
        code == LingIMHttpResponseCodeTokenError ||
        code == LingIMHttpResponseCodeOtherTokenError ||
        code == LingIMHttpResponseCodeNotAuth ||
        code == LingIMHttpResponseCodeTokenNull) {
        // token已过期，调用此逻辑判断token是否需要刷新
        [[NoaIMSocketManagerTool sharedManager] isNeedRefreshToken:self.sendDate];
    } else if (code == LingIMHttpResponseCodeTokenDestroy && IMSDKManager.myUserToken.length > 0) {
        //执行用户 强制下线 代理回调（已在LingIMTcpManager+HandleReceiveMessage处理退出登录）
    } else if (code == LingIMHttpResponseCodeUsedIpDisabled) {
        //执行用户 强制下线 代理回调并给出提示语（已在LingIMTcpManager+HandleReceiveMessage处理退出登录）
        if (self.failureCallBack) {
            self.failureCallBack(code, response.message, self.msgId);
        }
    } else {
        if (self.failureCallBack) {
            self.failureCallBack(code, response.message, self.msgId);
        }
    }
}



@end
