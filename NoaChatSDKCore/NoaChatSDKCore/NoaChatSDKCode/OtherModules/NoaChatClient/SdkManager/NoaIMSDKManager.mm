//
//  NoaIMSDKManager.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

#import "NoaIMSDKManager.h"
#import "NoaIMSDKManager+ChatMessage.h"//聊天类型消息处理
#import "NoaIMSDKManager+ServiceMessage.h"//系统类型消息处理
#import "NoaIMSDKManager+Session.h"//会话处理
#import "NoaIMSDKManager+SyncServer.h"//同步数据
#import "NoaIMSDKManager+AppInfo.h"//App配置信息或者敏感词相关
#import "NoaIMSDKManager+Group.h"
#import "NoaIMSDKManager+Logan.h"//日志模块

#import "NoaIMDBTool.h"//数据库工具
#import "NoaIMHttpManager.h"//Http
#import <MMKV/MMKV.h>
#import "NoaIMSocketHostOptions.h"
#import "NoaIMSocketManagerTool+LingImTcpReplaceHttp.h"
#import "LoggerWrapper.h"


//单例
static dispatch_once_t onceToken;

@interface NoaIMSDKManager ()
<
NoaConnectDelegate,
NoaMessageDelegate,
NoaUserDelegate,
NoaGroupDelegate
>
//用户ID
@property (nonatomic, copy) NSString *userID;
//用户token
@property (nonatomic, copy) NSString *userToken;
/// 当前请求使用的设备凭证，只保存在 SDK 内存中，不负责持久化
@property (nonatomic, copy, nullable) NSString *deviceSecret;
//用户昵称
@property (nonatomic, copy) NSString *userNickname;
//用户头像
@property (nonatomic, copy) NSString *userAvatar;
//实时翻译(是否自动翻译接收到的文字消息)
@property (nonatomic, assign) NSInteger isAutoTranslate;
//实时翻译(接收到的消息内容目标翻译通道)
@property (nonatomic, copy) NSString * translateChannel;
//实时翻译(接收到的消息内容目标翻译语种)
@property (nonatomic, copy) NSString * translateLanguage;
//ssoxin'x
@property (nonatomic, copy) NSString *ssoDetailInfo;
//liceseId
@property (nonatomic, copy) NSString *currentLiceseId;
//captchaChannel
@property (nonatomic, assign)NSInteger captchaChannel;
//tenantCode
@property (nonatomic, copy) NSString *tenantCode;
//短连接地址
@property (nonatomic, copy) NSString *cimHost;
//短连接端口
@property (nonatomic, copy) NSString *cimPort;
//长连接地址
@property (nonatomic, copy) NSString *apiHost;
//租户标识
@property (nonatomic, copy) NSString *orgName;
//是否配置了用户信息
@property (nonatomic, assign) BOOL configedUserInfo;
//上次同步数据时间戳
@property (nonatomic, assign)long long lastSyncTime;

@end

@implementation NoaIMSDKManager

#pragma mark - 单例
+ (instancetype)sharedTool {
    static NoaIMSDKManager *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不再使用alloc方法，因为已经重写了allocWithZone方法，所以这里要调用父类的方法
        _manager = [[super allocWithZone:NULL] init];
        
        [_manager configDelegate];
        [_manager syncServerTime];
    });
    return _manager;
}
// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [NoaIMSDKManager sharedTool];
}
// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [NoaIMSDKManager sharedTool];
}
// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [NoaIMSDKManager sharedTool];
}


// 单例一般不需要清空，但是在执行某些功能的时候，防止数据清空不及时可以清空一下
- (void)clearTool {
    onceToken = 0;
}

/// 配置SDK代理
- (void)configDelegate {
    //连接代理
    cim_function_setConnectDelegate(self);
    //消息代理
    cim_function_setMessageDelegate(self);
    //用户代理
    cim_function_setUserDelegate(self);
    //群聊代理
    cim_function_setGroupDelegate(self);
    //Http代理
    cim_function_setHttpDelegate(self);
}

/// 同步一下服务器上的时间戳
- (void)syncServerTime {
    //先配置一下默认的时间戳，防止请求接口的逻辑不生效造成空值
    [ZDateRequestTool configDefaultServerTime];
    //获取服务端的时间戳
    [ZDateRequestTool requestDate];
}

