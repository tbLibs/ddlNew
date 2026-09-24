//
//  ECDHClientProtocolHandler.m
//  NoaChatSDKCore
//
//  客户端 ECDH 协议处理器实现
//  对应服务端 ECDHProtocolHandler.java 的客户端实现
//  Created by IM Team
//

#import "ECDHClientProtocolHandler.h"
#import <CommonCrypto/CommonHMAC.h>
#import "LingIMMacorHeader.h"

// 协议消息类型 - 与服务端保持一致
static const uint8_t ECDH_KEY_EXCHANGE_REQUEST = 0x10;
static const uint8_t ECDH_KEY_EXCHANGE_RESPONSE = 0x11;
static const uint8_t ECDH_KEY_EXCHANGE_ERROR = 0x12;
static const uint8_t ECDH_SESSION_KEY_DERIVED = 0x13;

// 协议版本
static const uint8_t PROTOCOL_VERSION = 0x01;

// 消息头长度
static const NSInteger HEADER_LENGTH = 8; // version(1) + type(1) + length(4) + reserved(2)

// HKDF 相关常量
static NSString * const HKDF_SALT = @"ECDH_IM_CLIENT_SALT_2024";
static const NSInteger HASH_LENGTH = 32; // SHA-256 输出长度

// 错误域
static NSString * const ECDHClientProtocolErrorDomain = @"ECDHClientProtocolError";

@interface ECDHClientProtocolHandler ()

@property (nonatomic, readwrite) SecKeyRef clientPublicKey;
@property (nonatomic, readwrite) SecKeyRef clientPrivateKey;
@property (nonatomic, readwrite) NSData *sharedSecret;
@property (nonatomic, readwrite) NSData *sessionKey;
@property (nonatomic, readwrite) BOOL isKeyExchangeCompleted;

@end

@implementation ECDHClientProtocolHandler

#pragma mark - 生命周期

- (instancetype)initWithDelegate:(id<ECDHClientProtocolHandlerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _isKeyExchangeCompleted = NO;
        _clientPublicKey = NULL;
        _clientPrivateKey = NULL;
        _sharedSecret = nil;
        _sessionKey = nil;
    }
    return self;
}

- (void)dealloc {
    [self reset];
}

#pragma mark - 公共方法

/**
 * 启动 ECDH 密钥交换流程
 */
- (void)initiateKeyExchange {
    CIMLog(@"🚀 [ECDH客户端] 启动密钥交换流程...");
    
    [self notifyStatusUpdate:@"正在生成客户端密钥对..."];
    
    // 异步生成密钥对
    __weak typeof(self) weakSelf = self;
    [ECDHKeyManager generateKeyPairWithCompletion:^(SecKeyRef publicKey, SecKeyRef privateKey, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        
        if (error || !publicKey || !privateKey) {
            NSString *errorMsg = [NSString stringWithFormat:@"客户端密钥对生成失败: %@", error.localizedDescription];
            CIMLog(@"❌ [ECDH客户端] %@", errorMsg);
            [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                       code:-1 
                                                description:errorMsg]];
            return;
        }
        
        // 保存密钥对
        self.clientPublicKey = publicKey;
        CFRetain(self.clientPublicKey);
        self.clientPrivateKey = privateKey;
        CFRetain(self.clientPrivateKey);
        
        CIMLog(@"✅ [ECDH客户端] 客户端密钥对生成成功");
        [ECDHKeyManager printKeyInfo:self.clientPrivateKey label:@"客户端私钥"];
        [ECDHKeyManager printKeyInfo:self.clientPublicKey label:@"客户端公钥"];
        
        [self notifyStatusUpdate:@"密钥对生成完成，准备发送交换请求..."];
    }];
}

/**
 * 创建 ECDH 密钥交换请求数据
 */
