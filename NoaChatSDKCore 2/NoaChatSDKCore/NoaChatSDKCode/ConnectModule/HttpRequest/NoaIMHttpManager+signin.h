//
//  NoaIMHttpManager+signin.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

//签到
#define Sign_signInRecord_Sign_Url    @"/biz/signInRecord/sign"
//签到记录
#define Sign_signInRecord_InRecord_Url  @"/biz/signInRecord/getMonthSignInRecord"
//签到详情
#define Sign_signInRecord_InInfo_Url    @"/biz/signInRecord/sigInInfo"
//积分明细
#define Sign_signInRecord_intergralDetail_Url  @"/biz/signInRecord/getMonthPointsDetails"
//签到规则
#define Sign_Rule_Info_Url            @"/biz/signInRecord/signConfig"


#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (signin)

//签到
- (void)signInRecordWithSign:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//签到记录
- (void)signInWithRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//签到详情
- (void)signInWithInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//积分明细
- (void)signInWithIntergralDetail:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//签到规则
- (void)signInWithRule:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;
@end

NS_ASSUME_NONNULL_END
