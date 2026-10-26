// Receives historical records only; no calling API is exposed.
#import "NoaIMSDKManager.h"
NS_ASSUME_NONNULL_BEGIN
@interface NoaIMSDKManager (CallRecords)
- (void)imSdkDealReceiveServiceMessageForCall:(IMServerMessage *)message;
- (void)imSdkDealReceiveServiceMessageForGroupCallInfoChange:(IMServerMessage *)message;
- (void)imSdkDealReceiveChatMessageForCall:(IMChatMessage *)message;
@end
NS_ASSUME_NONNULL_END