- (NSData *)createKeyExchangeRequest {
    if (!self.clientPublicKey) {
        CIMLog(@"❌ [ECDH客户端] 客户端公钥未生成，无法创建交换请求");
        return nil;
    }
    
    // 获取客户端公钥字节数组
    NSError *error = nil;
    
    // 获取公钥的X.509 DER编码字节数组
    NSData *publicKeyBytes = [ECDHKeyManager getPublicKeyBytes:self.clientPublicKey error:&error];
    if (error || !publicKeyBytes) {
        CIMLog(@"❌ [ECDH客户端] 获取公钥字节数组失败: %@", error.localizedDescription);
        return nil;
    }
    
    CIMLog(@"📤 [ECDH客户端] 客户端公钥字节数组 (%lu字节): %@", 
           (unsigned long)publicKeyBytes.length, 
           [ECDHKeyManager hexStringFromData:publicKeyBytes]);
    
    // 创建协议消息
    NSData *requestData = [self createProtocolMessage:ECDH_KEY_EXCHANGE_REQUEST payload:publicKeyBytes];
    
    CIMLog(@"📤 [ECDH客户端] ECDH密钥交换请求创建成功，总长度: %lu字节", (unsigned long)requestData.length);
    
    return requestData;
}

/**
 * 处理服务端的 ECDH 响应数据
 */
- (BOOL)handleServerResponse:(NSData *)responseData {
    if (!responseData || responseData.length < HEADER_LENGTH) {
        CIMLog(@"❌ [ECDH客户端] 服务端响应数据无效或过短");
        [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                   code:-2 
                                            description:@"服务端响应数据无效"]];
        return NO;
    }
    
    // 解析消息头
    const uint8_t *bytes = (const uint8_t *)responseData.bytes;
    uint8_t version = bytes[0];
    uint8_t messageType = bytes[1];
    uint32_t payloadLength = OSReadBigInt32(responseData.bytes, 2);
    // bytes[6-7] 是 reserved 字段
    
    CIMLog(@"📥 [ECDH客户端] 收到服务端响应: version=%d, type=%d, length=%u", 
           version, messageType, payloadLength);
    
    // 验证协议版本
    if (version != PROTOCOL_VERSION) {
        NSString *errorMsg = [NSString stringWithFormat:@"不支持的协议版本: %d", version];
        CIMLog(@"❌ [ECDH客户端] %@", errorMsg);
        [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                   code:-3 
                                            description:errorMsg]];
        return NO;
    }
    
    // 验证载荷长度
    if (responseData.length < HEADER_LENGTH + payloadLength) {
        CIMLog(@"❌ [ECDH客户端] 响应数据长度不足: 期望%ld，实际%lu", 
               HEADER_LENGTH + payloadLength, (unsigned long)responseData.length);
        [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                   code:-4 
                                            description:@"响应数据长度不足"]];
        return NO;
    }
    
    // 提取载荷数据
    NSData *payload = [responseData subdataWithRange:NSMakeRange(HEADER_LENGTH, payloadLength)];
    
    // 根据消息类型处理
    switch (messageType) {
        case ECDH_KEY_EXCHANGE_RESPONSE:
            return [self handleKeyExchangeResponse:payload];
            
        case ECDH_KEY_EXCHANGE_ERROR:
            return [self handleKeyExchangeError:payload];
            
        default:
            CIMLog(@"⚠️ [ECDH客户端] 未知的消息类型: %d", messageType);
            [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                       code:-5 
                                                description:@"未知的消息类型"]];
            return NO;
    }
}

/**
 * 重置协议处理器状态
 */
- (void)reset {
    CIMLog(@"🔄 [ECDH客户端] 重置协议处理器状态");
    
    if (_clientPublicKey) {
        CFRelease(_clientPublicKey);
        _clientPublicKey = NULL;
    }
    
    if (_clientPrivateKey) {
        CFRelease(_clientPrivateKey);
        _clientPrivateKey = NULL;
    }
    
    _sharedSecret = nil;
    _sessionKey = nil;
    _isKeyExchangeCompleted = NO;
}

/**
 * 派生指定上下文的会话密钥
 */
