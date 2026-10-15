//
//  XorEncryptManager.m
//  EncryptLib
//
//  Created by 庞海亮 on 2025/9/10.
//

#import "XorEncryptManager.h"

#define kXOR_LENGTH 3
#define kENCRYPT_DATA_LENGTH 128
#define kKEY_DATA_LENGTH 256

@implementation XorEncryptManager

// 异或加密
- (NSData *)xorEncrypt:(NSData *)data {
    if (!data || data.length == 0) {
        return data;
    }
    
    @try {
        BOOL isExist = [self xorIsExist:data];
        if (isExist) {
            NSLog(@"数据已经加密，直接返回");
            return data;
        }
        
        // 数据源长度
        NSUInteger dataLength = data.length;
        if (dataLength < kKEY_DATA_LENGTH) {
            NSLog(@"数据长度不足，无法加密");
            return data.copy;
        }
        
        // 需要加密的数据 长度128
        NSData *toEncryptData = [data subdataWithRange:NSMakeRange(0, kENCRYPT_DATA_LENGTH)];
        
        // 未做加密的数据（中间部分）
        NSData *originData = [data subdataWithRange:NSMakeRange(kENCRYPT_DATA_LENGTH, dataLength - kENCRYPT_DATA_LENGTH)];
        
        // 取出数据最后256的长度作为加密串
        NSData *privateKeyData = [data subdataWithRange:NSMakeRange(dataLength - kKEY_DATA_LENGTH, kKEY_DATA_LENGTH)];
        
        // 加密前128字节
        NSMutableData *encryptedData = [self xorHandle:toEncryptData keyData:privateKeyData];
        if (!encryptedData) {
            NSLog(@"加密数据处理失败");
            return data;
        }
        
        // 组合加密后的数据
        if (originData && originData.length > 0) {
            [encryptedData appendData:originData];
        }
        
        // 加上xor标识的三个字节
        NSData *xorData = [self xorData];
        NSMutableData *resultData = [[NSMutableData alloc] initWithData:xorData];
        [resultData appendData:encryptedData];
        
        return resultData.copy;
        
    } @catch (NSException *exception) {
        NSLog(@"异或加密异常：%@", exception.reason);
        return data; // 发生异常时返回原始数据
    }
}

// 异或解密
- (NSData *)xorDecrypt:(NSData *)data {
    if (!data || data.length == 0) {
        return data;
    }
    
    @try {
        BOOL isExist = [self xorIsExist:data];
        if (!isExist) {
            return data;
        }
        
        NSUInteger dataLength = data.length;
        if (dataLength < kKEY_DATA_LENGTH) {
            NSLog(@"数据长度不足，无法解密");
            return data.copy;
        }
        
        NSData * noneData = [data subdataWithRange:NSMakeRange(kXOR_LENGTH, kENCRYPT_DATA_LENGTH)];
        //未做加密的数据
        NSData * originData = [data subdataWithRange:NSMakeRange(kXOR_LENGTH + kENCRYPT_DATA_LENGTH, dataLength - kENCRYPT_DATA_LENGTH - kXOR_LENGTH)];
        //取出数据最后256的长度作为加密串
        NSData *privateKeyData = [data subdataWithRange:NSMakeRange(dataLength - kKEY_DATA_LENGTH, kKEY_DATA_LENGTH)];
        NSMutableData *decryptedData = [self xorHandle:noneData keyData:privateKeyData];
        [decryptedData appendData:originData];
        return decryptedData;
    } @catch (NSException *exception) {
        NSLog(@"异或解密异常：%@", exception.reason);
        return data; // 发生异常时返回原始数据
    }
}

// 判断是否有异或加密标识
- (BOOL)xorIsExist:(NSData *)data {
    if (!data || data.length < kXOR_LENGTH) {
        return NO;
    }
    
    @try {
        const Byte *bytes = (const Byte *)[data bytes];
        if (!bytes) {
            return NO;
        }
        
        NSData *xorData = [[NSData alloc] initWithBytes:bytes length:kXOR_LENGTH];
        if (!xorData) {
            return NO;
        }
        
        NSString *xorString = [[NSString alloc] initWithData:xorData encoding:NSUTF8StringEncoding];
        if (!xorString) {
            return NO;
        }
        
        return [xorString isEqualToString:kXOR];
        
    } @catch (NSException *exception) {
        NSLog(@"检查异或标识异常：%@", exception.reason);
        return NO;
    }
}

