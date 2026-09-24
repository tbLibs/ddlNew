//
//  NoaIMSDKManager+Connect.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/5.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (Connect)

/// SDK连接状态
- (BOOL)connectState;

/// 退出账号
- (void)toolLogoutAccount;

/// 主动断开socket连接(会自动重连，主要用于账号退出后，主动断开socket连接，避免收到上一个账号的消息)
- (void)toolDisconnectCanReconnect;

/// 主动断开socket连接(不会自动重连，主要用于在邀请码加入页面，主动断开socket连接，并且直到竞速后，重新连接)
- (void)toolDisconnectNoReconnect;

@end

NS_ASSUME_NONNULL_END
