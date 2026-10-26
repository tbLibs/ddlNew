#!/usr/bin/env python3
"""Compile the production record filter with a Foundation-only message fixture.

The fixture replaces database/UI delivery with a counter; it checks which wire
events survive removal of the calling engines, without requiring a call server.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / "NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/OtherModules/"
          "NoaChatClient/SdkManager/NoaIMSDKManager+CallRecords.m").read_text()
start = source.index("- (void)imSdkDealReceiveChatMessageForCall:")
opening = source.index("{", start)
depth = 1
end = opening + 1
while depth:
    depth += (source[end] == "{") - (source[end] == "}")
    end += 1
production_method = source[start:end]

fixture = r'''
#import <Foundation/Foundation.h>
@interface NetCallMessage : NSObject
@property NSInteger chatType;
@property NSInteger status;
@property(copy) NSString *roomCreateUser;
@end
@implementation NetCallMessage
@end
@interface IMChatMessage : NSObject
@property(strong) NetCallMessage *netCallMessage;
@end
@implementation IMChatMessage
@end
@interface RecordReceiver : NSObject
@property NSUInteger saved;
- (NSString *)myUserID;
- (void)saveChatMessageForCallWith:(IMChatMessage *)message;
- (void)imSdkDealReceiveChatMessageForCall:(IMChatMessage *)message;
@end
@implementation RecordReceiver
- (NSString *)myUserID { return @"current-user"; }
- (void)saveChatMessageForCallWith:(IMChatMessage *)message { self.saved++; }
__PRODUCTION_METHOD__
@end
int main(void) {
    @autoreleasepool {
        // Completed/missed direct calls survive; active invitations/accepts do not.
        NSSet *directHistory = [NSSet setWithArray:@[@2, @3, @4, @5, @7, @12]];
        // Group history records start/end, not each live participant update.
        NSSet *groupHistory = [NSSet setWithArray:@[@1, @11]];
        NSUInteger checked = 0;
        for (NSInteger kind = 0; kind <= 3; kind++) {
            for (NSInteger status = 0; status <= 13; status++) {
                for (NSString *creator in @[@"current-user", @"other-user"]) {
                    RecordReceiver *receiver = [RecordReceiver new];
                    IMChatMessage *message = [IMChatMessage new];
                    message.netCallMessage = [NetCallMessage new];
                    message.netCallMessage.chatType = kind;
                    message.netCallMessage.status = status;
                    message.netCallMessage.roomCreateUser = creator;
                    BOOL expected = NO;
                    if (kind == 1) {
                        expected = [directHistory containsObject:@(status)] ||
                            (status == 8 && [creator isEqualToString:@"other-user"]);
                    } else if (kind == 2) {
                        expected = [groupHistory containsObject:@(status)];
                    }
                    [receiver imSdkDealReceiveChatMessageForCall:message];
                    if (receiver.saved != (NSUInteger)expected) {
                        fprintf(stderr, "FAIL: kind=%ld status=%ld creator=%s\n",
                                (long)kind, (long)status, creator.UTF8String);
                        return 1;
                    }
                    checked++;
                }
            }
        }
        printf("PASS: %lu direct, group and unknown history-event cases\n",
               (unsigned long)checked);
    }
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix="ddlNew-call-records-") as directory:
    path = Path(directory)
    (path / "checks.m").write_text(fixture.replace("__PRODUCTION_METHOD__", production_method))
    subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "Foundation",
                    str(path / "checks.m"), "-o", str(path / "checks")], check=True)
    subprocess.run([str(path / "checks")], check=True)