#pragma mark - ******业务******
/// 1.SDK api 相关信息 配置/更新 HTTP
- (void)configSDKApiWith:(NoaIMSDKApiOptions *)apiOptions {
    //只对有值的内容进行更新
    if (apiOptions.imApi.length > 0) _apiHost = apiOptions.imApi;
    if (apiOptions.imOrgName.length > 0) _orgName = apiOptions.imOrgName;
}

/// 3.SDK user 相关信息 配置/更新
- (void)configSDKUserWith:(NoaIMSDKUserOptions *)userOptions {
    
    //记录一下原先的用户token，因为token会失效，所以token更新后需要重连
    NSString *tempUserToken = [_userToken mutableCopy];
    
    //只对有值的内容进行更新
    if (userOptions.userID.length > 0) _userID = userOptions.userID;
    if (userOptions.userNickname.length > 0) _userNickname = userOptions.userNickname;
    if (userOptions.userAvatar.length > 0) _userAvatar = userOptions.userAvatar;
    if (userOptions.userToken.length > 0) _userToken = userOptions.userToken;
    
    if (tempUserToken.length > 0) {
        
        //目前的功能 只有更新了用户的token信息，需要更新Socket
        if (![tempUserToken isEqualToString:_userToken]) {
            [self configSDKSocketUserInfo];
            LoggerInfo([NSString stringWithFormat:@"通过 - (void)configSDKUserWith:(LingIMSDKUserOptions *)userOptions 调用configSDKSocket, ip = %@, port = %@", _cimHost, _cimPort]);
        }
        
    }else {
        
        //第一次配置用户信息
        //首次初始化数据库
        [self configSDKDB];
        _configedUserInfo = YES;
        
    }
}

/// SDK重连机制
- (void)reconnectedSDK {
    //TCP竞速失败，延迟5秒后，重新走一次TCP竞速，直到TCP竞速成功，执行socket的重连机制
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        cim_function_reconnected();
    });
}

///SDK SSO 相关信息 配置/更新
/// @param ssoInfoStr 邀请码 或者 IP/域名+端口
- (void)configSDKSsoInfo:(NSString *)ssoInfoStr {
    if (ssoInfoStr.length > 0) _ssoDetailInfo = ssoInfoStr;
}

/// 获取我的ID
- (NSString *)myUserID {
    return _userID.length ? _userID : @"";
}
/// 获得我的token
- (NSString *)myUserToken {
    NSString * token = _userToken.length ? _userToken : @"";
    return token;
}
/// 配置当前请求使用的设备凭证；空值用于清除现有凭证
- (void)configSDKDeviceSecret:(nullable NSString *)deviceSecret {
    _deviceSecret = deviceSecret.length > 0 ? [deviceSecret copy] : nil;
}
/// 获取当前请求使用的设备凭证；未配置时返回空字符串
- (NSString *)myDeviceSecret {
    return _deviceSecret.length > 0 ? _deviceSecret : @"";
}
/// 获取我的昵称
- (NSString *)myUserNickname {
    return _userNickname.length ? _userNickname : @"";
}

//更新昵称
- (void)configNewUserNickName:(NSString *)nickName {
    if (nickName.length > 0) {
        _userNickname = nickName;
    }
}
/// 获取我的头像
- (NSString *)myUserAvatar {
    return _userAvatar.length ? _userAvatar : @"";
}

//更新头像
- (void)configNewUserAvatar:(NSString *)avatar {
    if (avatar.length > 0) {
        _userAvatar = avatar;
    }
}

/// 获取我的ssoInfo
- (NSString *)mySsoInfo {
    return _ssoDetailInfo.length ? _ssoDetailInfo : @"";
}

/// 获取当前liceseId
- (NSString *)currentLiceseId {
    return _currentLiceseId.length > 0 ? _currentLiceseId : @"";
}

- (NSInteger)captchaChannel {
    return _captchaChannel;
}

/// 获取tenantCode
- (NSString *)tenantCode {
    return _tenantCode.length > 0 ? _tenantCode : @"";
}

- (long long)lastSyncSessionTime {
    NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_SESSION_TIME_KEY, _userID];
    long long localLastSyncSessionTime = [[MMKV defaultMMKV] getInt64ForKey:key];
    return localLastSyncSessionTime;
}

