//
//  NoaIMSDKManager.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/10/21.
//

// 基于GCDSocket封装的单例

#define IMSDKManager [NoaIMSDKManager sharedTool]


#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>
#import <pthread.h>
//SDK
#import "NoaIMSDK.h"//sdk头文件

#import "OIMGCDMulticastDelegate.h"//一对多代理
#import "NoaIMSDKDelegate.h"//代理
#import "LingIMModelTool.h"//model工具

#import "NoaIMDBHeader.h"//数据库

#import "NoaIMSDKApiOptions.h"//服务器相关配置参数
#import "NoaIMSDKHostOptions.h"//IM主机相关配置参数
#import "NoaIMSDKUserOptions.h"//用户信息相关配置参数

#define LAST_SYNC_SESSION_TIME_KEY  @"LAST_SYNC_SESSION_TIME_KEY_VERSION_0"//会话列表
#define LAST_SYNC_SECTION_TIME_KEY  @"LAST_SYNC_SECTION_TIME_KEY_VERSION_0"//通讯录分组
#define LAST_SYNC_FRIEND_TIME_KEY   @"LAST_SYNC_FRIEND_TIME_KEY_VERSION_0"//通讯录好友
#define LAST_SYNC_GROUP_TIME_KEY    @"LAST_SYNC_GROUP_TIME_KEY_VERSION_0"//群组列表
#define LAST_SYNC_MEMBER_TIME_KEY   @"LAST_SYNC_MEMBER_TIME_KEY_VERSION_0"//群成员列表


