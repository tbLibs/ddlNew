#!/usr/bin/env python3
"""Run production failure classifiers/ACK checks with Foundation mocks, without network."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
sdk = root / 'NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode'
protocol = (sdk / 'ConnectModule/Common/LingIMProtocol.h').read_text()
tool = (sdk / 'ConnectModule/Socket/TcpManager/NoaIMSocketManagerTool.m').read_text()
http = (sdk / 'ConnectModule/HttpRequest/NoaIMHttpManager.m').read_text()

def method(source, signature):
    start = source.index(signature)
    pos = source.index('{', start) + 1
    depth = 1
    while depth:
        depth += (source[pos] == '{') - (source[pos] == '}')
        pos += 1
    return source[start:pos]
start = protocol.index('typedef NS_ENUM(NSInteger, CIMMessageSendFailureReason)')
enum = protocol[start:protocol.index('};', start)+2]
code = '#import <Foundation/Foundation.h>\n#import <dispatch/dispatch.h>\n' + enum
code += '\n#import "' + str(sdk / 'ConnectModule/HttpToTcpRequest/NoaIMRequestSessionFence.h') + '"\n'
code += '\nextern void InvalidateSessionFromRequestModule(NSObject *owner);\n'
# Execute the production push HTTP rejection branch before handing its result to
# the real socket callback. Dropping a 4xx/5xx response message must fail here.
push_request = method(http, '- (void)netRequestMessagePushWithPath:(NSString *)path httpHost:')
http_rejection = method(push_request, 'if (httpStatus >= 400 && httpStatus < 600)')
code += '''
static NSString *AFNetworkingOperationFailingURLResponseDataErrorKey = @"responseData";
static void receiveHTTPRejection(NSInteger httpStatus, id responseObject, NSError *error,
                                void (^onFailure)(NSInteger, NSString *, NSString *)) {
    NSString *ztid = @"fixture-trace";
''' + http_rejection + '\n}\n'
code += r'''
#define CHECK(x) NSCAssert((x), @#x)
static void *NoaMessageSendQueueKey=&NoaMessageSendQueueKey;
@interface NetWorkStatusManager:NSObject
@property BOOL getConnectStatus;
+ (instancetype)shared;
@end
@implementation NetWorkStatusManager
+ (instancetype)shared {static NetWorkStatusManager *m; if(!m)m=[NetWorkStatusManager new];return m;}
@end
@interface IMChatMessageACK:NSObject
@property(copy) NSString *ackMsgId, *sMsgId;
@end
@implementation IMChatMessageACK
@end
@interface IMChatMessage:NSObject
@property NSInteger mType;
@property(copy) NSString *from, *msgId;
@end
@implementation IMChatMessage
@end
@interface IMMessage:NSObject
@property(strong) IMChatMessage *chatMessage;
@property(strong) IMChatMessageACK *chatMessageAck;
@property NSInteger dataType;
- (NSData *)data;
+ (instancetype)mj_objectWithKeyValues:(NSDictionary *)data;
@end
@implementation IMMessage
- (NSData *)data {return [self.chatMessage.msgId dataUsingEncoding:NSUTF8StringEncoding];}
+ (instancetype)mj_objectWithKeyValues:(NSDictionary *)data {
    IMMessage *message = [self new]; message.chatMessageAck = data[@"ack"]; return message;
}
@end
@interface Delegate:NSObject
@property NSInteger failures, successes;
@property CIMMessageSendFailureReason lastReason;
- (void)noaMessageSendFail:(NSString *)msg reason:(CIMMessageSendFailureReason)reason;
- (void)noaMessageSendFail:(NSString *)msg;
@end
@implementation Delegate
- (void)noaMessageSendSuccess:(IMChatMessageACK *)ack {self.successes++;}
- (void)noaMessageSendFail:(NSString *)msg reason:(CIMMessageSendFailureReason)reason {self.failures++; self.lastReason=reason;}
- (void)noaMessageSendFail:(NSString *)msg {self.failures++;}
@end
@interface Harness:NSObject
@property(strong) NSMutableDictionary *sendMessageDic;
@property(strong) dispatch_queue_t sendMessageQueue;
@property(strong) Delegate *messageDelegate;
@property BOOL currentSocketConnectStatus, isAuth;
@property NSInteger sends, pushes;
@property(copy) NSString *myUserID;
@property(copy) NSString *apiHost;
@property(copy) NSArray<NSString *> *messagePushHTTPHosts;
@property(copy) NSString *lastHTTPHost;
@property(copy) void (^success)(id, NSString *);
@property(copy) void (^failure)(NSInteger, NSString *, NSString *);
@property(copy) NSData *payload;
- (void)notifyMessageSendFail:(NSString *)messageID reason:(CIMMessageSendFailureReason)reason;
- (CIMMessageSendFailureReason)pushFailureReasonForCode:(NSInteger)code networkAvailable:(BOOL)available;
- (BOOL)isValidMessageACK:(IMChatMessageACK *)ack forMessageID:(NSString *)msg;
- (void)checkMessageSendAckStatus:(NSString *)messageId;
- (void)sendSocketMessage:(id)message tag:(NSInteger)tag;
- (void)submitPendingMessageWithID:(NSString *)msgID pending:(NSMutableDictionary *)dic;
@end
#define IMSDKManager self
#define IMSDKHTTPTOOL self
#define Message_Push_Msg_Url @"/biz/message/pushMsg"
typedef void (^LingIMSuccessCallback)(id, NSString *);
typedef void (^LingIMFailureCallback)(NSInteger, NSString *, NSString *);
#define IMMessage_DataType_ImchatMessage 1
#define IMChatMessage_MessageType_HaveReadMessage 2
#define LingIMMessageTimeout 3
#define SOCKETMANAGER self
#define LingIMMessageTag 1
@implementation Harness
- (instancetype)init {if((self=[super init])){self.sendMessageDic=[NSMutableDictionary dictionary];self.messageDelegate=[Delegate new];self.sendMessageQueue=dispatch_queue_create("test.message",DISPATCH_QUEUE_SERIAL);dispatch_queue_set_specific(self.sendMessageQueue,NoaMessageSendQueueKey,(__bridge void *)self,NULL);}return self;}
- (void)sendSocketMessage:(id)message tag:(NSInteger)tag {self.sends++;}
- (void)MessagePushMsg:(NSData *)data onSuccess:(void(^)(id, NSString *))success
             onFailure:(void(^)(NSInteger, NSString *, NSString *))failure {
    self.pushes++; self.payload=data; self.success=success; self.failure=failure;
}
- (void)messageSendFailLoganWith:(NSString *)why messageId:(NSString *)msgID {}
- (void)sendPingMessageForChatMessageSendFail {}
- (void)netRequestMessagePushWithPath:(NSString *)path httpHost:(NSString *)host paramData:(NSData *)data
                          onSuccess:(LingIMSuccessCallback)success onFailure:(LingIMFailureCallback)failure {
    CHECK([path isEqual:@"/biz/message/pushMsg"]);
    self.lastHTTPHost=host;
    [self MessagePushMsg:data onSuccess:success onFailure:failure];
}
'''
for source, signature in [(tool,'- (void)trackChatMessage:'),(tool,'- (void)pushPendingMessageWithID:'),(tool,'- (void)receiveMessageDealForChatMessageAckWith:'),(tool,'- (void)notifyMessageSendFail:'),(tool,'- (CIMMessageSendFailureReason)pushFailureReasonForCode:'),(tool,'- (BOOL)isValidMessageACK:'),(tool,'-(void)checkMessageSendAckStatus:')]:
    code += '\n' + method(source,signature)
if '- (void)submitPendingMessageWithID:' in tool:
    code += '\n' + method(tool, '- (void)submitPendingMessageWithID:')
code += r'''
@end
int main(){@autoreleasepool {
 Harness *h=[Harness new];
 CHECK(CIMMessageSendFailureReasonUnknown==0 && CIMMessageSendFailureReasonTranslation==7);
 NSArray *pairs=@[@[@429,@(CIMMessageSendFailureReasonRateLimited)],@[@413,@(CIMMessageSendFailureReasonFileTooLarge)],@[@403,@(CIMMessageSendFailureReasonServerRejected)],@[@40015,@(CIMMessageSendFailureReasonServerRejected)],@[@0,@(CIMMessageSendFailureReasonInvalidResponse)],@[@10005,@(CIMMessageSendFailureReasonConnectionNotReady)],@[@(-1005),@(CIMMessageSendFailureReasonConnectionLost)],@[@(-1001),@(CIMMessageSendFailureReasonTimeout)],@[@503,@(CIMMessageSendFailureReasonTimeout)]];
 for(NSArray *pair in pairs){CHECK([h pushFailureReasonForCode:[pair[0] integerValue] networkAvailable:YES]==[pair[1] integerValue]);CHECK([h pushFailureReasonForCode:[pair[0] integerValue] networkAvailable:NO]==CIMMessageSendFailureReasonNetworkUnavailable);}
 CHECK([h pushFailureReasonForCode:NSURLErrorSecureConnectionFailed networkAvailable:YES] != CIMMessageSendFailureReasonTimeout);
 IMChatMessageACK *ack=[IMChatMessageACK new];
 CHECK(![h isValidMessageACK:nil forMessageID:@"m"]);
 ack.ackMsgId=@"m"; CHECK(![h isValidMessageACK:ack forMessageID:@"m"]);
 ack.sMsgId=@"server"; CHECK([h isValidMessageACK:ack forMessageID:@"m"]);
 CHECK(![h isValidMessageACK:ack forMessageID:@"other"]);
 [NetWorkStatusManager shared].getConnectStatus=NO;
 for(NSNumber *reason in @[@(CIMMessageSendFailureReasonConnectionNotReady),@(CIMMessageSendFailureReasonInvalidResponse),@(CIMMessageSendFailureReasonUpload)]) {
   h.sendMessageDic[@"m"]=[@{@"message":[IMMessage new]} mutableCopy];
   [h notifyMessageSendFail:@"m" reason:reason.integerValue];dispatch_sync(h.sendMessageQueue,^{});
   CHECK(h.messageDelegate.lastReason==CIMMessageSendFailureReasonNetworkUnavailable && h.sendMessageDic.count==0);
 }
 [NetWorkStatusManager shared].getConnectStatus=YES; h.currentSocketConnectStatus=NO;
 IMMessage *message=[IMMessage new]; message.chatMessage=[IMChatMessage new];
 message.dataType=IMMessage_DataType_ImchatMessage;
 h.myUserID=@"sender";
 message.chatMessage.msgId=@"m"; message.chatMessage.from=@"sender";
 h.sendMessageDic[@"m"]=[@{@"message":message, @"session":NoaIMRequestSession(h)} mutableCopy];
 dispatch_sync(h.sendMessageQueue,^{
    [h pushPendingMessageWithID:@"m"];
    [h pushPendingMessageWithID:@"m"];
 });
 CHECK(h.pushes==1 && h.sendMessageDic.count==1 && h.sends==0 && [h.payload isEqual:message.data]);
 __block NSMutableArray *notices=[NSMutableArray new];
 id observer=[[NSNotificationCenter defaultCenter] addObserverForName:@"IMMessagePushRejected" object:nil queue:nil
    usingBlock:^(NSNotification *note){[notices addObject:note.userInfo];}];
 h.failure(96305,@"禁止发送",nil); dispatch_sync(h.sendMessageQueue,^{});
 CHECK((notices.count==1 && [notices[0] isEqual:@{@"message":@"禁止发送",@"userID":@"sender"}]));
 CHECK(h.messageDelegate.lastReason==CIMMessageSendFailureReasonServerRejected && h.sendMessageDic.count==0);

 // A TCP ACK with no server ID must enter push exactly once.
 h.sendMessageDic[@"m"]=[@{@"message":message, @"session":NoaIMRequestSession(h)} mutableCopy];
 IMMessage *tcpAck=[IMMessage new]; tcpAck.chatMessageAck=[IMChatMessageACK new];
 tcpAck.chatMessageAck.ackMsgId=@"m";
 [h receiveMessageDealForChatMessageAckWith:tcpAck];
 [h receiveMessageDealForChatMessageAckWith:tcpAck];
 dispatch_sync(h.sendMessageQueue,^{});
 CHECK(h.pushes==2);
 // A real ACK wins over late HTTP failure.
 tcpAck.chatMessageAck=ack;
 [h receiveMessageDealForChatMessageAckWith:tcpAck];
 dispatch_sync(h.sendMessageQueue,^{});
 h.failure(96305,@"late",nil); dispatch_sync(h.sendMessageQueue,^{});
 CHECK(h.messageDelegate.successes==1 && notices.count==1);
 // Same UID login gets a different session and discards previous HTTP callbacks.
 h.sendMessageDic[@"m"]=[@{@"message":message, @"session":NoaIMRequestSession(h)} mutableCopy];
 dispatch_sync(h.sendMessageQueue,^{ [h pushPendingMessageWithID:@"m"]; });
 InvalidateSessionFromRequestModule(h);
 h.failure(96305,@"old session",nil); dispatch_sync(h.sendMessageQueue,^{});
 CHECK(notices.count==1);
 // Failed TCP submission starts a push directly, without ACK.
 Harness *fresh=[Harness new]; fresh.myUserID=@"sender"; fresh.isAuth=YES; fresh.currentSocketConnectStatus=YES;
 [fresh trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(fresh.sendMessageQueue,^{});
 CHECK(fresh.pushes==1);
 [fresh trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(fresh.sendMessageQueue,^{});
 CHECK(fresh.pushes==1);
 // Four unanswered submissions reach the same push entry.
 Harness *unanswered=[Harness new]; unanswered.myUserID=@"sender"; unanswered.isAuth=YES; unanswered.currentSocketConnectStatus=YES;
 for (int i=0;i<4;i++) { [unanswered trackChatMessage:message tcpSendFailed:NO]; dispatch_sync(unanswered.sendMessageQueue,^{}); }
 CHECK(unanswered.pushes==1);
 // Disconnected pending message also falls back.
 Harness *disconnected=[Harness new]; disconnected.myUserID=@"sender";
 disconnected.sendMessageDic[@"m"]=[@{@"message":message, @"session":NoaIMRequestSession(disconnected)} mutableCopy];
 dispatch_sync(disconnected.sendMessageQueue,^{[disconnected checkMessageSendAckStatus:@"m"];});
 CHECK(disconnected.pushes==1);
 // xgd preserves rejection text on non-2xx responses as well as HTTP-200 business failures.
 NSArray *httpCases=@[
    @{@"status":@403, @"body":@{@"code":@96305, @"message":@"当前为宵禁时段，禁止发送消息"}, @"data":NSData.data, @"want":@"当前为宵禁时段，禁止发送消息"},
    @{@"status":@503, @"body":NSNull.null, @"data":[@"{\"code\":96305,\"message\":\"宵禁拒绝原文\"}" dataUsingEncoding:NSUTF8StringEncoding], @"want":@"宵禁拒绝原文"},
    @{@"status":@403, @"body":@{@"message":NSNull.null}, @"data":NSData.data, @"want":@""},
    @{@"status":@403, @"body":NSNull.null, @"data":[@"<html>Forbidden</html>" dataUsingEncoding:NSUTF8StringEncoding], @"want":@""},
    @{@"status":@500, @"body":NSNull.null, @"data":[@"[1,2]" dataUsingEncoding:NSUTF8StringEncoding], @"want":@""}
 ];
 for (NSDictionary *entry in httpCases) {
    Harness *failed=[Harness new]; failed.myUserID=@"sender";
    [failed trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(failed.sendMessageQueue,^{});
    NSUInteger before=notices.count;
    NSError *error=[NSError errorWithDomain:@"AFURLResponseSerializationErrorDomain" code:-1011
        userInfo:@{AFNetworkingOperationFailingURLResponseDataErrorKey:entry[@"data"]}];
    __block NSInteger failureCode=0, calls=0;
    receiveHTTPRejection([entry[@"status"] integerValue], entry[@"body"], error,
        ^(NSInteger code, NSString *text, NSString *trace) { calls++; failureCode=code; failed.failure(code,text,trace); });
    dispatch_sync(failed.sendMessageQueue,^{});
    CHECK(calls==1 && failureCode==[entry[@"status"] integerValue]);
    CHECK(failed.messageDelegate.failures==1 && failed.sendMessageDic.count==0);
    NSString *wanted=entry[@"want"];
    if (wanted.length) {
        CHECK(notices.count==before+1);
        CHECK([notices.lastObject[@"message"] isEqual:wanted]);
        CHECK([notices.lastObject[@"userID"] isEqual:@"sender"]);
    } else { CHECK(notices.count==before); }
 }
 // A transport failure has no server rejection message and must not invent curfew.
 NSUInteger beforeTransportFailure=notices.count;
 fresh.failure(NSURLErrorSecureConnectionFailed,@"TLS failure",nil); dispatch_sync(fresh.sendMessageQueue,^{});
 CHECK(fresh.messageDelegate.lastReason==CIMMessageSendFailureReasonSecureConnection);
 CHECK(notices.count==beforeTransportFailure);
 // A failed TLS handshake must try another DNS1 HTTP candidate before reporting a terminal failure.
 Harness *tls=[Harness new]; tls.myUserID=@"sender"; tls.apiHost=@"https://unavailable.example:2027";
 tls.messagePushHTTPHosts=@[tls.apiHost,@"https://working.example:2027",@"https://working.example:2027"];
 [tls trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(tls.sendMessageQueue,^{});
 void (^firstFailure)(NSInteger,NSString *,NSString *)=tls.failure;
 firstFailure(NSURLErrorSecureConnectionFailed,@"TLS failure",nil); dispatch_sync(tls.sendMessageQueue,^{});
 CHECK(tls.pushes==2 && tls.messageDelegate.failures==0 && tls.sendMessageDic.count==1);
 CHECK([tls.lastHTTPHost isEqual:@"https://working.example:2027"] && [tls.payload isEqual:message.data]);
 firstFailure(NSURLErrorSecureConnectionFailed,@"duplicate",nil); dispatch_sync(tls.sendMessageQueue,^{});
 CHECK(tls.pushes==2 && tls.messageDelegate.failures==0);
 NSUInteger beforeCurfew=notices.count;
 tls.failure(96305,@"当前宵禁，禁止发送",nil); dispatch_sync(tls.sendMessageQueue,^{});
 CHECK(tls.pushes==2 && tls.messageDelegate.failures==1 && tls.messageDelegate.lastReason==CIMMessageSendFailureReasonServerRejected);
 CHECK(notices.count==beforeCurfew+1 && [notices.lastObject[@"message"] isEqual:@"当前宵禁，禁止发送"]);
 // Duplicate candidates, an unsafe downgrade and another account's new configuration cannot expand this round.
 Harness *exhausted=[Harness new]; exhausted.myUserID=@"sender"; exhausted.apiHost=@"https://one.example";
 exhausted.messagePushHTTPHosts=@[exhausted.apiHost,@"http://downgrade.example",@"https://two.example",@"https://two.example"];
 [exhausted trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(exhausted.sendMessageQueue,^{});
 exhausted.messagePushHTTPHosts=@[@"https://new-session.example"];
 for (int i=0;i<2;i++) { exhausted.failure(NSURLErrorSecureConnectionFailed,@"tls",nil); dispatch_sync(exhausted.sendMessageQueue,^{}); }
 CHECK(exhausted.pushes==2 && exhausted.messageDelegate.failures==1 && exhausted.sendMessageDic.count==0);
 CHECK(notices.count==beforeCurfew+1);
 // A business result or uncertain transport timeout must never trigger candidate replay.
 for (NSNumber *code in @[@96305,@(-1001),@(-1005)]) {
    Harness *terminal=[Harness new]; terminal.myUserID=@"sender";
    terminal.messagePushHTTPHosts=@[@"https://other.example"];
    [terminal trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(terminal.sendMessageQueue,^{});
    terminal.failure(code.integerValue,@"",nil); dispatch_sync(terminal.sendMessageQueue,^{});
    CHECK(terminal.pushes==1 && terminal.messageDelegate.failures==1);
 }
 // A real ACK arriving while the alternate HTTP request is pending prevents a later curfew popup.
 Harness *acked=[Harness new]; acked.myUserID=@"sender"; acked.messagePushHTTPHosts=@[@"https://other.example"];
 [acked trackChatMessage:message tcpSendFailed:YES]; dispatch_sync(acked.sendMessageQueue,^{});
 acked.failure(NSURLErrorSecureConnectionFailed,@"tls",nil); dispatch_sync(acked.sendMessageQueue,^{});
 [acked receiveMessageDealForChatMessageAckWith:tcpAck]; dispatch_sync(acked.sendMessageQueue,^{});
 acked.failure(96305,@"late curfew",nil); dispatch_sync(acked.sendMessageQueue,^{});
 CHECK(acked.messageDelegate.successes==1 && acked.messageDelegate.failures==0 && notices.count==beforeCurfew+1);
 [[NSNotificationCenter defaultCenter] removeObserver:observer];
 puts("PASS: DNS1 TLS failover, bounded attempts, no business replay, ACK priority, HTTP rejection messages, stale callback and session isolation");
}return 0;}
'''
with tempfile.TemporaryDirectory(prefix='message-failure-test-') as tmp:
    src,exe=Path(tmp)/'test.m',Path(tmp)/'test'
    src.write_text(code)
    other = Path(tmp)/'request-module.m'
    other.write_text('#import "' + str(sdk / 'ConnectModule/HttpToTcpRequest/NoaIMRequestSessionFence.h') + '"\nvoid InvalidateSessionFromRequestModule(NSObject *owner) { NoaIMInvalidateRequestSession(owner); }\n')
    subprocess.run(['xcrun','clang','-fobjc-arc','-fblocks','-framework','Foundation',str(src),str(other),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