/// 上次同步通讯录分组数据时间戳
- (long long)lastSyncSectionTime {
    NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_SECTION_TIME_KEY, _userID];
    long long localLastSyncSectionTime = [[MMKV defaultMMKV] getInt64ForKey:key];
    return localLastSyncSectionTime;
}

/// 上次同步分组好友数据时间戳
- (long long)lastSyncFriendTime {
    BOOL isBulkingSyncFriend = [[MMKV defaultMMKV] getBoolForKey:@"isSyncAllFriend"];
    if (isBulkingSyncFriend == NO) {
        return 0;
    }
    NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_FRIEND_TIME_KEY, _userID];
    long long localLastSyncFriendTime = [[MMKV defaultMMKV] getInt64ForKey:key];
    return localLastSyncFriendTime;
}

/// 上次同步群组列表时间戳
- (long long)lastSyncGroupTime {
    NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_GROUP_TIME_KEY, _userID];
    long long localLastSyncGroupTime = [[MMKV defaultMMKV] getInt64ForKey:key];
    return localLastSyncGroupTime;
}

/// 清除用户信息及当前请求使用的设备凭证
- (void)clearMyUserInfo {
    _userID = nil;
    _userToken = nil;
    _deviceSecret = nil;
    _userNickname = nil;
    _userAvatar = nil;
    //清除日志模块用户信息
    [self imSdkClearLoganOption];


}

/// 获取当前邀请码或者IP/域名+端口号下，储存 敏感词 的表名
- (NSString *)getTableNameForSensitive {
    return [NSString stringWithFormat:@"CIMDB_Sensitive_v2_%@", IMSDKManager.mySsoInfo];;
}

//设置请求的域名
- (void)configApiHost:(NSString *)apiHost {
    _apiHost = apiHost;
}

/// 获得接口地址
-(NSString *)apiHost{
    return _apiHost.length ? _apiHost : @"";
}
/// 获得多租户信息
- (NSString *)orgName{
    return _orgName.length ? _orgName : @"";
}
/// SDK版本号
- (NSString *)sdkVersion {
    return @"1.0.0";
}

/// SDK数据库相关处理
- (void)configSDKDB {
    if (_userID.length > 0 && _userToken.length > 0) {
        BOOL dbResult = [DBTOOL configDBWith:_userToken userID:_userID];
        if (dbResult) {
            //socket配置
            [self configSDKSocketUserInfo];
            LoggerInfo([NSString stringWithFormat:@"通过 - (void)configSDKDB 调用configSDKSocket, ip = %@, port = %@", _cimHost, _cimPort]);
            //MMKV配置
            [MMKVTOOL configMMKVToolWith:_userID token:_userToken];
        }
    }else {
        CIMLog(@"LingIMSDKManager>>>缺少用户信息，数据库初始化失败");
    }
}

/// SDK长连接相关处理
- (void)configSDKSocketUserInfo {
    if (_userID.length > 0 && _userToken.length > 0) {
        //用户信息
        NoaIMSocketUserOptions *userOptions = [NoaIMSocketUserOptions new];
        userOptions.userID = _userID;
        userOptions.userToken = _userToken;
        
        cim_function_configUser(userOptions);
        
        LoggerInfo([NSString stringWithFormat:@"调用LingIMSDKManager - - (void)configSDKSocket, ip = %@, port = %@", _cimHost, _cimPort]);
        
    }else {
        CIMLog(@"LingIMSDKManager>>>缺少部分用户信息和网关信息，socket初始化失败");
    }
}

/// @param liceseId 邀请码
- (void)configSDKLiceseId:(NSString *)liceseId {
    _currentLiceseId = liceseId;
}

/// 验证类型 2：图形验证码  3：腾讯无感验证 1: 关闭验证码 4: 阿里无感验证
- (void)configSDKCaptchaChannel:(NSInteger)captchaChannel {
    _captchaChannel = captchaChannel;
}

/// @param tenantCode 接口验签
- (void)configSDKTenantCode:(NSString *)tenantCode {
    _tenantCode = tenantCode;
}

#pragma mark - **********工具类代理相关**********
/// 添加连接代理
- (void)addConnectDelegate:(id <NoaToolConnectDelegate> )delegate {
    [self.connectDelegate addDelegate:delegate delegateQueue:dispatch_get_main_queue()];
}
/// 移除连接代理
- (void)removeConnectDelegate:(id <NoaToolConnectDelegate> )delegate {
    [self.connectDelegate removeDelegate:delegate];
}

