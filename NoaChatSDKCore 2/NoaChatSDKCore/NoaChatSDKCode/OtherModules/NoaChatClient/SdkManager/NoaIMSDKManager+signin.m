//
//  NoaIMSDKManager+signin.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/1.
//

#import "NoaIMSDKManager+signin.h"
#import "NoaIMHttpManager+signin.h"

@implementation NoaIMSDKManager (signin)

//签到
- (void)imSignInRecordWithSign:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] signInRecordWithSign:params onSuccess:onSuccess onFailure:onFailure];
}

//签到记录
- (void)imSignInWithRecord:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] signInWithRecord:params onSuccess:onSuccess onFailure:onFailure];
}

//签到详情
- (void)imSignInWithInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] signInWithInfo:params onSuccess:onSuccess onFailure:onFailure];
}

//积分明细
- (void)imSignInWithIntergralDetail:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] signInWithIntergralDetail:params onSuccess:onSuccess onFailure:onFailure];
}


//签到规则
- (void)imSignInWithRule:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] signInWithRule:params onSuccess:onSuccess onFailure:onFailure];
}



@end
