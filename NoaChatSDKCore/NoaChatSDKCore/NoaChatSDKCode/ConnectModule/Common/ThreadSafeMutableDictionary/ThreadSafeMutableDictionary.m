//
//  ThreadSafeMutableDictionary.m
//  ThreadSafeMutableDemo
//
//  Created by Gavin Xiang on 2021/11/30.
//

/*
 Instead of adding methods like threadSafeObjectForKey: in a category, and requiring all developers working on an application to use that method, another technique is to create a subclass of NSMutableDictionary, overriding methods like objectForKey: and replacing them with thread-safe implementations.

 NSMutableDictionary is part of the NSDictionary class cluster. Subclassing within a class cluster is somewhat complicated, and you shouldn't do it without good reason. For an introduction to both class clusters and ways to subclass them, see the primer on Class Clusters.

 The implementation below uses the "composite object" technique described in the class cluster documentation. It defines an object which includes both a real mutable dictionary and a lock. It also implements each of the "primitive" methods in NSMutableDictionary.
 */

/*
 Difference between ARC and autorelease explained in code :

 ARC :

 -somefunc {
   id obj = [NSArray array];
   NSLog(@"%@", obj);
   // ARC now calls release for the first object

   id obj2 = [NSArray array];
   NSLog(@"%@", obj2);
   // ARC now calls release for the second object
 }
 
 Autorelease :

 -somefunc {
   id obj = [NSArray array];
   NSLog(@"%@", obj);

   id obj2 = [NSArray array];
   NSLog(@"%@", obj2);
 }
 // Objects are released some time after this
 
 Basically ARC works once a variable isn't used anymore in a scope, while autorelease waits until it reaches the main loop and then calls release on all objects in the pool. ARC is used inside the scope, autorelease is used outside the scope of the function.
 */

#import "ThreadSafeMutableDictionary.h"
//#import <libkern/OSAtomic.h>
#import <os/lock.h>
#import <objc/runtime.h>

#if !__has_feature(objc_arc)
#error This code needs ARC. Use compiler option -fobjc-arc
#endif

/*
 'OSSpinLock' is deprecated: first deprecated in iOS 10.0 - Use os_unfair_lock() from <os/lock.h> instead
 
 os_unfair_lock是在iOS10之后为了替代自旋锁OSSpinLock而诞生的，主要是通过线程休眠的方式来继续加锁，而不是一个“忙等”的锁。
 猜测是为了解决自旋锁的优先级反转的问题。
 */

/*
#ifndef UNFAIR_LOCKED
#define UNFAIR_LOCKED(...) do { \
[lock lock]; \
__VA_ARGS__; \
[lock unlock]; \
} while (NO)
#endif

#ifndef UNFAIR_LOCKED_BLOCK
#define UNFAIR_LOCKED_BLOCK(block)\
[lock lock];\
block();\
[lock unlock];
#endif
 */

/*
#define LOCKED(...) do { \
OSSpinLockLock(&_lock); \
__VA_ARGS__; \
OSSpinLockUnlock(&_lock); \
} while (NO)
 */

#ifndef UNFAIR_LOCKED
#define UNFAIR_LOCKED(...) do { \
os_unfair_lock_lock(&_lock); \
__VA_ARGS__; \
os_unfair_lock_unlock(&_lock); \
} while (NO)
#endif

#ifndef UNFAIR_LOCKED_BLOCK
#define UNFAIR_LOCKED_BLOCK(block)\
os_unfair_lock_lock(&_lock);\
block();\
os_unfair_lock_unlock(&_lock);
#endif

@implementation ThreadSafeMutableDictionary {
//    NSLock *lock;
//    OSSpinLock _lock;
    os_unfair_lock _lock;
    NSMutableDictionary *realDictionary; // Class Cluster!
}

#pragma mark - Primitive methods in NSDictionary

- (NSUInteger)count {
    //  I believe we don't need to lock for this.
    return [realDictionary count];
}

- (NSEnumerator *)keyEnumerator {
    NSEnumerator *result;
    //    It's not clear whether we need to lock for this operation,
    //    but let's be careful.
    UNFAIR_LOCKED(result = [realDictionary keyEnumerator]);
    return result;
}

- (id)objectForKey:(id)aKey {
    __block id obj;
    @autoreleasepool {
        UNFAIR_LOCKED_BLOCK(^{
            id result = [self->realDictionary objectForKey:aKey];
            //    Before unlocking, make sure this object doesn't get
            //  deallocated until the autorelease pool is released.
            // MRC: [[result retain] autorelease];
            // ARC: In order to prevent instances from being deallocated while they are still needed, property, constant or variable establish a strong reference to the instance when they are assigned an instance.
            __strong __typeof(result) strongObject = result;
            obj = strongObject;
        })
    }
    return obj;
}

#pragma mark - Primitive methods in NSMutableDictionary

- (void)removeObjectForKey:(id)aKey {
    //    While this method itself may not run into trouble, respect the
    //  lock so we don't trip up other threads.
    UNFAIR_LOCKED([realDictionary removeObjectForKey:aKey]);
}

- (void)setObject:(id)anObject forKey:(id<NSCopying>)aKey {
    @autoreleasepool {
        UNFAIR_LOCKED_BLOCK(^{
            //    Putting the object into the dictionary puts it at risk for being
            //  released by another thread, so protect it.
            // [[anObject retain] autorelease];
            
            __strong __typeof(anObject) strongObject = anObject;
            
            //    Respect the lock, because setting the object may release
            // its predecessor.
            [self->realDictionary setObject:strongObject forKey:aKey];
        })
    }
}

//    This isn't labeled as primitive, but let's optimize it.
- (instancetype)initWithCapacity:(NSUInteger)numItems {
    self = [super init];
    if (self != nil) {
        // lock = [[NSLock alloc] init];
        //  _lock = OS_SPINLOCK_INIT;
        _lock = OS_UNFAIR_LOCK_INIT;
        realDictionary = [[NSMutableDictionary alloc] initWithCapacity:numItems];
    }
    return self;
}

#pragma mark - Overrides from NSObject
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        // lock = [[NSLock alloc] init];
        //  _lock = OS_SPINLOCK_INIT;
        _lock = OS_UNFAIR_LOCK_INIT;
        realDictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

// Only for debug print
- (NSString *)description {
    NSString *desc;
    UNFAIR_LOCKED(desc = [realDictionary description]);
    return desc;
}

- (NSString *)debugDescription {
    NSString *debugDesc;
    UNFAIR_LOCKED(debugDesc = [realDictionary debugDescription]);
    return debugDesc;
}

#pragma mark - Dealloc
/*
 The suffix mm means you are using C++ code and Objective-C code. Although Objective-C is a superset op C, the compiler will allow it. But you have to keep in mind that C++ is not a superset of C. The same rules don't apply.

 While C allows you to do implicit casts from  void * to an other data type, C++ requires you to do an explicit cast.

 E.g.:

 char *a;
 void *b;

 a = b; // allowed in C, not in C++
 a = (char *)b; // allowed in C, required in C++
 */
- (void)dealloc {
    // MRC:
    // [realDictionary release];
    // [lock release];
    // [super dealloc];
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
}

@end