/// 添加消息代理
- (void)addMessageDelegate:(id <NoaToolMessageDelegate> )delegate {
    [self.messageDelegate addDelegate:delegate delegateQueue:dispatch_get_main_queue()];
}
/// 移除消息代理
- (void)removeMessageDelegate:(id <NoaToolMessageDelegate> )delegate {
    [self.messageDelegate removeDelegate:delegate];
}

/// 添加用户代理
- (void)addUserDelegate:(id<NoaToolUserDelegate>)delegate {
    [self.userDelegate addDelegate:delegate delegateQueue:dispatch_get_main_queue()];
}
/// 移除用户代理
- (void)removeUserDelegate:(id<NoaToolUserDelegate>)delegate {
    [self.userDelegate removeDelegate:delegate];
}

/// 添加会话代理
- (void)addSessionDelegate:(id<NoaToolSessionDelegate>)delegate {
    [self.sessionDelegate addDelegate:delegate delegateQueue:dispatch_get_main_queue()];
}
/// 移除回话代理
- (void)removeSessionDelegate:(id<NoaToolSessionDelegate>)delegate {
    [self.sessionDelegate removeDelegate:delegate];
}

/// 添加群组代理
- (void)addGroupDelegate:(id<CIMToolGroupDelegate>)delegate {
    [self.groupDelegate addDelegate:delegate delegateQueue:dispatch_get_main_queue()];
}
/// 移除群组代理
- (void)removeGroupDelegate:(id<CIMToolGroupDelegate>)delegate {
    [self.groupDelegate removeDelegate:delegate];
}

/// 添加多媒体会话代理(音视频通话)
- (void)addMediaCallDelegate:(id <NoaIMMediaCallDelegate> )delegate {
    [self.mediaCallDelegate addDelegate:delegate delegateQueue:dispatch_get_main_queue()];
}
/// 移除多媒体会话代理(音视频通话)
- (void)removeMediaCallDelegate:(id <NoaIMMediaCallDelegate> )delegate {
    [self.mediaCallDelegate removeDelegate:delegate];
}

#pragma mark - CIMMessageDelegate
- (void)noaMessageSendSuccess:(IMChatMessageACK *)messageACK {
    CIMLog(@"LingIMSDKManager>>>消息发送成功:消息ID:%@--服务端生成的ID:%@",messageACK.ackMsgId,messageACK.sMsgId);
    
    //更新数据库发送消息内容
    NSString *sessionID = [MMKVTOOL getSessionIDWith:messageACK.ackMsgId];
    //忽略掉发送的ToACK消息 的 ACK消息
    if (sessionID.length > 0) {
        //发送的聊天信息成功
        NoaIMChatMessageModel *model = [IMSDKManager toolGetOneChatMessageWithMessageID:messageACK.ackMsgId sessionID:sessionID];
        model.messageSendType = CIMChatMessageSendTypeSuccess;
        model.sendFailureReason = CIMMessageSendFailureReasonUnknown;
        model.serviceMsgID = messageACK.sMsgId;
        model.sendTime = messageACK.sendTime > 0 ? messageACK.sendTime : model.sendTime;
        //更新会话和消息表
        [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        
        //移除MMKV存储的发送消息
        [MMKVTOOL deleteSendChatMessageWith:messageACK.ackMsgId];
        
        //代理回调UI层渲染
        [self.messageDelegate cimToolChatMessageSendSuccess:messageACK];
    }
}

- (void)noaMessageSendFail:(NSString *)messageID {
    [self noaMessageSendFail:messageID reason:CIMMessageSendFailureReasonUnknown];
}

/// 将底层发送失败状态落库并向界面透传结构化失败原因。
/// @param messageID 发送失败的本地消息 ID。
/// @param reason 供界面展示的失败原因分类。
- (void)noaMessageSendFail:(NSString *)messageID reason:(CIMMessageSendFailureReason)reason {
    CIMLog(@"LingIMSDKManager>>>消息发送失败:消息ID:%@",messageID);
    
    //更新数据库发送消息内容
    NSString *sessionID = [MMKVTOOL getSessionIDWith:messageID];
    //忽略掉发送的ToACK消息 的 ACK消息
    if (sessionID.length > 0) {
        NoaIMChatMessageModel *model = [IMSDKManager toolGetOneChatMessageWithMessageID:messageID sessionID:sessionID];
        model.messageSendType = CIMChatMessageSendTypeFail;
        model.sendFailureReason = reason;
        [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
        
        //移除MMKV存储的发送消息
        [MMKVTOOL deleteSendChatMessageWith:messageID];
        
        //代理回调UI层渲染
        if ([self.messageDelegate hasDelegateThatRespondsToSelector:@selector(cimToolChatMessageSendFail:reason:)]) {
            [self.messageDelegate cimToolChatMessageSendFail:messageID reason:reason];
        } else {
            [self.messageDelegate cimToolChatMessageSendFail:messageID];
        }
    }
}
- (void)noaMessageChatReceiveWith:(IMMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到聊天消息");
    [IMSDKManager toolDealReceiveChatMessage:message];
}
- (void)noaMessageHaveRead:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到已读消息，我的消息被对方已读");
    [IMSDKManager toolDealReceiveServiceForReadMessage:message];
}
- (void)noaMessageUpdateMessageRead:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到 我 已读 了消息 成功，红点进行处理");
    //将原来的发送 消息已读 接口成功后，红点-1，放在此处处理
    [IMSDKManager toolDealReceiveServiceForUpdateMessageRead:message];
}

