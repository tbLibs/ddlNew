#import "../../NoaChatSDKCore/NoaChatSDKCore/NoaChatSDKCode/ConnectModule/HttpToTcpRequest/NoaIMRequestSessionFence.h"

int main(void) {
    @autoreleasepool {
        NSObject *manager = [NSObject new];
        NSObject *queuedLogout = [NSObject new];
        NSCAssert(NoaIMBindRequestToSession(manager, queuedLogout), @"首次请求绑定当前会话");
        NSCAssert(NoaIMRequestIsCurrent(manager, queuedLogout), @"当前排队请求可发送");
        NSUUID *firstSession = NoaIMRequestSession(manager);
        NoaIMInvalidateRequestSession(manager);
        NSCAssert(!NoaIMRequestIsCurrent(manager, queuedLogout), @"退出后排队logout不能重发");
        NSCAssert(!NoaIMBindRequestToSession(manager, queuedLogout), @"旧请求重入队不能改绑新会话");
        NSCAssert(![firstSession isEqual:NoaIMRequestSession(manager)], @"同账号重登也必须新轮次");
        NSObject *newRequest = [NSObject new];
        NSCAssert(NoaIMBindRequestToSession(manager, newRequest), @"新用户请求正常绑定");
        NoaIMInvalidateRequestSession(manager);
        NSCAssert(!NoaIMRequestIsCurrent(manager, newRequest), @"复制出缓存队列的请求仍受退出撤销约束");
        NSLog(@"SDK request session fence: 7 checks passed");
    }
    return 0;
}
