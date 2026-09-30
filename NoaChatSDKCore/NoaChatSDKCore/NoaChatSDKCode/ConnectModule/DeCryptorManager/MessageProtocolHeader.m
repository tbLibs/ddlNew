//
//  MessageProtocolHeader.m
//  NoaChatSDKCore
//
//  ZIM消息协议头
//  Created by IM Team
//

#import "MessageProtocolHeader.h"
// 宏定义
#import "LingIMMacorHeader.h"

// 协议头总长度（字节）
enum { PROTOCOL_HEADER_LENGTH = 12 };

// 协议魔数："ZIMA" (0x5A494D41)
static const int PROTOCOL_MAGIC = 0x5A494D41;

// 协议版本号
static const uint8_t PROTOCOL_VERSION = 0x01;

// 标志位定义
static const uint8_t FLAG_AES_ENCRYPTED = 0x01;  // bit 0: AES加密
static const uint8_t FLAG_COMPRESSED = 0x02;     // bit 1: 压缩 (预留)

// 最大消息长度限制 (10MB)
static const NSInteger MAX_MESSAGE_LENGTH = 10 * 1024 * 1024;

@interface MessageProtocolHeader ()

// 私有属性
@property (nonatomic, assign) int magic;
@property (nonatomic, assign) uint8_t version;
@property (nonatomic, assign) uint8_t flags;
@property (nonatomic, assign) uint16_t reserved;
@property (nonatomic, assign) NSInteger totalLength;
@property (nonatomic, assign) NSInteger messageBodyLength;

@end

@implementation MessageProtocolHeader

#pragma mark - 类属性

+ (NSInteger)protocolHeaderLength {
    return PROTOCOL_HEADER_LENGTH;
}

#pragma mark - 实例属性

- (NSInteger)messageBodyLength {
    return _messageBodyLength;
}

- (NSInteger)totalLength {
    return _totalLength;
}

- (BOOL)isAesEncrypted {
    return (_flags & FLAG_AES_ENCRYPTED) != 0;
}

- (BOOL)isCompressed {
    return (_flags & FLAG_COMPRESSED) != 0;
}

- (BOOL)isValid {
    return _magic == PROTOCOL_MAGIC &&
           _version == PROTOCOL_VERSION &&
           _totalLength >= PROTOCOL_HEADER_LENGTH &&
           _totalLength <= MAX_MESSAGE_LENGTH;
}

#pragma mark - 工厂方法

+ (instancetype)createEncryptedHeader:(NSInteger)messageLength {
    MessageProtocolHeader *header = [[MessageProtocolHeader alloc] init];
    header->_magic = PROTOCOL_MAGIC;
    header->_version = PROTOCOL_VERSION;
    header->_flags = FLAG_AES_ENCRYPTED;
    header->_reserved = 0;
    header->_totalLength = PROTOCOL_HEADER_LENGTH + messageLength;
    header->_messageBodyLength = messageLength;
    return header;
}

+ (instancetype)createPlaintextHeader:(NSInteger)messageLength {
    MessageProtocolHeader *header = [[MessageProtocolHeader alloc] init];
    header->_magic = PROTOCOL_MAGIC;
    header->_version = PROTOCOL_VERSION;
    header->_flags = 0;
    header->_reserved = 0;
    header->_totalLength = PROTOCOL_HEADER_LENGTH + messageLength;
    header->_messageBodyLength = messageLength;
    return header;
}

+ (instancetype _Nullable)readFromData:(NSData *)data {
    NSInteger offset = 0;
    return [self readFromData:data offset:&offset];
}