- (void)noaMessageSystemReceiveWith:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到系统消息");
    [IMSDKManager toolDealReceiveServiceMessage:message];
}

- (void)noaMessageSystemCustomEventWith:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到系统消息-自定义事件");
    [self imSdkDealReceiveServiceMessageForCustomEvent:message];
}

- (void)noaMessageSystemMessageTimeDeleteWith:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到系统消息-消息定时自动删除消息");
    [self imSdkDealReceiveServiceMessageForMessageTimeDelete:message];
}

- (void)noaMessageSystemMessageUpdateSensitiveWith:(IMServerMessage * _Nullable)message {
    CIMLog(@"LingIMSDKManager>>>接收到系统消息-更新敏感词");
    [self syncAppSensitiveFromServer];
}

- (void)noaMessageSystemMessageSynchroMessageWith:(IMServerMessage * _Nullable)message {
    [self syncUserSessionStatus:message];
}


- (void)noaDialogMessageTopChangeEventWith:(IMServerMessage *)message {
    [self toolDealReceiveServiceMessageForMessageTop:message];
}

// 接收 Socket 分发的编辑通知，并交给消息服务统一更新数据库和 UI。
- (void)noaEditOneMessageWith:(IMServerMessage *)message {
    [self toolDealReceiveServiceMessageForMessageEdit:message];
}

- (void)noaDialogReadTagChangeEventWith:(IMServerMessage * _Nullable)message {
    DialogReadTagChangeEventMessage *dialogReadTagMessage = message.dialogReadTagChangeEventMessage;
    LingIMSessionModel *sessionModel = [IMSDKManager toolCheckMySessionWith:dialogReadTagMessage.peerUid];
    sessionModel.readTag = dialogReadTagMessage.readTag;
    if (sessionModel.readTag == 0) {
        sessionModel.sessionUnreadCount = 0;
        //将最新消息sMsgId赋值给dialogReadTag
        NSMutableDictionary *clearReadNumSMsgIdDict = [[[MMKV defaultMMKV] getObjectOfClass:[NSDictionary class] forKey:@"clearReadNumSMsgIdDictKey"] mutableCopy];
        if (clearReadNumSMsgIdDict == nil) {
            clearReadNumSMsgIdDict = [[NSMutableDictionary alloc] init];
        }
        [clearReadNumSMsgIdDict setObject:(sessionModel.sessionLatestMessage.serviceMsgID ? sessionModel.sessionLatestMessage.serviceMsgID : @"0") forKey:sessionModel.sessionID];
        [[MMKV defaultMMKV] setObject:[clearReadNumSMsgIdDict copy] forKey:@"clearReadNumSMsgIdDictKey"];
    }
    //将sessionModel更新到本地，并告知UI层刷新会话列表更新本会话未读数，已经更新所有会话的未读总数
    [IMSDKManager toolUpdateSessionWith:sessionModel];
}

