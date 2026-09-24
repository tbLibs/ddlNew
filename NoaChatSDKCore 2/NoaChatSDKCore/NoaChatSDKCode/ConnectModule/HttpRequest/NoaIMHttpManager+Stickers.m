//
//  NoaIMHttpManager+Stickers.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/27.
//

#import "NoaIMHttpManager+Stickers.h"
#import "LingIMTcpRequestModel.h"

@implementation NoaIMHttpManager (Stickers)

#pragma mark - 获取收藏表情列表
- (void)userGetCollectStickersList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Get_Collect_List_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Sticker_Get_Collect_List_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 添加表情到收藏列表
- (void)userAddStickersToCollectList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Add_To_CollectList_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sticker_Add_To_CollectList_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 从收藏列表移除表情
- (void)userRemoveStickersFromCollectList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Remove_From_CollectList_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sticker_Remove_From_CollectList_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 根据表情名称获取表情列表
- (void)userFindStickersForName:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Find_For_Name_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Sticker_Find_For_Name_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 添加表情包
- (void)userAddStickersPackage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Package_Add_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sticker_Package_Add_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取表情包列表 - 用户未下载的表情包
- (void)userFindUnUsedStickersPackageList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_UnDownload_Package_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Sticker_UnDownload_Package_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取表情包列表 - 用户正在使用的表情包列表
- (void)userFindUsedStickersPackageList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Find_Use_Package_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Sticker_Find_Use_Package_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 获取表情包表情详情
- (void)userGetStickersPackageDetail:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Get_Package_Detail_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Sticker_Get_Package_Detail_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 根据表情ID查询表情包 - 当前有效的唯一表情包
- (void)userGetPackageFromStickersId:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Find_Package_For_StickersId_Url Method:LingRequestGet SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypeGET path:Sticker_Find_Package_For_StickersId_Url parameters:params onSuccess:onSuccess onFailure:onFailure];
    }
}

#pragma mark - 移除表情包
- (void)userRemoveusedStickersPackage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    if (kAllHttpRequestUseTcp) {
        [LingIMTcpRequestModel sendTcpRequestWithParam:params Url:Sticker_Remove_Used_Package_Url Method:LingRequestPost SuccessFunc:onSuccess FailureFunc:onFailure];
    }else {
        [self netRequestWithType:LingIMHttpRequestTypePOST path:Sticker_Remove_Used_Package_Url parameters:params onSuccess:onSuccess onFailure:onFailure];        
    }
}

@end
