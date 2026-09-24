//
//  LingIMTcpRequestModel+HandleReceiveMessage.h
//  NoaChatSDKCore
//
//  Created by phl on 2025/6/27.
//

#import "LingIMTcpRequestModel.h"

// tcp发送类

NS_ASSUME_NONNULL_BEGIN

@interface LingIMTcpRequestModel (HandleReceiveMessage)

/// MARK: 接收消息处理
- (void)receiveMessageDealWith:(IMMessage *)receiveMessage;

@end

NS_ASSUME_NONNULL_END
