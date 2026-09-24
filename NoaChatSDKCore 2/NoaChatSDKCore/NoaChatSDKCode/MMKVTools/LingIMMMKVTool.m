//
//  LingIMMMKVTool.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/3.
//

#import "LingIMMMKVTool.h"
#import <MMKV/MMKV.h>

//单例
static dispatch_once_t onceToken;

@interface LingIMMMKVTool ()
//发送聊天消息缓存
@property (nonatomic, strong) MMKV *sendChatMessageMMKV;
//用户信息
@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *userToken;
@end

@implementation LingIMMMKVTool

#pragma mark - 单例
+ (instancetype)sharedTool {
    static LingIMMMKVTool *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        [_manager configTool];
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [LingIMMMKVTool sharedTool];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [LingIMMMKVTool sharedTool];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [LingIMMMKVTool sharedTool];
}
// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearTool {
    onceToken = 0;
}
- (void)configTool {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //1.2.14之后，必须先调用此方法在主线程
        [MMKV initializeMMKV:nil];
        weakSelf.sendChatMessageMMKV = [MMKV mmkvWithID:@"ChatMessage"];
    });
    
}


#pragma mark - ******业务******
- (void)configMMKVToolWith:(NSString *)userID token:(NSString *)userToken {
    _userID = userID;
    _userToken = userToken;
}
#pragma mark - 发送的消息存储到MMKV
- (BOOL)addSendChatMessageWith:(IMChatMessage *)chatMessage {
    NSString *msgID = chatMessage.msgId;
    NSString *keyStr = [NSString stringWithFormat:@"%@-%@",_userID,msgID];
    return [_sendChatMessageMMKV setData:chatMessage.delimitedData forKey:keyStr];
}

#pragma mark - 根据消息ID获取发送的消息
- (IMChatMessage *)getSendChatMessageWith:(NSString *)msgID {
    NSString *keyStr = [NSString stringWithFormat:@"%@-%@",_userID,msgID];
    NSData *messageData = [_sendChatMessageMMKV getDataForKey:keyStr];
    GPBCodedInputStream *stream = [GPBCodedInputStream streamWithData:messageData];
    IMChatMessage *message = [IMChatMessage parseDelimitedFromCodedInputStream:stream extensionRegistry:nil error:nil];
    return message;
}

#pragma mark - 根据消息ID删除发送的消息
- (void)deleteSendChatMessageWith:(NSString *)msgID {
    NSString *keyStr = [NSString stringWithFormat:@"%@-%@",_userID,msgID];
    [_sendChatMessageMMKV removeValueForKey:keyStr];
}

#pragma mark - 获取全部发送的消息(如果有则重新发送这些消息)
- (NSArray <IMChatMessage *> *)getAllSendChatMessage {
    NSMutableArray *allArray = [NSMutableArray array];
    
    for (NSString *keyStr in _sendChatMessageMMKV.allKeys) {
        NSString *tempUserID = [[keyStr componentsSeparatedByString:@"-"] firstObject];
        if ([tempUserID isKindOfClass:[NSString class]] && [tempUserID isEqualToString:_userID]) {
            //找到自己发送的消息
            NSData *messageData = [_sendChatMessageMMKV getDataForKey:keyStr];
            GPBCodedInputStream *stream = [GPBCodedInputStream streamWithData:messageData];
            IMChatMessage *message = [IMChatMessage parseDelimitedFromCodedInputStream:stream extensionRegistry:nil error:nil];
            [allArray addObject:message];
        }
    }
    
    return allArray;
}
#pragma mark - 清空所有发送的消息
- (void)clearAllSendChatMessage {
    [_sendChatMessageMMKV clearAll];
}
#pragma mark - 根据消息ID获取回话表名称
- (NSString *)getSessionIDWith:(NSString *)msgID {
    IMChatMessage *message = [self getSendChatMessageWith:msgID];
    NSString *sessionID;//会话ID
    if (message.cType == ChatType_SingleChat) {
        //单聊消息
        if ([message.from isEqualToString:_userID]) {
            //我发的消息
            sessionID = message.to;
        }else {
            //对方发的消息
            sessionID = message.from;
        }
    }else {
        //群聊消息
        sessionID = message.to;
        
    }
    return sessionID;
    
    //NSString *sessionTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",_userID,sessionID];
    //return sessionTableName;
}
@end