#pragma mark - 签到提醒
- (void)noaMessageSystemMessageSignInReminder:(IMServerMessage * _Nullable)message {
    CIMLog(@"LingIMSDKManager>>>接收到系统消息-签到提醒");
    NoaIMChatMessageModel *model = [NoaIMChatMessageModel new];
    model.serverMessageProtobuf = message.delimitedData;//protobuf
    model.messageType = CIMChatMessageType_ServerMessage;//群聊里的系统通知消息 提示
    model.messageSendType = CIMChatMessageSendTypeSuccess;//接收到的消息，发送成功
    model.chatType = CIMChatType_SignInReminder;//签到提醒
    model.sendTime = message.sendTime;//发送时间
    model.toSource = message.toSource;//发送的设备
    model.msgID = [[NoaIMManagerTool sharedManager] getMessageID];//本地生成消息ID
    model.serviceMsgID = message.sMsgId;//服务端返回消息ID
    model.chatMessageReaded = NO;//系统通知消息，默认已读
    model.messageStatus = 1;//接收到的消息，默认是正常消息
    //更新会话列表+存储到数据库+进行UI上的展示
    [IMSDKManager toolInsertOrUpdateSessionWith:model isRemind:YES];
}

/// 接收到系统通知消息 - 用户角色权限发生变化
- (void)noaMessageSystemMessageUserRoleAuthority:(IMServerMessage * _Nullable)message {
    
    [self.sessionDelegate imSdkSessionUpdateUserRoleAuthority];
    [self.messageDelegate imSdkChatMessageUpdateUserRoleAuthority];
}

#pragma mark - CIMUserDelegate
- (void)noaUserConnectSuccess {
    CIMLog(@"LingIMSDKManager>>>用户认证通过");
    [self.userDelegate cimToolUserConnectSuccess];
    
    //MMKV是否有未发送的消息
    [IMSDKManager toolMMKVSendChatMessage];
    //更新会话列表数据
    [self syncSessionsFromServer];
    //更新好友列表数据
    [self syncContactsFromServer];
    //更新群组列表数据
    [self syncGroupsFromServer];
    //更新消息提醒方式
    [self syncMessageRemindFromServer];
    //更新敏感词
    [self syncAppSensitiveFromServer];
}

//socket认证断开连接，且不执行重连 或 socket的Auth认证其他的错误码，统一执行进入登录界面的逻辑
- (void)noaUserConnectLogoutWithCode:(NSInteger)errorCode messsage:(NSString *)message {
    CIMLog(@"LingIMSDKManager>>>用户退出登录");
    /* 40015, "该账号被禁用"
     40029, "该设备已被禁止登录"
     40030, "客户端IP已被禁止登录"
     */
    
    if (errorCode == 40015) {
        //该账号被禁用
        [self.userDelegate imSdkUserForceLogout:999 message:message];
    } else if (errorCode == 40029) {
        //该设备已被禁止登录
        [self.userDelegate imSdkUserForceLogout:11 message:message];
    } else if (errorCode == 40030) {
        //客户端IP已被禁止登录
        [self.userDelegate imSdkUserForceLogout:10 message:message];
    } else if (errorCode == 900017) {
        //用户已经注销
        [self.userDelegate imSdkUserForceLogout:888 message:message];
    } else if (errorCode == 90018) {
        //登录IP不在白名单
        [self.userDelegate imSdkUserForceLogout:90018 message:message];
    } else {
        [self.userDelegate imSdkUserForceLogout:999 message:@""];
    }
}

- (void)noaUserAuthTokenNeedRefresh {
    CIMLog(@"LingIMSDKManager>>>用户token需要刷新");
    [SOCKETMANAGERTOOL authRefreshTokenExpiredWithSuccessFunc:nil FailureFunc:nil];
}

- (void)noaUserFriendInvite:(FriendInviteMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到用户的好友申请");
    //新朋友+1
    [self.userDelegate cimToolUserFriendInvite:message];
}

- (void)noaUserFriendConfirm:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到用户好友申请系统通知");
    [IMSDKManager toolDealReceiveServiceMessageForUserFriendConfirm:message];
}

- (void)noaUserFriendDelete:(FriendDelMessage *)message {
    CIMLog(@"LingIMSDKManager>>>告知用户，删除好友的审核通过了")
    //[self.userDelegate cimToolUserFriendDelete:message];
    LingIMFriendModel *friendModel = [DBTOOL checkMyFriendWith:message.fUid];
    [DBTOOL deleteMyFriendWith:message.fUid];
    [self.userDelegate imSdkUserFriendDelete:friendModel];
    [self.userDelegate imSdkUserFriendGroupChange];
}

