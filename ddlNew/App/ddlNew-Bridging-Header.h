//
//  ddlNew-Bridging-Header.h
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

#import <pdns-sdk-ios/DNSResolver.h>
#import "../Basic/LXChatEncrypt/LXChatEncrypt.h"
// 历史接口需要 SDK 现有的历史模型转换器，显式导入而不修改 SDK 伞头。
#import <NoaChatCore/NoaChatMessageModel.h>
// 消息编辑与转发复用SDK既有模型转换，避免重复实现protobuf映射。
#import <NoaChatCore/LingIMModelTool.h>
// STS接口位于SDK用户分类，媒体上传显式依赖该现有公开接口。
#import <NoaChatCore/NoaIMSDKManager+User.h>
// 应用层透明观察GroupMemberNick，原SDK消息代理保持完整转发。
#import <NoaChatCore/NoaIMSocketManagerTool.h>
//#import "NoaIMSDKCore.h"
