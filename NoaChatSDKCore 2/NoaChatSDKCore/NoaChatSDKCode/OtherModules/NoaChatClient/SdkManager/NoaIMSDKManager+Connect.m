//
//  NoaIMSDKManager+Connect.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/11/5.
//

#import "NoaIMSDKManager+Connect.h"
#import "NoaIMSDKManager+MiniApp.h"

@implementation NoaIMSDKManager (Connect)

#pragma mark - SDK连接状态
- (BOOL)connectState {
    return cim_function_connected();
}

#pragma mark - SDK断开连接
- (void)toolLogoutAccount {
    
    //断开socket连接
//    cim_function_disconnected();
//
//    //移除代理
//    [self.connectDelegate removeAllDelegates];
//    [self.messageDelegate removeAllDelegates];
//    [self.userDelegate removeAllDelegates];
//    [self.sessionDelegate removeAllDelegates];
//    [self.groupDelegate removeAllDelegates];
//    [self.mediaCallDelegate removeAllDelegates];
    
    // 清理socket用户信息
    cim_function_clearUserInfo();
    
    // 标记为非重新连接
    cim_function_resetReconnectStatus();
    
    //清除小程序浮窗
    [self imSdkDeleteAllFloatMiniApp];
    
    //关闭数据库
    [DBTOOL closeDB];
    
    //清除用户信息
    [self clearMyUserInfo];
    
}

- (void)toolDisconnectCanReconnect {
    //断开socket连接
    cim_function_disconnected();
}

- (void)toolDisconnectNoReconnect {
    //断开socket连接
    cim_function_disconnectWithOutReconnect();
}


@end
