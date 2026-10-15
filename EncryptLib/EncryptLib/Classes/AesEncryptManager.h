//
//  AesEncryptManager.h
//  EncryptLib
//
//  Created by phl on 2025/9/11.
//

#import <Foundation/Foundation.h>
#define kAES @"AES"

NS_ASSUME_NONNULL_BEGIN

@interface AesEncryptManager : NSObject

/// AES解密
/// - Parameter data: 需要aes解密的数据
-(NSData*)aesDecrypt:(NSData*)data;

/// 文件Aes加密
/// - Parameters:
///   - plainData: 文件数据
///   - error: 错误
- (NSData *)encryptFileToData:(NSData *)plainData;

@end

NS_ASSUME_NONNULL_END