+ (instancetype _Nullable)readFromData:(NSData *)data offset:(NSInteger *)offset {
    if (!data || !offset) {
        CIMLog(@"❌ 输入参数无效");
        return nil;
    }
    
    if (data.length < PROTOCOL_HEADER_LENGTH) {
        CIMLog(@"❌ 数据长度不足，需要: %ld字节，实际: %lu字节", (long)PROTOCOL_HEADER_LENGTH, (unsigned long)data.length);
        return nil;
    }
    
    const uint8_t *bytes = data.bytes;
    NSInteger currentOffset = *offset;
    
    // 检查偏移量
    if (currentOffset + PROTOCOL_HEADER_LENGTH > data.length) {
        CIMLog(@"❌ 偏移量超出数据范围");
        return nil;
    }
    
    @try {
        // 读取魔数 (4字节)
        int magic = (bytes[currentOffset] << 24) | 
                   (bytes[currentOffset + 1] << 16) | 
                   (bytes[currentOffset + 2] << 8) | 
                   bytes[currentOffset + 3];
        currentOffset += 4;
        
        // 读取版本号 (1字节)
        uint8_t version = bytes[currentOffset];
        currentOffset += 1;
        
        // 读取标志位 (1字节)
        uint8_t flags = bytes[currentOffset];
        currentOffset += 1;
        
        // 读取预留字段 (2字节)
        uint16_t reserved = (bytes[currentOffset] << 8) | bytes[currentOffset + 1];
        currentOffset += 2;
        
        // 读取消息总长度 (4字节)
        int totalLength = (bytes[currentOffset] << 24) | 
                         (bytes[currentOffset + 1] << 16) | 
                         (bytes[currentOffset + 2] << 8) | 
                         bytes[currentOffset + 3];
        currentOffset += 4;
        
        // 验证协议头
        if (![self validateProtocolHeader:magic version:version totalLength:totalLength]) {
            return nil;
        }
        
        MessageProtocolHeader *header = [[MessageProtocolHeader alloc] init];
        header->_magic = magic;
        header->_version = version;
        header->_flags = flags;
        header->_reserved = reserved;
        header->_totalLength = totalLength;
        header->_messageBodyLength = totalLength - PROTOCOL_HEADER_LENGTH;
        
        // 更新偏移量
        *offset = currentOffset;
        
        return header;
        
    } @catch (NSException *exception) {
        CIMLog(@"❌ 协议头解析异常: %@", exception.reason);
        return nil;
    }
}

