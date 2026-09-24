//
//  NoaIMSDKManager+signin.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (signin)

//签到
- (void)imSignInRecordWithSign:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//签到记录
- (void)imSignInWithRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//签到详情
- (void)imSignInWithInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//积分明细
- (void)imSignInWithIntergralDetail:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

//签到规则
- (void)imSignInWithRule:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