- (void)noaUserFriendNoneExist:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>告知发消息的人，该好友不存在")
    [self.userDelegate cimToolUserFriendNoneExist:message];
    [IMSDKManager toolDealReceiveServiceMessageForUserFriendNoneExist:message];
}

- (void)noaUserFriendLineStatus:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>好友在线状态");
    [self toolDealReceiveServiceMessageForUserFriendOnline:message];
}

- (void)noaUserFriendBlack:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>好友拉黑提示消息");
    [IMSDKManager toolDealReceiveServiceMessageForUserFriendBlack:message];
}

- (void)noaUserAccountClose:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>好友账号注销提示消息");
    [IMSDKManager toolDealReceiveServiceMessageForUserAccoutClose:message];
}

- (void)noaSdkUserForceLogout:(NSInteger)type message:(nonnull NSString *)message {
    CIMLog(@"强制下线");
    [self.userDelegate imSdkUserForceLogout:type message:message];
}

- (void)noaSdkUpdateHttpNodeWith:(NSString *)httpNode {
    CIMLog(@"更新httpNode");
    [self.userDelegate cimUserUpdateHttpNode:httpNode];
}

- (void)noaSdkUnableHttpNodeWith:(NSString *)tipContent {
    CIMLog(@"无可用httpNode时给出提示语");
    [self.userDelegate cimUserUnableHttpNode:tipContent];
}

/// 用户token失效，触发刷新token接口获取最新token并更新给KIT层
- (void)noaSdkRefreshUsetToken:(NSString *)userToken errorMsg:(NSString *)errorMsg {
    [self.userDelegate imSdkRefreshUsetToken:userToken errorMsg:errorMsg];
}

/// 账号封禁、设备封禁、IP封禁
- (void)noaSdkRefreshTokenAuthBanned:(NSInteger)errorCode {
    [self.userDelegate imSdkRefreshTokenAuthBanned:errorCode];
}

- (void)noaSdkFriendGroup:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>好友分组相关消息");
    [self toolDealReceiveServiceMessageForFriendGroup:message];
}

- (void)noaSdkFriendGroupForFriend:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>好友分组下的好友管理相关消息");
    [self toolDealReceiveServiceMessageForFriendGroup:message];
}

- (void)noaSdkReceiveTranslateConfigUplate:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>用户上传了翻译配置信息");
    [self toolDealReceiveServiceMessageForUpdateTranslateConfig:message];
}

#pragma mark - CIMGroupDelegate
- (void)noaGroupTipServerMessage:(IMServerMessage *)message {
    CIMLog(@"LingIMSDKManager>>>接收到群聊相关系统通知，消息类型%d",message.sMsgType);
    [IMSDKManager toolDealReceiveServiceMessageForGroupTip:message];
}
#pragma mark - CIMConnectDelegate
//socket正在连接中
- (void)noaConnecting {
    [self.connectDelegate cimToolConnecting];
}
//socket连接成功
- (void)noaConnectSuccess {
    [self.connectDelegate cimToolConnectSuccess];
}
//socked重连成功
- (void)noaReConnectSuccess {
    [self.connectDelegate cimToolReConnectSuccess];
    //当socket重连成功后，需要重新(增量)拉取一次会话列表，解决socket断开期间会话列表发生变化
    [self reconnectSyncSessionsFromServer];
}
//socket连接失败
- (void)noaConnectFailWithError:(NSError *)error {
    [self.connectDelegate cimToolConnectFailWith:error];
}
//socket断开连接
- (void)noaDisconnect {
    [self.connectDelegate cimToolDisconnect];
}

