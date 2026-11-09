#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#define UIApplicationStateActive 0
#define LingIMSocketConnectStateDisconnected 0
@interface UIApplication : NSObject
@property NSInteger applicationState;
+ (instancetype)sharedApplication;
@end
@implementation UIApplication
+ (instancetype)sharedApplication { static id x; if(!x) x=[self new]; return x; }
@end
@interface GCDAsyncSocket : NSObject
@property NSInteger disconnects;
- (void)disconnect;
@end
@implementation GCDAsyncSocket
- (void)disconnect { self.disconnects++; }
@end
@interface NoaIMSDKManager : NSObject
@property NSString *user;
@property NSString *license;
+ (instancetype)sharedTool;
- (NSString *)myUserID;
- (NSString *)currentLiceseId;
@end
@implementation NoaIMSDKManager
+ (instancetype)sharedTool { static id x; if(!x) x=[self new]; return x; }
- (NSString *)myUserID { return self.user; }
- (NSString *)currentLiceseId { return self.license; }
@end
@interface Auth : NSObject
@property BOOL isAuth;
+ (instancetype)shared;
@end
@implementation Auth
+ (instancetype)shared { static id x; if(!x) x=[self new]; return x; }
@end
#define SOCKETMANAGERTOOL [Auth shared]
@interface NoaIMSocketManager : NSObject {
@public GCDAsyncSocket *_gcdSocket;
}
@property dispatch_queue_t internalQueue;
@property BOOL isCanReconnect;
@property BOOL isTcpRacing;
@property BOOL reconnectScheduled;
@property NSString *socketUserID;
@property NSInteger reconnects;
- (void)stopSocketHeartbeat;
- (void)stopSocketReconnectWithReason:(NSString *)reason;
- (void)cancelAuthPhase;
- (void)stopKeyExchangeTimer;
- (void)updateConnectState:(NSInteger)state;
- (void)startingSocketReconnect;
@end
@implementation NoaIMSocketManager
- (void)stopSocketHeartbeat {}
- (void)stopSocketReconnectWithReason:(NSString *)reason {}
- (void)cancelAuthPhase {}
- (void)stopKeyExchangeTimer {}
- (void)updateConnectState:(NSInteger)state {}
- (void)startingSocketReconnect { self.reconnects++; }
#include "Probe.inc"
@end
int main() { @autoreleasepool {
    NoaIMSDKManager *sdk=[NoaIMSDKManager sharedTool]; sdk.user=@"user"; sdk.license=@"club";
    Auth.shared.isAuth=YES;
    NoaIMSocketManager *manager=[NoaIMSocketManager new];
    manager.internalQueue=dispatch_queue_create("test.probe", DISPATCH_QUEUE_SERIAL);
    manager.socketUserID=@"user"; manager.isCanReconnect=YES;
    GCDAsyncSocket *old=[GCDAsyncSocket new], *current=[GCDAsyncSocket new]; manager->_gcdSocket=current;
    [manager reconnectIfCurrentSocket:old userID:@"user" liceseId:@"club"];
    NSCAssert(current.disconnects==0 && manager.reconnects==0,@"old socket ignored");
    [manager reconnectIfCurrentSocket:current userID:@"other" liceseId:@"club"];
    [manager reconnectIfCurrentSocket:current userID:@"user" liceseId:@"other"];
    NSCAssert(current.disconnects==0,@"wrong identity ignored");
    UIApplication.sharedApplication.applicationState=1;
    [manager reconnectIfCurrentSocket:current userID:@"user" liceseId:@"club"];
    NSCAssert(current.disconnects==0,@"background ignored");
    UIApplication.sharedApplication.applicationState=0;
    manager.isTcpRacing=YES;
    [manager reconnectIfCurrentSocket:current userID:@"user" liceseId:@"club"];
    NSCAssert(current.disconnects==0,@"SDK race not interrupted");
    manager.isTcpRacing=NO;
    [manager reconnectIfCurrentSocket:current userID:@"user" liceseId:@"club"];
    NSCAssert(current.disconnects==1 && manager.reconnects==1,@"current connection reconnects exactly once");
    puts("Socket probe production method checks passed (6)");
} }
