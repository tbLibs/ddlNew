//
//  LIMServerMessageModel.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

#import "LIMServerMessageModel.h"
#import "NoaIMSDKManager+ServiceMessage.h"

@implementation LIMServerMessageModel

+ (NSDictionary *)mj_replacedKeyFromPropertyName {
    //更换参数名称
    return @{
        @"ID" : @"id"
    };
}

#pragma mark - 根据聊天记录消息，获取数据库存储类型消息
- (IMServerMessage *)getChatMessageFromServerMessageModel {
    if (self) {
        
        //创建配置系统通知消息
        IMServerMessage *serverMessage = [IMServerMessage new];
        serverMessage.from = self.fromUid;
        serverMessage.nick = self.nick;
        serverMessage.icon = self.icon;
        serverMessage.to = self.toUid;
        serverMessage.sMsgType = self.smsgType;
        serverMessage.sendTime = self.sendTime;
        serverMessage.sMsgId = self.smsgId;
        
        NSDictionary *bodyDict = [self.messageBody mj_JSONObject];
        
        switch (self.smsgType) {
            case IMServerMessage_ServerMsgType_CreateGroupMessage://创建群聊200
            {
                CreateGroupMessage *createGroup = [CreateGroupMessage new];
                createGroup.uid = [bodyDict objectForKey:@"uid"];
                createGroup.nick = [bodyDict objectForKey:@"nick"];
                
                createGroup.gid = [bodyDict objectForKey:@"gid"];
                createGroup.gName = [bodyDict objectForKey:@"gName"];
                createGroup.gHeader = [bodyDict objectForKey:@"gHeader"];
                
                NSDictionary *groupInfoDic = [[bodyDict objectForKey:@"groupInfo"] mj_JSONObject];
                GroupInfo *groupInfo = [GroupInfo new];
                groupInfo.msgTop = [[groupInfoDic objectForKey:@"msgTop"] boolValue];
                groupInfo.msgNoPromt = [[groupInfoDic objectForKey:@"msgNoPromt"] boolValue];
                groupInfo.isPrivateChat = [[groupInfoDic objectForKey:@"isPrivateChat"] boolValue];
                groupInfo.isGroupChat = [[groupInfoDic objectForKey:@"isGroupChat"] boolValue];
                groupInfo.isNeedVerify = [[groupInfoDic objectForKey:@"isNeedVerify"] boolValue];
                groupInfo.gId = [groupInfoDic objectForKey:@"gId"];
                groupInfo.maxMemberCount = [[groupInfoDic objectForKey:@"maxMemberCount"] intValue];
                groupInfo.gStatus = [[groupInfoDic objectForKey:@"gStatus"] intValue];
                groupInfo.createTime = [[groupInfoDic objectForKey:@"createTime"] longLongValue];
                createGroup.groupInfo = groupInfo;
                
                __block NSMutableArray <UserInfo *> *userInfoArr = [NSMutableArray array];
                NSArray *invitedArr = (NSArray *)[bodyDict objectForKey:@"inviteUid"];
                [invitedArr enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    UserInfo *user = [UserInfo new];
                    user.uId = [obj objectForKey:@"uId"];
                    user.uNick = [obj objectForKey:@"uNick"];
                    user.uHeader = [obj objectForKey:@"uHeader"];
                    [userInfoArr addObject:user];
                }];
                createGroup.inviteUidArray = userInfoArr;
                
                //系统通知消息，配置创建群的消息
                serverMessage.createGroupMessage = createGroup;
                
            }
                break;
            case IMServerMessage_ServerMsgType_InviteConfirmGroupMessage://邀请进群确认/邀请进群通知  该消息只转发给在线的所有群成员 215
            {
                InviteConfirmGroupMessage *inviteGroup = [InviteConfirmGroupMessage new];
                inviteGroup.nick = [bodyDict objectForKey:@"nick"];
                inviteGroup.uid = [bodyDict objectForKey:@"uid"];
                inviteGroup.reason = [bodyDict objectForKey:@"reason"];
                inviteGroup.gid = [bodyDict objectForKey:@"gid"];
                inviteGroup.gName = [bodyDict objectForKey:@"gName"];
                inviteGroup.gHeader = [bodyDict objectForKey:@"gHeader"];
                inviteGroup.confirmUid = [bodyDict objectForKey:@"confirmUid"];
                inviteGroup.confirmNick = [bodyDict objectForKey:@"confirmNick"];
                inviteGroup.type = [[bodyDict objectForKey:@"type"] intValue];
                inviteGroup.status = [[bodyDict objectForKey:@"status"] intValue];
                
                __block NSMutableArray <UserInfo *> *userInfoArr = [NSMutableArray array];
                NSArray *invitedArr = (NSArray *)[bodyDict objectForKey:@"inviteUid"];
                [invitedArr enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    UserInfo *user = [UserInfo new];
                    user.uId = [obj objectForKey:@"uId"];
                    user.uNick = [obj objectForKey:@"uNick"];
                    user.uHeader = [obj objectForKey:@"uHeader"];
                    [userInfoArr addObject:user];
                }];
                inviteGroup.inviteUidArray = userInfoArr;
                
                
                //系统通知消息，配置邀请进群的消息
                serverMessage.inviteConfirmGroupMessage = inviteGroup;
                
            }
                break;
            case IMServerMessage_ServerMsgType_InviteJoinRepGroupMessage://邀请进群申请  该消息发送给群管理员 214
            {
                //邀请入群申请信息
                InviteJoinRepGroupMessage *inviteJoinGroupRequest = [InviteJoinRepGroupMessage new];
                inviteJoinGroupRequest.uid = [bodyDict objectForKey:@"uid"];//发起邀请者ID
                inviteJoinGroupRequest.nick = [bodyDict objectForKey:@"nick"];//发起邀请者昵称
                inviteJoinGroupRequest.gid = [bodyDict objectForKey:@"gid"];//群ID
                inviteJoinGroupRequest.gName = [bodyDict objectForKey:@"g_name"];//群名称
                inviteJoinGroupRequest.reason = [bodyDict objectForKey:@"reason"];//进群理由
                __block NSMutableArray <UserInfo *> *userInfoArr = [NSMutableArray array];
                NSArray *invitedArr = (NSArray *)[bodyDict objectForKey:@"inviteUid"];
                [invitedArr enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    UserInfo *user = [UserInfo new];
                    user.uId = [obj objectForKey:@"uId"];
                    user.uNick = [obj objectForKey:@"uNick"];
                    user.uHeader = [obj objectForKey:@"uHeader"];
                    [userInfoArr addObject:user];
                }];
                inviteJoinGroupRequest.inviteUidArray = userInfoArr;//被邀请用户信息
                //群组头像
                
                //系统通知消息，配置 邀请入群申请 的消息
                serverMessage.inviteJoinRepGroupMessage = inviteJoinGroupRequest;
                
            }
                break;
                
            default:
                break;
        }

        return serverMessage;
        
    }else {
        return nil;
    }
    
}

@end