// 加密标识符
- (NSData *)xorData {
    return [kXOR dataUsingEncoding:NSUTF8StringEncoding];
}

// 异或加密实现
- (NSMutableData *)xorHandle:(NSData *)cryptData keyData:(NSData *)privateKeyData {
    if (!cryptData || !privateKeyData || privateKeyData.length == 0) {
        return [NSMutableData data];
    }
    
    @try {
        const char *cKey = (const char *)[privateKeyData bytes];
        if (!cKey) {
            NSLog(@"密钥数据指针为空");
            return [NSMutableData data];
        }
        
        // 关键修改：使用固定长度256，与解密逻辑保持一致
        int length = (int)kKEY_DATA_LENGTH;
        
        // 数据初始化，空间未分配 配合使用 appendBytes
        NSMutableData *encryptData = [[NSMutableData alloc] initWithCapacity:kKEY_DATA_LENGTH];
        if (!encryptData) {
            NSLog(@"内存分配失败");
            return [NSMutableData data];
        }
        
        // 获取字节指针
        const Byte *point = (const Byte *)[cryptData bytes];
        if (!point) {
            NSLog(@"数据指针为空");
            return [NSMutableData data];
        }
        
        for (NSUInteger i = 0; i < cryptData.length; i++) {
            // 关键修改：使用固定模256，与解密逻辑保持一致
            int l = i % length;
            char c = cKey[l];
            // 异或运算
            Byte b = (Byte)(point[i] ^ c);
            // 追加字节
            [encryptData appendBytes:&b length:1];
        }
        return encryptData;
        
    } @catch (NSException *exception) {
        NSLog(@"异或处理异常：%@", exception.reason);
        return [NSMutableData data];
    }
}

/// 文件xor加密
/// - Parameter fileData: 需要加密的文件数据
- (NSData *)encryptFileToData:(NSData *)fileData {
    @try {
        // 参数验证
        if (!fileData) {
            NSLog(@"文件数据为空");
            return nil;
        }
        
        if (fileData.length == 0) {
            NSLog(@"文件数据长度为0");
            return nil;
        }
        
        NSMutableData *resultData = [NSMutableData data];
        NSUInteger fileSize = fileData.length;
        
        if (fileSize < kKEY_DATA_LENGTH) {
            // 如果文件小于256字节，直接返回原数据
            NSLog(@"文件大小小于最小加密长度，直接返回原数据");
            return nil;
        }
        
        // 前128字节需要加密
        NSRange encryRange = NSMakeRange(0, kENCRYPT_DATA_LENGTH);
        NSData *encryData = [fileData subdataWithRange:encryRange];
        if (!encryData || encryData.length != kENCRYPT_DATA_LENGTH) {
            NSLog(@"提取前128字节失败");
            return nil;
        }
        
        // 中间部分（未加密）
        NSUInteger originOffset = kENCRYPT_DATA_LENGTH;
        NSUInteger originLength = fileSize > kKEY_DATA_LENGTH ? fileSize - kKEY_DATA_LENGTH - kENCRYPT_DATA_LENGTH : 0;
        
        // 最后256字节作为加密密钥
        NSRange keyRange = NSMakeRange(fileSize - kKEY_DATA_LENGTH, kKEY_DATA_LENGTH);
        NSData *privateKeyData = [fileData subdataWithRange:keyRange];
        if (!privateKeyData || privateKeyData.length != kKEY_DATA_LENGTH) {
            NSLog(@"提取密钥数据失败");
            return nil;
        }
        
        // 加密前128字节
        NSMutableData *encryptData = [self otherXorHandle:encryData keyData:privateKeyData];
        if (!encryptData || encryptData.length == 0) {
            NSLog(@"前128字节加密失败");
            return nil;
        }
        
        // 添加xor标识
        NSData *xorData = [self xorData];
        [resultData appendData:xorData];
        
        // 添加加密后的前128字节
        [resultData appendData:encryptData];
        
        // 添加中间未加密的数据
        if (originLength > 0) {
            NSRange middleRange = NSMakeRange(originOffset, originLength);
            NSData *middleData = [fileData subdataWithRange:middleRange];
            if (middleData) {
                [resultData appendData:middleData];
            }
        }
        
        // 添加最后256字节（加密密钥）
        [resultData appendData:privateKeyData];
        
        return resultData.copy;
        
    } @catch (NSException *exception) {
        NSLog(@"文件加密异常：%@", exception.reason);
        return nil;
    }
}

