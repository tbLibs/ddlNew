#import <Foundation/Foundation.h>

static NSMutableArray<NSString *> *captured;
static NSUInteger checks, failures;
static BOOL emptyFixture;
static NSString *const secrets = @"anonymous_body_canary anonymous_token_canary anonymous_device_canary anonymous_sts_canary https://resource.invalid/private/object /Users/anonymous/private/local-resource";

/// 用真实Foundation格式化截获输出，替代控制台与SDK日志开关，不复制生产格式。
static void Capture(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void Capture(NSString *format, ...) {
    va_list arguments; va_start(arguments, format);
    [captured addObject:[[NSString alloc] initWithFormat:format arguments:arguments]];
    va_end(arguments);
}
#define NSLog Capture
#define CIMLog Capture

@interface NoaLocalLogger : NSObject
+ (void)info:(NSString *)value;
+ (void)error:(NSString *)value;
+ (void)verbose:(NSString *)value;
@end
@implementation NoaLocalLogger
/// 强制观察生产info边界，不能以关闭日志逃避泄漏回归。
+ (void)info:(NSString *)value { [captured addObject:value]; }
/// 观察生产错误输出，不建立远程日志连接。
+ (void)error:(NSString *)value { [captured addObject:value]; }
/// 观察生产发送诊断，验证开启verbose时也安全。
+ (void)verbose:(NSString *)value { [captured addObject:value]; }
@end

@interface Fixture : NSObject
@property int dataType, status;
@property long long sendTime, code;
@property NSString *msgId, *ackMsgId, *sMsgId, *requestId, *body, *userID, *userToken, *message, *url;
@property Fixture *chatMessage, *chatMessageAck, *chatMessageToAck, *responseMessage, *authMessage, *requestMessage;
@property NSData *data;
@end

@interface NSDictionary (FixtureJSON)
- (NSString *)mj_JSONString;
@end
@implementation NSDictionary (FixtureJSON)
/// 替代MJExtension序列化形状，实际Foundation输出仍由生产方法构造。
- (NSString *)mj_JSONString {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self options:0 error:nil] encoding:NSUTF8StringEncoding];
}
@end
@implementation Fixture
/// 用匿名正文/凭据模拟SDK整包description，字段ID保持非认证消息身份。
- (NSString *)description { return secrets; }
@end

@interface ECDHKeyManager : NSObject
+ (NSString *)hexStringFromData:(NSData *)data;
@end
@implementation ECDHKeyManager
/// 仅替代十六进制编码形状，输出实际输入字节而非固定哨兵。
+ (NSString *)hexStringFromData:(NSData *)data {
    NSMutableString *value = [NSMutableString string];
    const unsigned char *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) [value appendFormat:@"%02x", bytes[i]];
    return value;
}
@end

@interface FixtureManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)myUserToken;
@end
@implementation FixtureManager
/// 返回不涉及真实账户的SDK形状替身。
+ (instancetype)sharedManager { return [FixtureManager new]; }
/// 空凭据和非空凭据都参与日志验收。
- (NSString *)myUserToken { return emptyFixture ? @"" : secrets; }
@end
#define IMSDKManager [FixtureManager sharedManager]

enum { LingIMLoganTypeApi = 1 };
enum { IMMessage_DataType_ImchatMessageAck = 3, IMMessage_DataType_ImchatMessageToAck = 4 };
@interface NoaIMLoganManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)configLoganContent:(NSDictionary *)dictionary;
- (void)writeLoganWith:(NSInteger)type loganContent:(NSString *)content;
@end
@implementation NoaIMLoganManager
/// 不初始化真实Logan，只替代日志终端。
+ (instancetype)sharedManager { return [NoaIMLoganManager new]; }
/// 生产方法创建的原字典经实际Foundation序列化接受泄漏断言。
- (NSString *)configLoganContent:(NSDictionary *)dictionary {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil] encoding:NSUTF8StringEncoding];
}
/// 保留生产Logan调用边界，捕获序列化结果。
- (void)writeLoganWith:(NSInteger)type loganContent:(NSString *)content { [captured addObject:content]; }
@end