- (NSData *)deriveSessionKeyWithContext:(NSString *)context length:(NSUInteger)length {
    if (!self.sharedSecret) {
        CIMLog(@"❌ [ECDH客户端] 共享密钥未生成，无法派生会话密钥");
        return nil;
    }
    
    CIMLog(@"🔄 [ECDH客户端] 派生会话密钥，上下文: %@，长度: %lu字节", context, (unsigned long)length);
    
    NSData *derivedKey = [self deriveKeyFromSharedSecret:self.sharedSecret 
                                                 context:context 
                                                  length:length];
    
    if (derivedKey) {
        CIMLog(@"✅ [ECDH客户端] 会话密钥派生成功: %@", [ECDHKeyManager hexStringFromData:derivedKey]);
    } else {
        CIMLog(@"❌ [ECDH客户端] 会话密钥派生失败");
    }
    
    return derivedKey;
}

#pragma mark - 私有方法

/**
 * 处理密钥交换响应
 */
- (BOOL)handleKeyExchangeResponse:(NSData *)serverPublicKeyBytes {
    CIMLog(@"🔄 [ECDH客户端] 处理服务端密钥交换响应...");
    CIMLog(@"📥 [ECDH客户端] 服务端公钥字节数组 (%lu字节): %@", 
           (unsigned long)serverPublicKeyBytes.length, 
           [ECDHKeyManager hexStringFromData:serverPublicKeyBytes]);
    
    if (!self.clientPrivateKey) {
        CIMLog(@"❌ [ECDH客户端] 客户端私钥未生成");
        [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                   code:-6 
                                            description:@"客户端私钥未生成"]];
        return NO;
    }
    
    [self notifyStatusUpdate:@"正在计算共享密钥..."];
    
    // 使用客户端私钥和服务端公钥计算共享密钥
    NSError *error = nil;
    NSData *sharedSecret = [ECDHKeyManager computeSharedSecretWithPrivateKey:self.clientPrivateKey 
                                                              publicKeyBytes:serverPublicKeyBytes 
                                                                       error:&error];
    
    if (error || !sharedSecret) {
        NSString *errorMsg = [NSString stringWithFormat:@"共享密钥计算失败: %@", error.localizedDescription];
        CIMLog(@"❌ [ECDH客户端] %@", errorMsg);
        [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                   code:-7 
                                            description:errorMsg]];
        return NO;
    }
    
    self.sharedSecret = sharedSecret;
    
    CIMLog(@"✅ [ECDH客户端] 共享密钥计算成功 (%lu字节): %@", 
           (unsigned long)sharedSecret.length, 
           [ECDHKeyManager hexStringFromData:sharedSecret]);
    
    [self notifyStatusUpdate:@"正在派生会话密钥..."];
    
    // 派生默认会话密钥
    NSData *sessionKey = [self deriveKeyFromSharedSecret:sharedSecret 
                                                 context:@"MESSAGE_ENCRYPTION" 
                                                  length:32];
    
    if (!sessionKey) {
        CIMLog(@"❌ [ECDH客户端] 会话密钥派生失败");
        [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                                   code:-8 
                                            description:@"会话密钥派生失败"]];
        return NO;
    }
    
    self.sessionKey = sessionKey;
    self.isKeyExchangeCompleted = YES;
    
    CIMLog(@"🎉 [ECDH客户端] ECDH密钥交换成功完成！");
    CIMLog(@"🔐 [ECDH客户端] 会话密钥 (%lu字节): %@", 
           (unsigned long)sessionKey.length, 
           [ECDHKeyManager hexStringFromData:sessionKey]);
    
    [self notifyStatusUpdate:@"ECDH密钥交换完成"];
    [self notifyKeyExchangeSucceeded:sharedSecret sessionKey:sessionKey];
    
    // 通知服务端会话密钥已派生
    [self sendSessionKeyDerivedNotification:@"MESSAGE_ENCRYPTION"];
    
    return YES;
}

/**
 * 处理密钥交换错误响应
 */
- (BOOL)handleKeyExchangeError:(NSData *)errorData {
    NSString *errorMessage = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
    if (!errorMessage) {
        errorMessage = @"未知的服务端错误";
    }
    
    CIMLog(@"❌ [ECDH客户端] 服务端返回错误: %@", errorMessage);
    
    [self notifyKeyExchangeFailed:[self createError:ECDHClientProtocolErrorDomain 
                                               code:-9 
                                        description:[NSString stringWithFormat:@"服务端错误: %@", errorMessage]]];
    
    return NO;
}

