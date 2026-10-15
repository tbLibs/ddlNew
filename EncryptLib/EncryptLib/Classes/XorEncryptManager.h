//
//  XorEncryptManager.h
//  EncryptLib
//
//  Created by 庞海亮 on 2025/9/10.
//

#import <Foundation/Foundation.h>
#define kXOR @"XOR"

NS_ASSUME_NONNULL_BEGIN

@interface XorEncryptManager : NSObject

/// 异或加密
/// - Parameter data: 需要异或加密的数据
- (NSData *)xorEncrypt:(NSData *)data;

/// 异或解密
/// - Parameter data: 需要异或解密的数据
- (NSData *)xorDecrypt:(NSData *)data;

/// 检查是否存在xor加密标识
/// - Parameter data: 需要检查的数据
- (BOOL)xorIsExist:(NSData *)data;

/// 文件xor加密
/// - Parameter fileData: 需要加密的文件数据
- (NSData *)encryptFileToData:(NSData *)fileData;

/// 验证加密解密是否正确
/// - Parameter originalData: 原始数据
/// - Returns: 验证结果
- (BOOL)verifyEncryptDecrypt:(NSData *)originalData;

@end

NS_ASSUME_NONNULL_END
