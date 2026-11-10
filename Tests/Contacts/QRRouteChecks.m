#import <Foundation/Foundation.h>

typedef void (^LingIMSuccessCallback)(id, NSString *);
typedef void (^LingIMFailureCallback)(NSInteger, NSString *, NSString *);
enum { LingRequestPost, LingIMHttpRequestTypePOST };
static BOOL kAllHttpRequestUseTcp;
static NSString *sentPath;
static NSDictionary *sentParameters;
#include "Route.inc"

@interface Fixture : NSObject
+ (NSString *)apiHost;
+ (NSString *)tenantCode;
+ (NSString *)method5:(NSString *)method uri:(NSString *)uri timestamp:(long long)timestamp;
@end
#define IMSDKManager Fixture
#define LXChatEncrypt Fixture
#define LingIMTcpRequestModel Fixture

@implementation Fixture
+ (NSString *)apiHost { return @"https://fixture.invalid"; }
+ (NSString *)tenantCode { return @"fixture"; }
// Capture the real signing method's URI without invoking cryptography or credentials.
+ (NSString *)method5:(NSString *)method uri:(NSString *)uri timestamp:(long long)timestamp { return uri; }
+ (void)sendTcpRequestWithParam:(NSDictionary *)params Url:(NSString *)url Method:(NSInteger)method SuccessFunc:(LingIMSuccessCallback)success FailureFunc:(LingIMFailureCallback)failure {
    sentPath = url; sentParameters = params;
}
- (void)netRequestWithType:(NSInteger)type path:(NSString *)path parameters:(NSDictionary *)params onSuccess:(LingIMSuccessCallback)success onFailure:(LingIMFailureCallback)failure {
    sentPath = path; sentParameters = params;
}
#include "Dispatch.inc"
#include "Signature.inc"
@end

int main(void) { @autoreleasepool {
    Fixture *client = [Fixture new];
    NSMutableDictionary *params = [@{@"userUid": @"fixture-user", @"content": @"fixture-qr+/="} mutableCopy];
    int failures = 0;
    for (int tcp = 0; tcp <= 1; tcp++) {
        kAllHttpRequestUseTcp = tcp;
        [client getScanQrContentTransformData:params onSuccess:nil onFailure:nil];
        if (![sentPath isEqualToString:@"/biz/scan/group/readScanContent"]) {
            fprintf(stderr, "FAIL %s QR conversion request path lacks the leading slash\n", tcp ? "TCP" : "HTTP"); failures++;
        }
        if (![[client getUrlSignature:1 url:sentPath] isEqualToString:@"scan/group/readScanContent"]) {
            fprintf(stderr, "FAIL QR conversion signature includes an incorrect business prefix\n"); failures++;
        }
        if (![sentParameters isEqualToDictionary:params]) {
            fprintf(stderr, "FAIL QR content or user identity changed\n"); failures++;
        }
    }
    if (failures) return 1;
    puts("QR route and signing contract: 6 passed");
    return 0;
} }
