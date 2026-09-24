//
//  MessageProtocolHeader.h
//  NoaChatSDKCore
//
//  ZIM消息协议头
//  Created by IM Team
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ZIM消息协议头处理类
 * 
 * 定义和处理ZIM协议的消息头部结构，用于标识消息类型和处理方式
 * 
 * 协议头格式 (12字节):
 * +--------+--------+-------+----------+-------------+
 * | Magic  |Version | Flags | Reserved | Length      |
 * | 4字节  | 1字节  | 1字节 | 2字节    | 4字节       |
 * +--------+--------+-------+----------+-------------+
 * | ZIMA   |  0x01  |   ?   | 0x0000   | 消息总长度   |
 * +--------+--------+-------+----------+-------------+
 * 
 * 字段说明:
 * - Magic (4字节): 协议标识符 "ZIMA" (0x5A494D41)
 * - Version (1字节): 协议版本号，当前为 0x01
 * - Flags (1字节): 消息标志位
 *   - bit 0: AES加密标志 (1=加密, 0=明文)
 *   - bit 1: 压缩标志 (预留)
 *   - bit 2-7: 预留位
 * - Reserved (2字节): 预留字段，填充0x0000
 * - Length (4字节): 整个消息的总长度（包含协议头）
 */
@interface MessageProtocolHeader : NSObject

/**
 * 协议头长度（字节）
 */
@property (class, nonatomic, readonly) NSInteger protocolHeaderLength;

/**
 * 消息体长度
 */
@property (nonatomic, assign, readonly) NSInteger messageBodyLength;

/**
 * 总长度
 */
@property (nonatomic, assign, readonly) NSInteger totalLength;

/**
 * 是否为AES加密消息
 */
@property (nonatomic, assign, readonly) BOOL isAesEncrypted;

/**
 * 是否为压缩消息（预留）
 */
@property (nonatomic, assign, readonly) BOOL isCompressed;

/**
 * 检查协议头是否有效
 */
@property (nonatomic, assign, readonly) BOOL isValid;

#pragma mark - 工厂方法

/**
 * 创建AES加密消息的协议头
 *
 * @param messageLength 消息体长度（不包含协议头）
 * @return 协议头对象
 */
+ (instancetype)createEncryptedHeader:(NSInteger)messageLength;

/**
 * 创建明文消息的协议头
 *
 * @param messageLength 消息体长度（不包含协议头）
 * @return 协议头对象
 */
+ (instancetype)createPlaintextHeader:(NSInteger)messageLength;

/**
 * 从数据中读取协议头
 * 
 * @param data 输入数据
 * @return 协议头对象，失败返回nil
 */
+ (instancetype _Nullable)readFromData:(NSData *)data;

/**
 * 从数据流中读取协议头
 * 
 * @param data 输入数据
 * @param offset 偏移量（会被更新）
 * @return 协议头对象，失败返回nil
 */
+ (instancetype _Nullable)readFromData:(NSData *)data offset:(NSInteger *)offset;

/**
 * 从字节数组创建协议头
 *
 * @param bytes 字节数组
 * @return 协议头对象，失败返回nil
 */
+ (instancetype _Nullable)fromByteArray:(NSData *)bytes;

#pragma mark - 序列化方法

/**
 * 将协议头写入NSMutableData
 *
 * @param data 输出缓冲区
 */
- (void)writeToData:(NSMutableData *)data;

/**
 * 转换为字节数组
 *
 * @return 协议头字节数组
 */
- (NSData *)toByteArray;

/**
 * 描述信息
 */
- (NSString *)description;

@end

NS_ASSUME_NONNULL_END
