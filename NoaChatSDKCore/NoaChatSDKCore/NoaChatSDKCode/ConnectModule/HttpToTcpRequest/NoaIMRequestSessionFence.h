//
//  NoaIMRequestSessionFence.h
//  NoaChatSDKCore
//
//  Created by taobo on 2026/10/13.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// 退出撤销请求归属，排队模型只能绑定一次，重入队不能改用下一账号的身份。
// 分类和 Socket 实现在不同编译单元；头文件里的 static 变量会各有一份地址，
// 导致退出在一处失效，而另一处仍接受旧回执。运行时注册键在所有编译单元一致。
static inline const void *NoaIMRequestOwnerSessionKey(void) {
    return sel_registerName("noa_im_request_owner_session_key");
}
static inline const void *NoaIMRequestBoundSessionKey(void) {
    return sel_registerName("noa_im_request_bound_session_key");
}

static inline NSUUID *NoaIMRequestSession(NSObject *owner) {
    @synchronized (owner) {
        NSUUID *session = objc_getAssociatedObject(owner, NoaIMRequestOwnerSessionKey());
        if (!session) {
            session = [NSUUID UUID];
            objc_setAssociatedObject(owner, NoaIMRequestOwnerSessionKey(), session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return session;
    }
}

static inline BOOL NoaIMBindRequestToSession(NSObject *owner, NSObject *request) {
    @synchronized (owner) {
        NSUUID *session = NoaIMRequestSession(owner);
        NSUUID *bound = objc_getAssociatedObject(request, NoaIMRequestBoundSessionKey());
        if (!bound) {
            bound = session;
            objc_setAssociatedObject(request, NoaIMRequestBoundSessionKey(), bound, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return [bound isEqual:session];
    }
}

static inline BOOL NoaIMRequestIsCurrent(NSObject *owner, NSObject *request) {
    @synchronized (owner) {
        return [objc_getAssociatedObject(request, NoaIMRequestBoundSessionKey()) isEqual:NoaIMRequestSession(owner)];
    }
}

static inline void NoaIMInvalidateRequestSession(NSObject *owner) {
    @synchronized (owner) {
        objc_setAssociatedObject(owner, NoaIMRequestOwnerSessionKey(), [NSUUID UUID], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
