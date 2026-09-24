//
//  NoaIMSDKManager+Translate.m
//  NoaChatSDKCore
//
//  Created by Candy on 2023/9/22.
//

#import "NoaIMSDKManager+Translate.h"
#import "NoaIMHttpManager+Translate.h"
#import "NoaIMSDKManager+Session.h"//会话

@implementation NoaIMSDKManager (Translate)

#pragma mark -  将内容 拆分为 翻译内容  + at字符串 + 表情字符串 三部分
- (void)translationSplit:(NSString *)messageStr
              atUserList:(NSArray *)atUserList
                  finish:(void(^)(NSString * translationString,
                                  NSString * atString,
                                  NSString * emojiString))finish {
    if (messageStr.length > 0) {
        NSMutableString *translationString = [NSMutableString stringWithString:messageStr];
        NSMutableString *atString = [NSMutableString string];
        NSMutableString *emojiString = [NSMutableString string];
        // 先匹配 emoji，避免表情符号的]和@消息的\v紧邻时出现误匹配
        NSError *error;
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"\\[[^ \\[\\]]+?\\]"
                                      options:0
                                      error:&error];
        NSArray *matchs = [regex matchesInString:translationString
                                         options:0
                                           range:NSMakeRange(0, [translationString length])];
        //找到所有的 表情字符串 存放起来（倒序处理，避免索引偏移）
        NSMutableArray *emojiArray = [NSMutableArray array];
        for (NSTextCheckingResult *match in matchs) {
            [emojiArray addObject:@{@"text": [translationString substringWithRange:match.range], @"range": [NSValue valueWithRange:match.range]}];
        }
        // 按位置倒序排序，从后往前移除，避免索引偏移
        [emojiArray sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSRange range1 = [obj1[@"range"] rangeValue];
            NSRange range2 = [obj2[@"range"] rangeValue];
            if (range1.location > range2.location) {
                return NSOrderedAscending;
            } else if (range1.location < range2.location) {
                return NSOrderedDescending;
            }
            return NSOrderedSame;
        }];
        // 从后往前移除表情字符串，避免索引偏移
        for (NSDictionary *emojiDict in emojiArray) {
            NSRange emojiRang = [emojiDict[@"range"] rangeValue];
            [translationString replaceCharactersInRange:emojiRang withString:@""];
            [emojiString appendString:emojiDict[@"text"]];
        }
        
        //匹配 at信息（在移除表情符号后再移除@信息）
        for (NSDictionary *atUserDic in atUserList) {
            NSArray *atKeyArr = [atUserDic allKeys];
            NSString *atKey = (NSString *)[atKeyArr firstObject];
            
            NSString * atUidStr = [NSString stringWithFormat:@"\v%@\v",atKey];
            NSRange atRange = [translationString rangeOfString:atUidStr];
            if (atRange.location != NSNotFound) {
                [translationString replaceCharactersInRange:atRange withString:@""];
                [atString appendString:atUidStr];
        }
        }
        //删除字符串开头与结尾的空白符与换行
        [translationString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [atString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [emojiString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        //完成
        finish(translationString,atString,emojiString);
    }else{
        finish(messageStr,nil,nil);
    }
}

//翻译接口调用
- (void)requestTranslateActionWithContent:(NSString *)content
                           atUserDictList:(NSArray *)atUserList
                                sessionId:(NSString *)sessionId
                              messageType:(CIMChatMessageType)messageType
                                  success:(void(^)(NSString  * _Nullable result))success
                                  failure:(void(^)(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId))failure {
    
    __weak typeof(self) weakSelf = self;
    [self translationSplit:content atUserList:atUserList finish:^(NSString * _Nonnull translationString,
                                                                            NSString * _Nonnull atString,
                                                                            NSString * _Nonnull emojiString) {
        //判断 如果内容只有表情或者at消息将消息重新拼装返回
        if(translationString.length <= 0) {
            NSMutableString *sendResultStr = [NSMutableString string];
            [sendResultStr appendString:atString.length > 0 ? atString : @""];
            [sendResultStr appendString:emojiString.length > 0 ? emojiString : @""];
            [sendResultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (success) {
                success(sendResultStr);
            }
        } else {
            LingIMSessionModel *sessionModel = [weakSelf toolCheckMySessionWith:sessionId];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setObject:sessionModel.receiveTranslateChannel.length > 0 ? sessionModel.receiveTranslateChannel : @"" forKey:@"channelCode"];
            [dict setObject:sessionModel.receiveTranslateLanguage.length > 0 ? sessionModel.receiveTranslateLanguage : @"" forKey:@"to"];
            [dict setObject:translationString forKey:@"content"];
            [dict setObject:weakSelf.myUserID forKey:@"userUid"];
    
            [IMSDKManager imSdkTranslateYuueeContent:dict onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
                NSMutableString *result = [NSMutableString stringWithString:(NSString *)data];
                NSMutableString *sendResultStr = [NSMutableString string];
                [sendResultStr appendString:result.length > 0 ? result : @""];
                [sendResultStr appendString:atString.length > 0 ? atString : @""];
                [sendResultStr appendString:emojiString.length > 0 ? emojiString : @""];
                if (success) {
                    success(sendResultStr);
                }
            } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
                if (code == LingIMHttpResponseTranslateYueeNoBalanceStatus) {
                    sessionModel.isSendAutoTranslate = 0;
                    sessionModel.isReceiveAutoTranslate = 0;
                    [DBTOOL insertOrUpdateSessionModelWith:sessionModel];
                    
                    [weakSelf.userDelegate imSdkUserCloseAutoTranslateAndErrorCode:code errorMsg:msg sessionModel:sessionModel];
                } else if (code == LingIMHttpResponseTranslateYueeUnbindStatus) {
                    [weakSelf.userDelegate imSdkUserCloseAutoTranslateAndErrorCode:code errorMsg:msg sessionModel:sessionModel];
                } else {
                    [weakSelf.userDelegate imSdkUserCloseAutoTranslateAndErrorCode:code errorMsg:msg sessionModel:sessionModel];
                }
                if (failure) {
                    failure(code,msg,traceId);
                }
            }];
        }
    }];
}

#pragma mark - ============================= 分割线 =====================================

#pragma mark - 注册阅译账号并自动绑定
- (void)imSdkTranslateRegisterBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateRegisterBindAccount:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 绑定阅译账号
- (void)imSdkTranslateBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateBindAccount:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 解绑阅译账号
- (void)imSdkTranslateUnBindAccount:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateUnBindAccount:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 我绑定的阅译账号信息
- (void)imSdkTranslateGetYuueeAccountInfo:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateGetYuueeAccountInfo:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 调用阅译系统去翻译
- (void)imSdkTranslateYuueeContent:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateYuueeContent:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取所有翻译通道和通道下的语种
- (void)imSdkTranslateGetChannelLanguage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateGetChannelLanguage:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 获取当前登录用户所有翻译配置
- (void)imSdkTranslateGetUserAllTranslateConfig:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateGetUserAllTranslateConfig:params onSuccess:onSuccess onFailure:onFailure];
}

#pragma mark - 上传用户翻译配置
- (void)imSdkTranslateUploadNewTranslateConfig:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure {
    
    [[NoaIMHttpManager sharedManager] translateUploadNewTranslateConfig:params onSuccess:onSuccess onFailure:onFailure];
}

@end
