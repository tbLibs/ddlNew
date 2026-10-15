//
//  EncryptManager.h
//  EncryptLib
//
//  Created by 庞海亮 on 2025/9/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, EncryptDataType) {
    /// AES加解密
    EncryptDataTypeAES = 0,
    /// XOR加解密
    EncryptDataTypeXOR = 1,
    /// 不处理
    EncryptDataTypeNOT = 2
};

@interface EncryptManager : NSObject

/// 单例
+ (instancetype)shareEncryManager;

/// 设置的加密方式(必须配置，不然不知道那种加解密方式)
@property (nonatomic, assign) EncryptDataType encryptType;

/// 文件解密
/// - Parameters:
///   - data: 解密的文件数据
-(NSData *)decrypt:(NSData *)data;

/// 文件加密
/// - Parameters:
///   - plainData: 文件数据
- (NSData *)encryptFileToData:(NSData *)plainData;

@end

NS_ASSUME_NONNULL_END