/// 输出只报告用例名和字段类别，失败时也不打印完整捕获内容。
static void Check(NSString *name, NSArray<NSString *> *required) {
    checks++;
    NSString *output = [captured componentsJoinedByString:@"\n"];
    NSMutableString *normalized = [NSMutableString string];
    for (NSUInteger i = 0; i < output.length; i++) {
        unichar c = [output characterAtIndex:i];
        if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:c]) [normalized appendFormat:@"%C", c];
    }
    BOOL failed = captured.count == 0;
    for (NSString *value in [secrets componentsSeparatedByString:@" "]) if ([output containsString:value]) failed = YES;
    // 捕捉NSData description分组十六进制和密钥前16字节预览。
    if ([[normalized lowercaseString] containsString:@"616e6f6e796d6f75735f626f64795f6361"]) failed = YES;
    for (NSString *field in required) if (![output containsString:field]) failed = YES;
    if (failed) { failures++; fprintf(stderr, "FAIL %s: sensitive output or missing safe diagnostic\n", name.UTF8String); }
    [captured removeAllObjects];
}

@interface ScenarioOwner : NSObject
@property NSData *aesKey, *frameBuffer;
@property NSString *url, *msgId;
@property NSString *socketHost;
@property NSInteger socketPort;
@property BOOL isTokenExpired, isTokenRefreshing;
- (NSString *)dataToHexString:(NSData *)data;
- (NSString *)hexStringFromData:(NSData *)data;
- (void)loganConfigWith:(NSString *)url param:(NSDictionary *)param failure:(NSString *)failureReason ztid:(NSString *)ztid;
- (void)sentryUploadWithDictionary:(NSDictionary *)dictionary transaction:(NSString *)transaction;
- (void)sentryUploadWithEventObj:(id)eventObj errorCode:(NSString *)errorCode;
- (void)recordInitializationSentryStage:(NSString *)stage result:(NSNumber *)result reason:(NSString *)reason;
- (void)run;
@end
@implementation ScenarioOwner
/// 生产调用的十六进制转换使用真实输入字节。
- (NSString *)dataToHexString:(NSData *)data { return [ECDHKeyManager hexStringFromData:data]; }
/// 共享密钥助手使用同一真实输入编码，保证字节泄漏断言有效。
- (NSString *)hexStringFromData:(NSData *)data { return [ECDHKeyManager hexStringFromData:data]; }
/* PRODUCTION_HTTP_METHODS */
/* PRODUCTION_SOCKET_METHOD */
/// 只替代遥测最后的输出端，执行真实Socket reason提取逻辑。
- (void)recordInitializationSentryStage:(NSString *)stage result:(NSNumber *)result reason:(NSString *)reason {
    [captured addObject:[NSString stringWithFormat:@"stage=%@ result=%@ reason=%@", stage, result, reason]];
}
/// 场景数据全部匿名，原样执行提取到的生产日志调用。
- (void)run {
    Fixture *fixture = [Fixture new]; fixture.dataType = 3; fixture.status = 200; fixture.code = 401;
    fixture.sendTime = 1700000000123LL; fixture.msgId = @"safe-msg-id"; fixture.ackMsgId = @"safe-ack-id"; fixture.sMsgId = @"safe-server-id"; fixture.requestId = @"safe-request-id";
    fixture.body = emptyFixture ? @"" : secrets; fixture.userToken = fixture.body; fixture.userID = @"anonymous-user"; fixture.message = secrets;
    fixture.chatMessage = fixture; fixture.chatMessageAck = fixture; fixture.chatMessageToAck = fixture; fixture.responseMessage = fixture; fixture.authMessage = fixture; fixture.requestMessage = fixture;
    Fixture *receiveMessage = fixture, *sendMessage = fixture, *message = fixture, *userOptions = fixture, *resp = fixture;
    Fixture *requestModel = fixture; requestModel.url = emptyFixture ? @"" : secrets;
    NSData *sharedSecret = [fixture.body dataUsingEncoding:NSUTF8StringEncoding], *aesKey = sharedSecret, *sharedSecretData = sharedSecret, *derivedKey = sharedSecret, *sessionKey = sharedSecret;
    NSData *encryptedBody = sharedSecret, *encryptedData = sharedSecret, *expectedHMAC = sharedSecret, *receivedHMAC = sharedSecret;
    NSData *x509Data = sharedSecret, *keyDataToUse = sharedSecret, *rawPublicKey = sharedSecret, *publicKeyData = sharedSecret;
    NSData *frameIdentifier = sharedSecret, *expectedFrameIdentifier = sharedSecret, *receivedFrameIdentifier = sharedSecret;
    NSData *publicKeyBytes = sharedSecret, *serverPublicKeyBytes = sharedSecret;
    self.aesKey = aesKey; self.frameBuffer = sharedSecret; self.url = secrets; self.msgId = @"safe-request-id";
    id data = emptyFixture ? nil : @{ @"token": secrets, @"secretKey": secrets, @"remark": secrets }, respData = data, responseObject = data;
    NSString *newUserId = @"anonymous-user", *newUserToken = fixture.body, *newToken = fixture.body;
    NSString *url = secrets, *fullPath = secrets, *path = secrets, *method = @"POST", *body = fixture.body, *ztid = @"safe-trace-id";
    NSDictionary *param = data, *params = data, *headerDic = data;
    NSError *fixtureError = [NSError errorWithDomain:NSURLErrorDomain code:-1009 userInfo:@{NSLocalizedDescriptionKey:secrets, NSURLErrorFailingURLErrorKey:[NSURL URLWithString:@"https://resource.invalid/private/object"]}];
    NSError *error = fixtureError, *err = fixtureError;
    CFErrorRef cfError = (__bridge CFErrorRef)fixtureError;
    CFErrorRef error1 = cfError, error2 = cfError, error3 = cfError, exportError = cfError;
    NSString *methodName = @"anonymous-method", *errorMsg = secrets, *errorMessage = secrets;
    NSString *tokenAction = @"cache_request", *msg = secrets, *traceId = @"safe-trace-id", *status = secrets;
    NSInteger code = -1009;
    self.socketHost = @"127.0.0.1"; self.socketPort = 443;
    NSException *exception = [NSException exceptionWithName:@"NSInvalidArgumentException" reason:secrets userInfo:@{ @"resource": secrets }];
    /* PRODUCTION_LOG_CALLS */
    /* PRODUCTION_SOCKET_CALLS */
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"ZTSentryEventUploadNotification" object:nil queue:nil usingBlock:^(NSNotification *note) {
        [captured addObject:[note.userInfo description]];
    }];
    [self loganConfigWith:secrets param:data failure:secrets ztid:@"safe-trace-id"];
    Check(@"http-log-payload-and-notification", @[@"safe-trace-id", @"event_http"]);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    // 非认证消息ID和ACK字段不能随脱敏一起被删除。
    if (!emptyFixture) {
        Fixture *chat = [Fixture new], *ack = [Fixture new], *receipt = [Fixture new];
        chat.msgId = @"chat-local"; chat.sMsgId = @"chat-server"; chat.sendTime = 1700000000100LL;
        ack.msgId = @"ack-envelope"; ack.ackMsgId = @"chat-local"; ack.sMsgId = @"chat-server"; ack.sendTime = 1700000000200LL;
        receipt.msgId = @"receipt-envelope"; receipt.ackMsgId = @"chat-local"; receipt.sMsgId = @"chat-server";
        fixture.chatMessage = chat; fixture.chatMessageAck = ack; fixture.chatMessageToAck = receipt;
        /* ACK_IDENTITY_CHECK */
    }
}
@end

/// 同一生产日志边界覆盖非空与空载荷，避免nil导致格式化崩溃或关闭全部日志。
int main(void) {
    @autoreleasepool {
        captured = [NSMutableArray new];
        emptyFixture = NO; [[ScenarioOwner new] run];
        emptyFixture = YES; [[ScenarioOwner new] run];
        printf("Log redaction checks: %lu checked, %lu failed\n", (unsigned long)checks, (unsigned long)failures);
        return failures == 0 ? 0 : 1;
    }
}
