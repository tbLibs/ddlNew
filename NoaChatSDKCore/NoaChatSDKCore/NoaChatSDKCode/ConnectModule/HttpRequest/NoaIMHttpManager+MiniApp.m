//
//  NoaIMHttpManager+MiniApp.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMHttpManager+MiniApp.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (MiniApp)

#pragma mark - 获取快应用列表
- (void)miniAppListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:MiniApp_List_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:MiniApp_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 创建快应用
- (void)miniAppCreateWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:MiniApp_Create_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:MiniApp_Create_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 编辑快应用
- (void)miniAppEditWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:MiniApp_Edit_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:MiniApp_Edit_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 删除快应用
- (void)miniAppDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:MiniApp_Delete_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:MiniApp_Delete_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取快应用详情
- (void)miniAppDetailWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:MiniApp_Detail_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:MiniApp_Detail_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 验证快应用访问密码
- (void)miniAppPasswordVerifyWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:MiniApp_Password_Verify_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:MiniApp_Password_Verify_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

@end
