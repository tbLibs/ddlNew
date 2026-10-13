//
//  NoaIMRequestSessionFence.h
//  NoaChatSDKCore
//
//  Created by taobo on 2026/10/13.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// 退出撤销请求归属，排队模型只能绑定一次，重入队不能改用下一账号的身份。
static char NoaIMRequestOwnerSessionKey;
static char NoaIMRequestBoundSessionKey;

static inline NSUUID *NoaIMRequestSession(NSObject *owner) {
    @synchronized (owner) {
        NSUUID *session = objc_getAssociatedObject(owner, &NoaIMRequestOwnerSessionKey);
        if (!session) {
            session = [NSUUID UUID];
            objc_setAssociatedObject(owner, &NoaIMRequestOwnerSessionKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return session;
    }
}

static inline BOOL NoaIMBindRequestToSession(NSObject *owner, NSObject *request) {
    @synchronized (owner) {
        NSUUID *session = NoaIMRequestSession(owner);
        NSUUID *bound = objc_getAssociatedObject(request, &NoaIMRequestBoundSessionKey);
        if (!bound) {
            bound = session;
            objc_setAssociatedObject(request, &NoaIMRequestBoundSessionKey, bound, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return [bound isEqual:session];
    }
}

static inline BOOL NoaIMRequestIsCurrent(NSObject *owner, NSObject *request) {
    @synchronized (owner) {
        return [objc_getAssociatedObject(request, &NoaIMRequestBoundSessionKey) isEqual:NoaIMRequestSession(owner)];
    }
}

static inline void NoaIMInvalidateRequestSession(NSObject *owner) {
    @synchronized (owner) {
        objc_setAssociatedObject(owner, &NoaIMRequestOwnerSessionKey, [NSUUID UUID], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
