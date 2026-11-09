"""Verify the production push entry uses the same HTTP transport as xgd."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
sdk = root / "NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode"
source = (sdk / "ConnectModule/HttpRequest/NoaIMHttpManager+Message.m").read_text()
start = source.index("- (void)MessagePushMsg:")
end = source.index("{", start) + 1
depth = 1
while depth:
    depth += (source[end] == "{") - (source[end] == "}")
    end += 1
routing = source[start:end].replace("[[NoaIMSDKManager sharedTool] isUserAuthenticated]", "self.isUserAuthenticated")
code = r"""
#import <Foundation/Foundation.h>
typedef void (^LingIMSuccessCallback)(id, NSString *);
typedef void (^LingIMFailureCallback)(NSInteger, NSString *, NSString *);
static BOOL kAllHttpRequestUseTcp = YES;
#define LingRequestPost 1
#define Message_Push_Msg_Url @"/biz/message/pushMsg"
#define SOCKETMANAGER self
@interface LingIMTcpRequestModel:NSObject
+ (void)sendTcpRequestWithParam:(id)param Url:(NSString *)url Method:(NSInteger)method SuccessFunc:(LingIMSuccessCallback)success FailureFunc:(LingIMFailureCallback)failure;
@end
@implementation LingIMTcpRequestModel
+ (void)sendTcpRequestWithParam:(id)param Url:(NSString *)url Method:(NSInteger)method SuccessFunc:(LingIMSuccessCallback)success FailureFunc:(LingIMFailureCallback)failure {
    NSCAssert(NO, @"pushMsg must use legacy HTTP, including while TCP is authenticated");
}
@end
@interface Harness:NSObject
@property BOOL isUserAuthenticated, currentSocketConnectStatus;
@property NSInteger requests;
@property(copy) NSData *payload;
@property(copy) NSString *path;
- (void)netRequestMessagePushWithPath:(NSString *)path paramData:(NSData *)data onSuccess:(LingIMSuccessCallback)success onFailure:(LingIMFailureCallback)failure;
@end
@implementation Harness
- (void)netRequestMessagePushWithPath:(NSString *)path paramData:(NSData *)data onSuccess:(LingIMSuccessCallback)success onFailure:(LingIMFailureCallback)failure {
    self.requests++; self.payload=data; self.path=path;
    if (failure) failure(96305, @"服务端拒绝原文", @"trace");
}
"""
code += routing + r"""
@end
int main() { @autoreleasepool {
    Harness *h=[Harness new];
    const unsigned char bytes[]={0xff,0,1,0x80};
    NSData *data=[NSData dataWithBytes:bytes length:sizeof(bytes)];
    for (int config=0;config<2;config++) {
        kAllHttpRequestUseTcp=config;
        for (int auth=0;auth<2;auth++) {
            h.isUserAuthenticated=auth;
            for (int connected=0;connected<2;connected++) {
                h.currentSocketConnectStatus=connected;
                NSInteger before=h.requests;
                __block NSInteger result=0; __block NSString *message;
                [h MessagePushMsg:data onSuccess:nil onFailure:^(NSInteger c, NSString *m, NSString *t){result=c;message=m;}];
                NSCAssert(h.requests==before+1 && [h.path isEqual:Message_Push_Msg_Url] && [h.payload isEqual:data], @"HTTP receives unchanged original protobuf");
                NSCAssert(result==96305 && [message isEqual:@"服务端拒绝原文"], @"rejection reaches caller");
            }
        }
    }
    puts("PASS: 8 legacy HTTP routing states, protobuf preservation and rejection callback");
} return 0; }
"""
with tempfile.TemporaryDirectory(prefix="push-http-check-") as directory:
    path = Path(directory)
    (path / "test.m").write_text(code)
    subprocess.run(["xcrun", "clang", "-fobjc-arc", "-fblocks", "-framework", "Foundation", str(path / "test.m"), "-o", str(path / "test")], check=True)
    subprocess.run([str(path / "test")], check=True)