static inline void dispatch_async_on_main_queue(void (^ _Nullable block)(void)) {
    if (pthread_main_np()) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

//接口请求成功带有服务器时间的回调
typedef void (^LingIMSuccessWithTimeCallback)(id _Nullable data, long long serviceTime);

//接口请求成功回调
typedef void (^LingIMSuccessCallback)(id _Nullable data, NSString * _Nullable traceId);

//接口请求失败回调
typedef void (^LingIMFailureCallback)(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId);

//聊天历史记录回调
typedef void (^LingIMChatMessageHistoryBlock) (NSArray <NoaIMChatMessageModel *> * _Nullable chatMessageHistory, NSInteger offset, BOOL isLocal, NSInteger pageNumber);

//重连历史记录回调
typedef void (^LingIMReConnectMessageHistoryBlock) (NSArray <NoaIMChatMessageModel *> * _Nullable chatMessageHistory, NSInteger offset);

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager : NSObject

#pragma mark - 单例
+ (instancetype)sharedTool;
//单例一般不需要清空，但是在执行某些功能的时候，防止数据更换不及时，可以清空一下
- (void)clearTool;

#pragma mark - ******业务******
/******* 注意初始化的时候按照123的顺序进行配置 ******/
/******* 初始化完成后可根据需求单独调用某个配置方法 ******/

/// 1.SDK api 相关信息 配置/更新
/// - Parameter apiOptions: api信息
- (void)configSDKApiWith:(NoaIMSDKApiOptions *)apiOptions;

/// 3.SDK user 相关信息 配置/更新
/// @param userOptions 用户信息
- (void)configSDKUserWith:(NoaIMSDKUserOptions *)userOptions;
/// 配置当前请求使用的设备凭证。
/// @param deviceSecret App 层根据登录账号或用户 UID 查询到的设备凭证；传 nil 或空值表示清除
- (void)configSDKDeviceSecret:(nullable NSString *)deviceSecret;
///SDK SSO 相关信息 配置/更新
/// @param ssoInfoStr 邀请码 或者 IP/域名+端口
- (void)configSDKSsoInfo:(NSString *)ssoInfoStr;

/// @param liceseId 邀请码
- (void)configSDKLiceseId:(NSString *)liceseId;

/// @param tenantCode 接口验签
- (void)configSDKTenantCode:(NSString *)tenantCode;

/// @param captchaChannel 验证方式
- (void)configSDKCaptchaChannel:(NSInteger)captchaChannel;

/// SDK重连机制
- (void)reconnectedSDK;

//设置请求的域名
- (void)configApiHost:(NSString *)apiHost;

/// 获取我的信息
- (NSString *)myUserID;
/// 获取我的token
- (NSString *)myUserToken;
/// 获取当前请求使用的设备凭证；未配置时返回空字符串
- (NSString *)myDeviceSecret;
/// 获取我的昵称
- (NSString *)myUserNickname;
//更新昵称
- (void)configNewUserNickName:(NSString *)nickName;
/// 获取我的头像
- (NSString *)myUserAvatar;
//更新头像
- (void)configNewUserAvatar:(NSString *)avatar;
/// 获取我的ssoInfo
- (NSString *)mySsoInfo;
/// 获取当前liceseId
- (NSString *)currentLiceseId;
/// 获取captchaChannel
- (NSInteger)captchaChannel;
/// 获取tenantCode
- (NSString *)tenantCode;
/// 清除用户信息及当前请求使用的设备凭证
- (void)clearMyUserInfo;

- (long long)lastSyncSessionTime;
/// 上次同步通讯录分组数据时间戳
- (long long)lastSyncSectionTime;
/// 上次同步通讯录好友数据时间戳
- (long long)lastSyncFriendTime;
/// 上次同步群组列表时间戳
- (long long)lastSyncGroupTime;

/// 获取当前邀请码或者IP/域名+端口号下，储存 敏感词 的表名
- (NSString *)getTableNameForSensitive;

/// 多租户获取
- (NSString *)orgName;
/// 网络地址
- (NSString *)apiHost;

/// SDK版本号
- (NSString *)sdkVersion;

/// 添加连接代理
- (void)addConnectDelegate:(id <NoaToolConnectDelegate> )delegate;
/// 移除连接代理
- (void)removeConnectDelegate:(id <NoaToolConnectDelegate> )delegate;

/// 添加消息代理
- (void)addMessageDelegate:(id <NoaToolMessageDelegate> )delegate;
/// 移除消息代理
- (void)removeMessageDelegate:(id <NoaToolMessageDelegate> )delegate;

/// 添加用户代理
- (void)addUserDelegate:(id <NoaToolUserDelegate> )delegate;
/// 移除用户代理
- (void)removeUserDelegate:(id <NoaToolUserDelegate> )delegate;

/// 添加会话代理
- (void)addSessionDelegate:(id <NoaToolSessionDelegate> )delegate;
/// 移除会话代理
- (void)removeSessionDelegate:(id <NoaToolSessionDelegate> )delegate;

/// 添加群聊代理
- (void)addGroupDelegate:(id <CIMToolGroupDelegate> )delegate;
/// 移除群聊代理
- (void)removeGroupDelegate:(id <CIMToolGroupDelegate> )delegate;

/// 添加多媒体会话代理(音视频通话)
- (void)addMediaCallDelegate:(id <NoaIMMediaCallDelegate> )delegate;
/// 移除多媒体会话代理(音视频通话)
- (void)removeMediaCallDelegate:(id <NoaIMMediaCallDelegate> )delegate;

//注意此处的代理仅作为响应回调使用，服从代理需要调用 业务addFriendDelegate等方法
/// 连接代理
@property (nonatomic, strong) OIMGCDMulticastDelegate <NoaToolConnectDelegate> *connectDelegate;
/// 消息代理
@property (nonatomic, strong) OIMGCDMulticastDelegate <NoaToolMessageDelegate> *messageDelegate;
/// 用户代理
@property (nonatomic, strong) OIMGCDMulticastDelegate <NoaToolUserDelegate> *userDelegate;
/// 会话代理
@property (nonatomic, strong) OIMGCDMulticastDelegate <NoaToolSessionDelegate> *sessionDelegate;
/// 群聊代理
@property (nonatomic, strong) OIMGCDMulticastDelegate <CIMToolGroupDelegate> *groupDelegate;
/// 多媒体代理(音视频通话)
@property (nonatomic, strong) OIMGCDMulticastDelegate <NoaIMMediaCallDelegate> *mediaCallDelegate;
@property (nonatomic, strong) dispatch_queue_t sessionListUpdateQueue;
@property (nonatomic, strong) dispatch_queue_t friendGroupListUpdateQueue;
@property (nonatomic, strong) dispatch_queue_t contactsListUpdateQueue;
@property (nonatomic, strong) dispatch_queue_t friendListQueue;
@property (nonatomic, strong) dispatch_queue_t friendOnlineQueue;

@property (nonatomic, strong) dispatch_queue_t groupListQueue;
@property (nonatomic, strong) dispatch_queue_t imSdkUpdateAppSensitiveQueue;

@property (nonatomic, strong) dispatch_queue_t unreadCountQueue;
@property (nonatomic, strong) dispatch_queue_t appUserAndSessionTranslateInfoServerQueue;

@property (nonatomic, strong) NSMutableArray *allSessionList;
@property (nonatomic, strong) NSDictionary * _Nullable clearReadNumSMsgIdDict;

@end

NS_ASSUME_NONNULL_END
