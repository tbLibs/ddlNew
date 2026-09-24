//
//  NoaIMSDKManager+SyncServer.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

// 同步服务端数据

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (SyncServer)

@property (nonatomic, strong) dispatch_queue_t dbQueue;

/// 服务端同步联系人(先同步好友分组信息，然后才同步联系人)
- (void)syncContactsFromServer;

/// 服务端同步群组
- (void)syncGroupsFromServer;

/// 服务端同步会话
- (void)syncSessionsFromServer;
//socket重连成功后，重新同步会话列表
- (void)reconnectSyncSessionsFromServer;

/// 用户翻译配置信息和每个会话的翻译培训信息
- (void)syncAppUserAndSessionTranslateInfoServer;

/// 服务端同步消息提醒方式
- (void)syncMessageRemindFromServer;

/// 同步敏感词
- (void)syncAppSensitiveFromServer;

//同步类型消息-同步会话状态(置顶、取消置顶、免打扰)
- (void)syncUserSessionStatus:(IMServerMessage *)message;

@end

NS_ASSUME_NONNULL_END
