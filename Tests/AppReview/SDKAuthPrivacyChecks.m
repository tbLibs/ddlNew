#import <Foundation/Foundation.h>
#import "LingImmessage.pbobjc.h"

int main(void) {
    @autoreleasepool {
        IMAuthMessage *message = [IMAuthMessage message];
        message.msgId = @"m";
        message.userId = @"u";
        message.token = @"t";
        message.deviceType = @"IOS";
        message.deviceUuid = @"d";
        message.orgName = @"o";
        message.platform = @"iOS";
        message.versionNumber = @"1";
        // Independent wire fixture: fields 1/2/3/5/6/7/8/9, no field 4 (IP).
        const uint8_t expected[] = {
            0x0a,1,'m', 0x12,1,'u', 0x1a,1,'t', 0x2a,3,'I','O','S',
            0x32,1,'d', 0x3a,1,'o', 0x42,3,'i','O','S', 0x4a,1,'1'
        };
        NSData *wire = [NSData dataWithBytes:expected length:sizeof(expected)];
        if (![message.data isEqualToData:wire]) {
            fprintf(stderr, "FAIL: AUTH wire format changed or includes client IP\n");
            return 1;
        }
        NSError *error = nil;
        IMAuthMessage *decoded = [IMAuthMessage parseFromData:wire error:&error];
        if (error || ![decoded.token isEqualToString:@"t"] || decoded.loginIp.length != 0) {
            fprintf(stderr, "FAIL: AUTH fields did not round-trip\n");
            return 1;
        }
        puts("PASS: SDK AUTH keeps wire numbers and omits the optional login IP");
    }
    return 0;
}