// 异或处理方法
- (NSMutableData *)otherXorHandle:(NSData *)data keyData:(NSData *)keyData {
    if (!data || !keyData || keyData.length == 0) {
        return [NSMutableData data];
    }
    
    @try {
        NSMutableData *result = [NSMutableData dataWithLength:data.length];
        if (!result) {
            NSLog(@"内存分配失败");
            return [NSMutableData data];
        }
        
        const char *dataBytes = (const char *)data.bytes;
        const char *keyBytes = (const char *)keyData.bytes;
        char *resultBytes = (char *)result.mutableBytes;
        
        if (!dataBytes || !keyBytes || !resultBytes) {
            NSLog(@"数据指针为空");
            return [NSMutableData data];
        }
        
        // 关键修改：使用固定长度256，与解密逻辑保持一致
        int length = (int)kKEY_DATA_LENGTH;
        
        for (NSUInteger i = 0; i < data.length; i++) {
            // 关键修改：使用固定模256，与解密逻辑保持一致
            int l = i % length;
            resultBytes[i] = dataBytes[i] ^ keyBytes[l];
        }
        return result;
        
    } @catch (NSException *exception) {
        NSLog(@"异或处理异常：%@", exception.reason);
        return [NSMutableData data];
    }
}

/// 验证加密解密是否正确
/// - Parameter originalData: 原始数据
/// - Returns: 验证结果
- (BOOL)verifyEncryptDecrypt:(NSData *)originalData {
    if (!originalData || originalData.length < kKEY_DATA_LENGTH) {
        NSLog(@"验证失败：数据为空或长度不足");
        return NO;
    }
    
    @try {
        // 1. 加密原始数据
        NSData *encryptedData = [self xorEncrypt:originalData];
        if (!encryptedData) {
            NSLog(@"验证失败：加密失败");
            return NO;
        }
        
        // 2. 检查是否包含XOR标识
        BOOL hasXorFlag = [self xorIsExist:encryptedData];
        if (!hasXorFlag) {
            NSLog(@"验证失败：加密后数据缺少XOR标识");
            return NO;
        }
        
        // 3. 解密数据
        NSData *decryptedData = [self xorDecrypt:encryptedData];
        if (!decryptedData) {
            NSLog(@"验证失败：解密失败");
            return NO;
        }
        
        // 4. 比较原始数据和解密后数据
        BOOL isEqual = [originalData isEqualToData:decryptedData];
        if (!isEqual) {
            NSLog(@"验证失败：解密后数据与原始数据不一致");
            NSLog(@"原始数据长度: %lu", (unsigned long)originalData.length);
            NSLog(@"解密数据长度: %lu", (unsigned long)decryptedData.length);
            
            // 输出前几个字节进行对比
            if (originalData.length > 0 && decryptedData.length > 0) {
                const uint8_t *originalBytes = (const uint8_t *)originalData.bytes;
                const uint8_t *decryptedBytes = (const uint8_t *)decryptedData.bytes;
                NSInteger compareLength = MIN(originalData.length, decryptedData.length);
                NSInteger compareLength2 = MIN(compareLength, 16); // 只比较前16字节
                
                NSLog(@"前%d字节对比:", (int)compareLength2);
                for (NSInteger i = 0; i < compareLength2; i++) {
                    if (originalBytes[i] != decryptedBytes[i]) {
                        NSLog(@"字节[%ld]: 原始=0x%02X, 解密=0x%02X", (long)i, originalBytes[i], decryptedBytes[i]);
                    }
                }
            }
            return NO;
        }
        
        NSLog(@"验证成功：加密解密数据一致");
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"验证异常：%@", exception.reason);
        return NO;
    }
}

@end