/**
 * 发送会话密钥派生通知给服务端
 */
- (void)sendSessionKeyDerivedNotification:(NSString *)context {
    NSData *contextData = [context dataUsingEncoding:NSUTF8StringEncoding];
    NSData *notificationData = [self createProtocolMessage:ECDH_SESSION_KEY_DERIVED payload:contextData];
    
    CIMLog(@"📤 [ECDH客户端] 发送会话密钥派生通知: %@", context);
    
    // 这里应该通过 socket 发送给服务端，具体实现在集成时完成
    // [self.socketManager sendData:notificationData];
}

/**
 * 创建协议消息
 */
- (NSData *)createProtocolMessage:(uint8_t)messageType payload:(NSData *)payload {
    NSMutableData *messageData = [NSMutableData dataWithCapacity:HEADER_LENGTH + payload.length];
    
    // 写入消息头
    uint8_t header[HEADER_LENGTH];
    header[0] = PROTOCOL_VERSION;  // version
    header[1] = messageType;       // type
    OSWriteBigInt32(header, 2, (uint32_t)payload.length);  // length
    header[6] = 0;                 // reserved
    header[7] = 0;                 // reserved
    
    [messageData appendBytes:header length:HEADER_LENGTH];
    [messageData appendData:payload];
    
    return [messageData copy];
}

/**
 * 从共享密钥派生会话密钥 (HKDF-SHA256)
 */
- (NSData *)deriveKeyFromSharedSecret:(NSData *)sharedSecret 
                              context:(NSString *)context 
                               length:(NSUInteger)length {
    
    NSData *salt = [HKDF_SALT dataUsingEncoding:NSUTF8StringEncoding];
    NSData *info = [context dataUsingEncoding:NSUTF8StringEncoding];
    
    // HKDF-Extract
    NSMutableData *prk = [NSMutableData dataWithLength:HASH_LENGTH];
    CCHmac(kCCHmacAlgSHA256, 
           salt.bytes, salt.length,
           sharedSecret.bytes, sharedSecret.length,
           prk.mutableBytes);
    
    // HKDF-Expand
    NSUInteger iterations = (length + HASH_LENGTH - 1) / HASH_LENGTH;
    NSMutableData *result = [NSMutableData dataWithCapacity:length];
    NSMutableData *t = [NSMutableData data];
    
    for (NSUInteger i = 1; i <= iterations; i++) {
        NSMutableData *hmacInput = [NSMutableData dataWithData:t];
        [hmacInput appendData:info];
        uint8_t counter = (uint8_t)i;
        [hmacInput appendBytes:&counter length:1];
        
        NSMutableData *tNew = [NSMutableData dataWithLength:HASH_LENGTH];
        CCHmac(kCCHmacAlgSHA256,
               prk.bytes, prk.length,
               hmacInput.bytes, hmacInput.length,
               tNew.mutableBytes);
        
        t = tNew;
        
        NSUInteger copyLength = MIN(HASH_LENGTH, length - result.length);
        [result appendBytes:t.bytes length:copyLength];
        
        if (result.length >= length) {
            break;
        }
    }
    
    [result setLength:length];
    return [result copy];
}

/**
 * 创建错误对象
 */
- (NSError *)createError:(NSString *)domain code:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:domain 
                               code:code 
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

#pragma mark - 代理通知方法

- (void)notifyKeyExchangeSucceeded:(NSData *)sharedSecret sessionKey:(NSData *)sessionKey {
    if ([self.delegate respondsToSelector:@selector(ecdhProtocolHandler:keyExchangeSucceeded:sessionKey:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate ecdhProtocolHandler:self 
                        keyExchangeSucceeded:sharedSecret 
                                  sessionKey:sessionKey];
        });
    }
}

- (void)notifyKeyExchangeFailed:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(ecdhProtocolHandler:keyExchangeFailed:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate ecdhProtocolHandler:self keyExchangeFailed:error];
        });
    }
}

- (void)notifyStatusUpdate:(NSString *)status {
    if ([self.delegate respondsToSelector:@selector(ecdhProtocolHandler:statusUpdated:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate ecdhProtocolHandler:self statusUpdated:status];
        });
    }
}

@end