#pragma mark - **********懒加载**********
- (OIMGCDMulticastDelegate<NoaToolConnectDelegate> *)connectDelegate {
    if (!_connectDelegate) {
        _connectDelegate = (OIMGCDMulticastDelegate <NoaToolConnectDelegate> *) [[OIMGCDMulticastDelegate alloc] init];
    }
    return _connectDelegate;
}
- (OIMGCDMulticastDelegate<NoaToolMessageDelegate> *)messageDelegate {
    if (!_messageDelegate) {
        _messageDelegate = (OIMGCDMulticastDelegate <NoaToolMessageDelegate> *) [[OIMGCDMulticastDelegate alloc] init];
    }
    return _messageDelegate;
}
- (OIMGCDMulticastDelegate<NoaToolUserDelegate> *)userDelegate {
    if (!_userDelegate) {
        _userDelegate = (OIMGCDMulticastDelegate <NoaToolUserDelegate> *) [[OIMGCDMulticastDelegate alloc] init];
    }
    return _userDelegate;
}
- (OIMGCDMulticastDelegate<NoaToolSessionDelegate> *)sessionDelegate {
    if (!_sessionDelegate) {
        _sessionDelegate = [(OIMGCDMulticastDelegate <NoaToolSessionDelegate> *) [OIMGCDMulticastDelegate alloc] init];
    }
    return _sessionDelegate;
}
- (OIMGCDMulticastDelegate<CIMToolGroupDelegate> *)groupDelegate {
    if (!_groupDelegate) {
        _groupDelegate = [(OIMGCDMulticastDelegate <CIMToolGroupDelegate> *) [OIMGCDMulticastDelegate alloc] init];
    }
    return _groupDelegate;
}
- (OIMGCDMulticastDelegate<NoaIMMediaCallDelegate> *)mediaCallDelegate {
    if (!_mediaCallDelegate) {
        _mediaCallDelegate = [(OIMGCDMulticastDelegate <NoaIMMediaCallDelegate> *) [OIMGCDMulticastDelegate alloc] init];
    }
    return _mediaCallDelegate;
}
- (dispatch_queue_t)sessionListUpdateQueue {
    if (!_sessionListUpdateQueue) {
        _sessionListUpdateQueue = dispatch_queue_create("com.CIMSDKCode.sessionListUpdateQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _sessionListUpdateQueue;
}
- (dispatch_queue_t)friendGroupListUpdateQueue {
    if (!_friendGroupListUpdateQueue) {
        _friendGroupListUpdateQueue = dispatch_queue_create("com.CIMSDKCode.friendGroupListUpdateQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _friendGroupListUpdateQueue;
}
- (dispatch_queue_t)contactsListUpdateQueue {
    if (!_contactsListUpdateQueue) {
        _contactsListUpdateQueue = dispatch_queue_create("com.CIMSDKCode.contactsListUpdateQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _contactsListUpdateQueue;
}
- (dispatch_queue_t)friendListQueue {
    if (!_friendListQueue) {
        _friendListQueue = dispatch_queue_create("com.CIMSDKCode.friendListQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _friendListQueue;
}
- (dispatch_queue_t)friendOnlineQueue {
    if (!_friendOnlineQueue) {
        _friendOnlineQueue = dispatch_queue_create("com.CIMSDKCode.friendOnlineQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _friendOnlineQueue;
}
- (dispatch_queue_t)groupListQueue {
    if (!_groupListQueue) {
        _groupListQueue = dispatch_queue_create("com.CIMSDKCode.groupListQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _groupListQueue;
}
- (dispatch_queue_t)imSdkUpdateAppSensitiveQueue {
    if (!_imSdkUpdateAppSensitiveQueue) {
        _imSdkUpdateAppSensitiveQueue = dispatch_queue_create("com.CIMSDKCode.imSdkUpdateAppSensitiveQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _imSdkUpdateAppSensitiveQueue;
}
- (dispatch_queue_t)unreadCountQueue {
    if (!_unreadCountQueue) {
        _unreadCountQueue = dispatch_queue_create("com.CIMSDKCode.unreadCountQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _unreadCountQueue;
}
- (dispatch_queue_t)appUserAndSessionTranslateInfoServerQueue {
    if (!_appUserAndSessionTranslateInfoServerQueue) {
        _appUserAndSessionTranslateInfoServerQueue = dispatch_queue_create("com.CIMSDKCode.appUserAndSessionTranslateInfoServerQueue", DISPATCH_QUEUE_CONCURRENT);
    }
    return _appUserAndSessionTranslateInfoServerQueue;
}

- (NSMutableArray *)allSessionList {
    if (_allSessionList == nil) {
        _allSessionList = [[NSMutableArray alloc] init];
    }
    return _allSessionList;
}

@end
