//
//  EncryptManager.m
//  EncryptLib
//
//  Created by 庞海亮 on 2025/9/10.
//

#import "EncryptManager.h"
#import "XorEncryptManager.h"
#import "AesEncryptManager.h"

@interface EncryptManager ()

@property (nonatomic, strong) XorEncryptManager *xorEncryptManager;

@property (nonatomic, strong) AesEncryptManager *aesEncryptManager;

@end

@implementation EncryptManager

- (XorEncryptManager *)xorEncryptManager {
    if (!_xorEncryptManager) {
        _xorEncryptManager = [XorEncryptManager new];
    }
    return _xorEncryptManager;
}

- (AesEncryptManager *)aesEncryptManager {
    if (!_aesEncryptManager) {
        _aesEncryptManager = [AesEncryptManager new];
    }
    return _aesEncryptManager;
}

static dispatch_once_t onceToken;

/// 单例
+ (instancetype)shareEncryManager{
    static EncryptManager *_manager = nil;
    dispatch_once(&onceToken, ^{
        //不能再使用alloc方法
        //因为已经重写了allocWithZone方法，所以这里要调用父类的分配空间的方法
        _manager = [[super allocWithZone:NULL] init];
    });
    return _manager;
}

/// 防止外部调用alloc 或者 new
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [EncryptManager shareEncryManager];
}

/// 防止外部调用copy
- (id)copyWithZone:(nullable NSZone *)zone {
    return [EncryptManager shareEncryManager];
}

/// 防止外部调用mutableCopy
- (id)mutableCopyWithZone:(nullable NSZone *)zone {
    return [EncryptManager shareEncryManager];
}

- (NSData *)decrypt:(NSData *)data {
    EncryptDataType dataType = [self encryptTypeIsExist:data];
    if (dataType == EncryptDataTypeAES) {
        return [self.aesEncryptManager aesDecrypt:data];
    }else if (dataType == EncryptDataTypeXOR) {
        return [self.xorEncryptManager xorDecrypt:data];
    }else {
        return data;
    }
}

- (NSData *)encryptFileToData:(NSData *)plainData {
    if (self.encryptType == EncryptDataTypeAES) {
        return [self.aesEncryptManager encryptFileToData:plainData];
    }else if (self.encryptType == EncryptDataTypeXOR) {
        return [self.xorEncryptManager encryptFileToData:plainData];
    }else {
        return plainData;
    }
}

-(EncryptDataType)encryptTypeIsExist:(NSData*)data {
    if (!data || data.length < 3) {
        return EncryptDataTypeNOT;
    }
    
    const Byte *bytes = (const Byte *)[data bytes];
    if (!bytes) {
        return EncryptDataTypeNOT;
    }
    
    NSData *encryptData = [[NSData alloc] initWithBytes:bytes length:3];
    if (!encryptData) {
        return EncryptDataTypeNOT;
    }
    
    NSString *encryptString = [[NSString alloc] initWithData:encryptData encoding:NSUTF8StringEncoding];
    if ([encryptString isEqualToString:kXOR]) {
        return EncryptDataTypeXOR;
    } else if ([encryptString isEqualToString:kAES]){
        return EncryptDataTypeAES;
    } else {
        return EncryptDataTypeNOT;
    }
}


@end
