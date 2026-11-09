"""Exercise production request construction with an alternate HTTP host, without a network."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / "NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/HttpRequest/NoaIMHttpManager.m").read_text()
start = source.index("- (void)netRequestMessagePushWithPath:(NSString *)path httpHost:")
start = source.index("{", start) + 1
body = source[start:source.index("__weak typeof(self)", start)].replace("return;", "return nil;")
code = r'''
#import <Foundation/Foundation.h>
#define CHECK(x) NSCAssert((x), @#x)
@interface AFJSONRequestSerializer:NSObject
+ (instancetype)serializer;
- (NSMutableURLRequest *)requestWithMethod:(NSString *)method URLString:(NSString *)url parameters:(id)parameters error:(NSError **)error;
@end
@implementation AFJSONRequestSerializer
+ (instancetype)serializer { return [self new]; }
- (NSMutableURLRequest *)requestWithMethod:(NSString *)method URLString:(NSString *)url parameters:(id)parameters error:(NSError **)error {
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod=method; return request;
}
@end
@interface Fixture:NSObject
+ (instancetype)sharedManager;
+ (NSString *)uuidForDevice;
+ (NSString *)appVersion;
- (NSString *)getMessageID;
@end
@implementation Fixture
+ (instancetype)sharedManager { return [self new]; }
+ (NSString *)uuidForDevice { return @"fixture-device"; }
+ (NSString *)appVersion { return @"1.0"; }
- (NSString *)getMessageID { return @"fixture-trace"; }
@end
@interface NSDate (TestClock)
+ (long long)getCurrentTimeIntervalWithSecond;
@end
@implementation NSDate (TestClock)
+ (long long)getCurrentTimeIntervalWithSecond { return 123; }
@end
#define FCUUID Fixture
#define NoaIMDeviceTool Fixture
#define NoaIMManagerTool Fixture
#define IMSDKManager self
@interface Harness:NSObject
@property(copy) NSString *orgName, *myUserID, *myUserToken, *currentLiceseId, *apiHost;
@end
@implementation Harness
- (NSString *)getUrlSignature:(long long)timestamp url:(NSString *)path {
    CHECK(timestamp==123 && [path isEqual:@"/biz/message/pushMsg"]);
    return @"fixture-signature";
}
- (NSMutableURLRequest *)buildRequest:(NSString *)path host:(NSString *)httpHost body:(NSData *)paramData {
'''
code += body + r'''
    return request;
}
@end
int main() { @autoreleasepool {
    Harness *h=[Harness new]; h.orgName=@"org"; h.myUserID=@"sender";
    h.myUserToken=@"fixture-token"; h.currentLiceseId=@"fixture-license";
    h.apiHost=@"https://original.example:2027";
    const unsigned char bytes[]={0xff,0,0x80,1};
    NSData *body=[NSData dataWithBytes:bytes length:sizeof(bytes)];
    for (NSString *host in @[h.apiHost,@"https://alternate.example:10027"]) {
        NSMutableURLRequest *request=[h buildRequest:@"/biz/message/pushMsg" host:host body:body];
        CHECK([request.URL.absoluteString isEqual:[host stringByAppendingString:@"/biz/message/pushMsg"]]);
        CHECK([request.HTTPMethod isEqual:@"POST"] && [request.HTTPBody isEqual:body]);
        CHECK([[request valueForHTTPHeaderField:@"Content-Type"] isEqual:@"application/x-protobuf"]);
        CHECK([[request valueForHTTPHeaderField:@"ZTID"] isEqual:@"fixture-trace"]);
        CHECK([[request valueForHTTPHeaderField:@"signature"] isEqual:@"fixture-signature"]);
        CHECK([[request valueForHTTPHeaderField:@"token"] isEqual:@"fixture-token"]);
        CHECK([h.apiHost isEqual:@"https://original.example:2027"]);
    }
    puts("PASS: alternate HTTP URL, original protobuf, request-path signature, headers and unchanged global host");
} return 0; }
'''
with tempfile.TemporaryDirectory(prefix="push-request-check-") as directory:
    path = Path(directory)
    (path / "test.m").write_text(code)
    subprocess.run(["xcrun", "clang", "-fobjc-arc", "-fblocks", "-framework", "Foundation", str(path / "test.m"), "-o", str(path / "test")], check=True)
    subprocess.run([str(path / "test")], check=True)