+ (instancetype _Nullable)fromByteArray:(NSData *)bytes {
    if (!bytes || bytes.length < PROTOCOL_HEADER_LENGTH) {
        CIMLog(@"❌ 协议头数据不足");
        return nil;
    }
    
    const uint8_t *data = bytes.bytes;
    NSInteger offset = 0;
    
    @try {
        // 读取魔数
        int magic = ((data[offset] & 0xFF) << 24) |
                   ((data[offset + 1] & 0xFF) << 16) |
                   ((data[offset + 2] & 0xFF) << 8) |
                   (data[offset + 3] & 0xFF);
        offset += 4;
        
        // 读取版本号
        uint8_t version = data[offset++];
        
        // 读取标志位
        uint8_t flags = data[offset++];
        
        // 读取预留字段
        uint16_t reserved = (uint16_t)(((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF));
        offset += 2;
        
        // 读取总长度
        int totalLength = ((data[offset] & 0xFF) << 24) |
                         ((data[offset + 1] & 0xFF) << 16) |
                         ((data[offset + 2] & 0xFF) << 8) |
                         (data[offset + 3] & 0xFF);
        
        // 验证协议头
        if (![self validateProtocolHeader:magic version:version totalLength:totalLength]) {
            return nil;
        }
        
        MessageProtocolHeader *header = [[MessageProtocolHeader alloc] init];
        header->_magic = magic;
        header->_version = version;
        header->_flags = flags;
        header->_reserved = reserved;
        header->_totalLength = totalLength;
        header->_messageBodyLength = totalLength - PROTOCOL_HEADER_LENGTH;
        
        return header;
        
    } @catch (NSException *exception) {
        CIMLog(@"❌ 协议头解析异常: %@", exception.reason);
        return nil;
    }
}

#pragma mark - 序列化方法

- (void)writeToData:(NSMutableData *)data {
    if (!data) {
        CIMLog(@"❌ 输出缓冲区为空");
        return;
    }
    
    // 手动按字节写入，确保Big-Endian字节序
    uint8_t bytes[PROTOCOL_HEADER_LENGTH];
    int offset = 0;
    
    // Magic (4字节，Big-Endian)
    bytes[offset++] = (uint8_t)((_magic >> 24) & 0xFF);
    bytes[offset++] = (uint8_t)((_magic >> 16) & 0xFF);
    bytes[offset++] = (uint8_t)((_magic >> 8) & 0xFF);
    bytes[offset++] = (uint8_t)(_magic & 0xFF);
    
    // Version (1字节)
    bytes[offset++] = _version;
    
    // Flags (1字节)
    bytes[offset++] = _flags;
    
    // Reserved (2字节，Big-Endian)
    bytes[offset++] = (uint8_t)((_reserved >> 8) & 0xFF);
    bytes[offset++] = (uint8_t)(_reserved & 0xFF);
    
    // Total Length (4字节，Big-Endian)
    bytes[offset++] = (uint8_t)((_totalLength >> 24) & 0xFF);
    bytes[offset++] = (uint8_t)((_totalLength >> 16) & 0xFF);
    bytes[offset++] = (uint8_t)((_totalLength >> 8) & 0xFF);
    bytes[offset] = (uint8_t)(_totalLength & 0xFF);
    
    [data appendBytes:bytes length:PROTOCOL_HEADER_LENGTH];
    
    CIMLog(@"📋 写入协议头: Magic=0x%08X, Version=%d, Flags=0x%02X, Length=%ld", 
           _magic, _version, _flags, (long)_totalLength);
}

- (NSData *)toByteArray {
    // 直接创建字节数组，确保Big-Endian字节序
    uint8_t bytes[PROTOCOL_HEADER_LENGTH];
    int offset = 0;
    
    // Magic (4字节，Big-Endian)
    bytes[offset++] = (uint8_t)((_magic >> 24) & 0xFF);
    bytes[offset++] = (uint8_t)((_magic >> 16) & 0xFF);
    bytes[offset++] = (uint8_t)((_magic >> 8) & 0xFF);
    bytes[offset++] = (uint8_t)(_magic & 0xFF);
    
    // Version (1字节)
    bytes[offset++] = _version;
    
    // Flags (1字节)
    bytes[offset++] = _flags;
    
    // Reserved (2字节，Big-Endian)
    bytes[offset++] = (uint8_t)((_reserved >> 8) & 0xFF);
    bytes[offset++] = (uint8_t)(_reserved & 0xFF);
    
    // Total Length (4字节，Big-Endian)
    bytes[offset++] = (uint8_t)((_totalLength >> 24) & 0xFF);
    bytes[offset++] = (uint8_t)((_totalLength >> 16) & 0xFF);
    bytes[offset++] = (uint8_t)((_totalLength >> 8) & 0xFF);
    bytes[offset] = (uint8_t)(_totalLength & 0xFF);
    
    return [NSData dataWithBytes:bytes length:PROTOCOL_HEADER_LENGTH];
}

#pragma mark - 验证方法

+ (BOOL)validateProtocolHeader:(int)magic version:(uint8_t)version totalLength:(int)totalLength {
    if (magic != PROTOCOL_MAGIC) {
        CIMLog(@"❌ 无效的协议魔数: 0x%08X，期望: 0x%08X", magic, PROTOCOL_MAGIC);
        return NO;
    }
    
    if (version != PROTOCOL_VERSION) {
        CIMLog(@"❌ 不支持的协议版本: %d，支持版本: %d", version, PROTOCOL_VERSION);
        return NO;
    }
    
    if (totalLength < PROTOCOL_HEADER_LENGTH) {
        CIMLog(@"❌ 无效的消息长度: %d，最小长度: %ld", totalLength, (long)PROTOCOL_HEADER_LENGTH);
        return NO;
    }
    
    if (totalLength > MAX_MESSAGE_LENGTH) {
        CIMLog(@"❌ 消息长度过大: %d，最大限制: %ld", totalLength, (long)MAX_MESSAGE_LENGTH);
        return NO;
    }
    
    return YES;
}

#pragma mark - 描述方法

- (NSString *)description {
    return [NSString stringWithFormat:@"ProtocolHeader{Magic=0x%08X, Version=%d, Flags=0x%02X(AES:%@), Length=%ld}",
            _magic, _version, _flags, self.isAesEncrypted ? @"是" : @"否", (long)_totalLength];
}

@end
