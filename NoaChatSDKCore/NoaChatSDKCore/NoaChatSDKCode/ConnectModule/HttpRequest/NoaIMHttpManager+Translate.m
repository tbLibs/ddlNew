//
//  NoaIMHttpManager+Translate.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/22.
//

#import "NoaIMHttpManager+Translate.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Translate)

#pragma mark - 注册阅译账号并自动绑定
- (void)translateRegisterBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Translate_register_bind_account Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Translate_register_bind_account parameters:params onSuccess:onSuccess onFailure:onFailure];        
    }
}

#pragma mark - 绑定阅译账号
- (void)translateBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Translate_bind_account Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Translate_bind_account parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 解绑阅译账号
- (void)translateUnBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Translate_unbind_account Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Translate_unbind_account parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 我绑定的阅译账号信息
- (void)translateGetYuueeAccountInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Translate_account_info Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Translate_account_info parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 调用阅译系统去翻译
- (void)translateYuueeContent:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Translate_yuuee_content Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Translate_yuuee_content parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}



@end
