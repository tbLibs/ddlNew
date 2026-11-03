#import <Foundation/Foundation.h>
#import <Security/Security.h>
#define NoaLocalLogger Fixture
#define GCDAsyncSocket Fixture
#define NovDecryptorManager Fixture

static const NSTimeInterval kKeyExchangeTimeout = 0.001;
typedef void (^KeyCompletion)(SecKeyRef, SecKeyRef);
@interface Fixture : NSObject
@property BOOL isConnected, isKeyExchangeInProgress, isCanReconnect, isCanConnectNet;
@property NSUInteger connectionSequence, writes, disconnects;
@property (strong) Fixture *gcdSocket, *novDecryptorManager;
@property (weak) id delegate;
@property (strong) dispatch_source_t keyExchangeTimer;
@property (copy) NSString *reconnectFailureReason, *socketHost;
@property NSInteger socketPort;
@property (atomic, copy) KeyCompletion callback;
@end
@implementation Fixture
+ (void)info:(NSString *)s {}
+ (void)error:(NSString *)s {}
- (void)recordInitializationSentryStage:(NSString *)s result:(id)r reason:(id)e {}
- (void)sentryUploadWithEventObj:(NSDictionary *)e errorCode:(NSString *)c {}
- (void)generateKeyPairWithComplete:(KeyCompletion)completion { self.callback = completion; }
- (NSData *)secKeyRefToData:(SecKeyRef)key { return [NSData dataWithBytes:"x" length:1]; }
- (NSData *)buildServerPublicKeyRequestMessage:(NSData *)key { return key; }
- (void)writeData:(NSData *)data withTimeout:(double)timeout tag:(long)tag { self.writes++; }
- (void)disconnect { self.disconnects++; self.isConnected = NO; }
- (void)disconnectSocket { self.disconnects++; [self.gcdSocket disconnect]; }
- (void)disconnectAfterReadingAndWriting { [self disconnect]; }
- (void)clearKeyExchangeInfo {}
- (void)cleanupReceiveBuffers {}
#include "Callbacks.inc"
@end

int main(void) { @autoreleasepool {
    for (int scenario = 0; scenario < 7; scenario++) {
        Fixture *manager = [Fixture new], *socket = [Fixture new], *keys = [Fixture new];
        manager.gcdSocket = socket;
        manager.novDecryptorManager = keys;
        manager.isCanReconnect = manager.isCanConnectNet = manager.isKeyExchangeInProgress = socket.isConnected = YES;
        if (scenario >= 5) {
            [manager startKeyExchangeTimer];
            if (scenario == 5) {
                socket.isConnected = manager.isKeyExchangeInProgress = NO;
            }
            NSDate *end = [NSDate dateWithTimeIntervalSinceNow:0.1];
            [[NSRunLoop mainRunLoop] runUntilDate:end];
            [manager stopKeyExchangeTimer];
            if (manager.disconnects || socket.disconnects != (scenario == 6)) {
                fprintf(stderr, "FAIL timeout scenario %d\n", scenario);
                return 1;
            }
            continue;
        }
        [manager startKeyExchangeProcess];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
        while (!keys.callback && deadline.timeIntervalSinceNow > 0) [NSThread sleepForTimeInterval:0.001];
        if (!keys.callback) return 2;
        if (scenario == 0) { // Disconnect delegate already scheduled the next attempt.
            socket.isConnected = manager.isKeyExchangeInProgress = NO;
        } else if (scenario == 1 || scenario == 2) { // Next connection already started.
            [manager forceDisconnectSocket];
            if (manager.gcdSocket == socket || manager.novDecryptorManager == keys) return 1;
            manager.gcdSocket = [Fixture new];
            manager.gcdSocket.isConnected = YES;
            manager.connectionSequence++;
        }
        SecKeyRef fakeKey = (scenario == 1 || scenario == 4) ? NULL : (__bridge SecKeyRef)keys;
        keys.callback(fakeKey, fakeKey);
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        if (manager.disconnects || manager.gcdSocket.disconnects != (scenario == 4) ||
            manager.gcdSocket.writes != (scenario == 3)) {
            fprintf(stderr, "FAIL scenario %d: manager disconnects=%lu socket disconnects=%lu writes=%lu\n",
                scenario, manager.disconnects, manager.gcdSocket.disconnects, manager.gcdSocket.writes);
            return 1;
        }
    }
    puts("PASS 7 ECDH callback scenarios");
} }
