//
//  LingIMMacorHeader.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/9/6.
//

// 宏定义

#ifndef LingIMMacorHeader_h
#define LingIMMacorHeader_h


#ifdef DEBUG
#define CIMLog(fmt, ...) { \
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; \
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"]; \
    NSString *timestamp = [formatter stringFromDate:[NSDate date]]; \
    NSLog((@"[%@] %s [Line %d] " fmt), timestamp, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
}
#else
#define CIMLog(...)
#endif

#define CIMWeakSelf __weak typeof(self) weakSelf = self;
#define CIMStrongSelf __strong typeof(weakSelf) strongSelf = weakSelf;

#endif /* LingIMMacorHeader_h */
