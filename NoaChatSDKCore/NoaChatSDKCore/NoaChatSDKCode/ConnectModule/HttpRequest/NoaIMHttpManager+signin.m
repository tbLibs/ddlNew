//
//  NoaIMHttpManager+signin.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMHttpManager+signin.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (signin)

#pragma mark - 签到
- (void)signInRecordWithSign:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sign_signInRecord_Sign_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sign_signInRecord_Sign_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 签到记录
- (void)signInWithRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sign_signInRecord_InRecord_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sign_signInRecord_InRecord_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 签到详情
- (void)signInWithInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sign_signInRecord_InInfo_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sign_signInRecord_InInfo_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 积分明细
- (void)signInWithIntergralDetail:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sign_signInRecord_intergralDetail_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sign_signInRecord_intergralDetail_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 签到规则
- (void)signInWithRule:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sign_Rule_Info_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sign_Rule_Info_Url parameters:params onSuccess:onSuccess onFailure:onFailure];        
    }
}


@end
