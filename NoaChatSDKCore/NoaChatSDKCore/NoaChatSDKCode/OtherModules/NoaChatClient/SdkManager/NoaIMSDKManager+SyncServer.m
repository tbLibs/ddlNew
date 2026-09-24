//
//  NoaIMSDKManager+SyncServer.m
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/23.
//

#import "NoaIMSDKManager+SyncServer.h"

#import "NoaIMSDKManager+User.h"
#import "NoaIMSDKManager+Friend.h"
#import "NoaIMSDKManager+Group.h"
#import "NoaIMSDKManager+ChatMessage.h"
#import "NoaIMSDKManager+ServiceMessage.h"
#import "NoaIMSDKManager+Session.h"
#import "NoaIMSDKManager+MessageRemind.h"
#import "NoaIMSDKManager+AppInfo.h"
#import "NoaIMSDKManager+Translate.h"

#import "LIMSessionModel.h"
#import "LIMServerMessageModel.h"
#import "NoaChatMessageModel.h"
#import <NoaChatCore/LingIMGroupMemberModel.h>
#import "LingIMSensitivePageModel.h"
#import "LingIMTranslateConfigModel.h"
#import <MMKV/MMKV.h>
#import <objc/runtime.h>

static const void *kDBQueueKey = &kDBQueueKey;

@implementation NoaIMSDKManager (SyncServer)

- (dispatch_queue_t)dbQueue {
    dispatch_queue_t queue = objc_getAssociatedObject(self, kDBQueueKey);
    if (!queue) {
        queue = dispatch_queue_create("com.cim.sync.dbQueue", DISPATCH_QUEUE_SERIAL);
        objc_setAssociatedObject(self, kDBQueueKey, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return queue;
}

- (void)setDbQueue:(dispatch_queue_t)dbQueue {
    objc_setAssociatedObject(self, kDBQueueKey, dbQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - ******服务端同步联系人******
- (void)syncContactsFromServer {
    //1.同步好友分组信息
    //2.同步好友列表信息
    [self requestFriendGroupListFromService];
}

#pragma mark - ******服务端同步群组******
- (void)syncGroupsFromServer {
    //获取本地缓存的通讯录好友数据
    if (self.lastSyncGroupTime != 0) {
        [self requestGroupListFromServiceWith:1 withLastSyncGroupTime:self.lastSyncGroupTime];
    } else {
        [self requestGroupListFromServiceWith:1 withLastSyncGroupTime:0];
    }
}

#pragma mark - ******服务端同步会话******
- (void)syncSessionsFromServer {
    [self requestServerOfflineListFromServiceWith:1];
    //1.先请求离线的系统通知消息，创建出 创建群聊/邀请入群的信息
    //2.同步服务端的会话列表
    //3.更新会话的最新消息
}

//socket重连成功后，重新同步会话列表
- (void)reconnectSyncSessionsFromServer {
    if (self.myUserID == nil || self.myUserID.length == 0 || self.myUserToken == nil || self.myUserToken.length == 0) {
        CIMLog(@"听用户信息为空，不同步回话列表");
        return;
    }
    if (self.lastSyncSessionTime != 0) {
        if (self.clearReadNumSMsgIdDict == nil) {
            self.clearReadNumSMsgIdDict = [[NSDictionary alloc] init];
        }
        self.clearReadNumSMsgIdDict = [[MMKV defaultMMKV] getObjectOfClass:[NSDictionary class] forKey:@"clearReadNumSMsgIdDictKey"];
        //本地缓存有数据，增量拉取，lastSyncTime传上次同步时间(已经和服务器时间做了差值比较，其实是服务器时间)
        [self requestSessionListFromServiceWith:1 withLastSyncTime:self.lastSyncSessionTime];
    } else {
        //本地缓存没有数据，全量拉取，lastSyncTime不传
        [self requestSessionListFromServiceWith:1 withLastSyncTime:0];
    }
}

#pragma mark - ******用户翻译配置信息和每个会话的翻译配置信息******
- (void)syncAppUserAndSessionTranslateInfoServer {
    NSString *lastSyncTime = @"";
    NSString *sessionTranslateKey = [NSString stringWithFormat:@"SessionTranslateInfoSyncStatus_%@", self.myUserID];
    BOOL sessionTranslateSync = [[MMKV defaultMMKV] getBoolForKey:sessionTranslateKey];
    if (sessionTranslateSync) {
        lastSyncTime = [NSDate UTCDateTimeStr];
    } else {
        [[MMKV defaultMMKV] setBool:YES forKey:sessionTranslateKey];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:[self myUserID] forKey:@"userUid"];
    [params setValue:lastSyncTime forKey:@"lastSyncTime"];
    
    __weak typeof(self) weakSelf = self;
    [self imSdkTranslateGetUserAllTranslateConfig:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSArray class]]) {
            NSArray *dataArr = (NSArray *)data;
            NSArray *dataList = [LingIMTranslateConfigModel mj_objectArrayWithKeyValuesArray:dataArr];
            if (dataList.count > 0) {
                dispatch_async(self.appUserAndSessionTranslateInfoServerQueue, ^{
                    for (LingIMTranslateConfigModel *configModel in dataList) {
                        if (configModel.level == 1) {
                            //会话级别
                            //更新到sessionModel
                            LingIMSessionModel *sessionModel = [weakSelf toolCheckMySessionWith:configModel.dialogId];
                            if (sessionModel) {
                                sessionModel.isSendAutoTranslate = configModel.translateSwitch;
                                sessionModel.sendTranslateChannel = configModel.channel;
                                sessionModel.sendTranslateChannelName = configModel.channelName;
                                sessionModel.sendTranslateLanguage = configModel.targetLang;
                                sessionModel.sendTranslateLanguageName = configModel.targetLangName;
                                sessionModel.receiveTranslateChannel = configModel.receiveChannel;
                                sessionModel.receiveTranslateChannelName = configModel.receiveChannelName;
                                sessionModel.receiveTranslateLanguage = configModel.receiveTargetLang;
                                sessionModel.receiveTranslateLanguageName = configModel.receiveTargetLangName;
                                sessionModel.isReceiveAutoTranslate = configModel.receiveTranslateSwitch;
                                sessionModel.translateConfigId = configModel.configId;
                                //更新到本地
                                [weakSelf toolUpdateSessionWith:sessionModel];
                            }
                        }
                    }
                    [weakSelf.userDelegate imsdkSynUserAllTranslateConfig:dataList];
                });
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
    }];
}

#pragma mark - ******服务端同步消息提醒方式******
- (void)syncMessageRemindFromServer {
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:[self myUserID] forKey:@"userUid"];
    
    [self userGetMessageRemindWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataDict = (NSDictionary *)data;
            dispatch_queue_t concurrent_queue = dispatch_queue_create("userGetMessageRemindWith", DISPATCH_QUEUE_CONCURRENT);
            dispatch_async(concurrent_queue, ^{
                NSInteger messageRemind = [[dataDict objectForKey:@"isNewMsgNotify"] integerValue];
                NSInteger messageVoiceRemind = [[dataDict objectForKey:@"isVoiceNotice"] integerValue];
                NSInteger messageVibrationRemind = [[dataDict objectForKey:@"isShakeNotice"] integerValue];
                [weakSelf toolMessageReceiveRemindOpen:messageRemind == 1];
                [weakSelf toolMessageReceiveRemindVoiceOpen:messageVoiceRemind == 1];
                [weakSelf toolMessageReceiveRemindVibrationOpen:messageVibrationRemind == 1];
            });
        }
        
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        CIMLog(@"同步更新消息提醒方式失败：%@",msg);
    }];
}

#pragma mark - ******服务端同步敏感词******
- (void)syncAppSensitiveFromServer {
    //创建敏感词 表
    [DBTOOL createTableWithName:[IMSDKManager getTableNameForSensitive] model:LingIMSensitiveRecordsModel.class];
    [self requestSensitiveContentFromServiceWith:1];
}

#pragma mark - 同步类型消息，同步会话状态
- (void)syncUserSessionStatus:(IMServerMessage *)message {
    SynchroMessage *syncMsessage = message.synchroMessage;
    LingIMSessionModel *sessionModel = [self toolCheckMySessionWith:syncMsessage.sessionId];
    if (sessionModel) {
        switch (syncMsessage.synchroType) {
            case SynchroType_SessionTop://会话列表置顶
            {
                sessionModel.sessionTop = YES;
                sessionModel.sessionTopTime = message.sendTime;
                [self toolUpdateSessionWith:sessionModel];
            }
                break;
            case SynchroType_SessionUnTop://会话列表取消置顶
            {
                sessionModel.sessionTop = NO;
                sessionModel.sessionTopTime = 0;
                [self toolUpdateSessionWith:sessionModel];
            }
                break;
            case SynchroType_ChatMessageFree://会话消息免打扰 开启/关闭
            {
                if (syncMsessage.status) {
                    sessionModel.sessionNoDisturb = YES;
                } else {
                    sessionModel.sessionNoDisturb = NO;
                }
                [self toolUpdateSessionWith:sessionModel];
            }
                break;
            case SynchroType_UserHeader://更新了自己的头像
            {
                [self configNewUserAvatar:syncMsessage.content];
                [self.userDelegate cimUserUpdateAvatar:syncMsessage.content];
            }
                break;
            case SynchroType_UserNick://更新了自己的昵称
            {
                [self configNewUserNickName:syncMsessage.content];
                [self.userDelegate cimUserUpdateNickName:syncMsessage.content];
            }
                break;
            case SynchroType_FriendRemarks://更新了好友的的备注
            {
                [self.userDelegate cimToolUserFriendRemarkChange:syncMsessage];
            }
                break;
            
            default:
                break;
        }
    } else {
        switch (syncMsessage.synchroType) {
            case SynchroType_AllReadMessage://全部已读
            {
                [self.sessionDelegate imSdkSessionListAllRead:syncMsessage.content];
            }
                break;
            default:
                break;
            }
        }
}

#pragma mark - 同步服务端数据具体方法的实现
/// 服务端 更新通讯录好友分组数据
- (void)requestFriendGroupListFromService {
    //获取本地缓存的分组数据
    __weak typeof(self) weakSelf = self;
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:[self myUserID] forKey:@"userUid"];
    if (self.lastSyncSectionTime != 0) {
        [params setValue:@(self.lastSyncSectionTime) forKey:@"lastSyncTime"];
    }
    CIMLog(@"[好友] 开始获取好友列表, 参数 = %@", params);
    [self getFriendGroupListWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        CIMLog(@"[好友] 好友列表获取成功,data = %@", data);
        //请求成功
        //获取本地缓存的通讯录好友数据
        if ([data isKindOfClass:[NSArray class]]) {
            //清空本地数据
            NSArray *friendGroupArray = (NSArray *)data;
            if (friendGroupArray.count > 0) {
                for (NSInteger i = 0; i<friendGroupArray.count; i++) {
                    NSDictionary * obj = [friendGroupArray objectAtIndex:i];
                    LingIMFriendGroupModel *friendGroupModel = [LingIMFriendGroupModel mj_objectWithKeyValues:obj];
                    //delFlag删除标识 0正常；1删除
                    dispatch_async(self.friendGroupListUpdateQueue, ^{
                        if (friendGroupModel.delFlag == 0) {
                            [weakSelf toolUpdateMyFriendGroupWith:friendGroupModel];
                        } else {
                            [weakSelf toolDeleteMyFriendGroupWith:friendGroupModel.ugUuid];
                        }
                    });
                    
                    if (i == friendGroupArray.count - 1) {
                        if (weakSelf.lastSyncFriendTime != 0) {
                            [weakSelf requestFriendListFromServiceWith:1 withLastSyncFriendTime:weakSelf.lastSyncFriendTime];
                        } else {
                            [weakSelf requestFriendListFromServiceWith:1 withLastSyncFriendTime:0];
                        }
                    }
                }
            } else {
                if ( weakSelf.lastSyncFriendTime != 0) {
                    [weakSelf requestFriendListFromServiceWith:1 withLastSyncFriendTime:weakSelf.lastSyncFriendTime];
                } else {
                    [weakSelf requestFriendListFromServiceWith:1 withLastSyncFriendTime:0];
                }
            }
        }else {
            //接口成功了，返回数据格式错误
            if (weakSelf.lastSyncFriendTime != 0) {
                [weakSelf requestFriendListFromServiceWith:1 withLastSyncFriendTime:weakSelf.lastSyncFriendTime];
            } else {
                [weakSelf requestFriendListFromServiceWith:1 withLastSyncFriendTime:0];
            }
        }
        NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_SECTION_TIME_KEY, weakSelf.myUserID];
        [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];

    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        CIMLog(@"[好友] 好友列表获取失败");
    }];
    
}
/// 服务端 更新通讯录数据
- (void)requestFriendListFromServiceWith:(NSInteger)page withLastSyncFriendTime:(long long)lastSyncFriendTime {
    //默认分组
    LingIMFriendGroupModel *defaultFriendGroupModel = [self toolGetMyFriendGroupTypeList:-1].firstObject;
    
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:@(page) forKey:@"pageNumber"];
    [params setValue:@(100) forKey:@"pageSize"];
    [params setValue:@(0) forKey:@"pageStart"];
    [params setValue:[self myUserID] forKey:@"userUid"];
    if (lastSyncFriendTime != 0) {
        [params setValue:@(self.lastSyncFriendTime) forKey:@"lastSyncTime"];
    }
    
    [self getContactsFromServerWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            NSArray *friendList = [dict objectForKey:@"rows"];
            NSMutableArray *tempContactArr = [NSMutableArray array];
            dispatch_async(self.contactsListUpdateQueue, ^{
                
                for (NSInteger i = 0; i<friendList.count; i++) {
                    NSDictionary * obj = [friendList objectAtIndex:i];
                    LingIMFriendModel *model = [LingIMFriendModel mj_objectWithKeyValues:obj];
                    model.showName = model.remarks.length > 0 ? model.remarks : model.nickname;
                    if (model.ugUuid.length < 1) {
                        if (defaultFriendGroupModel) {
                            model.ugUuid = defaultFriendGroupModel.ugUuid;
                        }
                    }
                    
                    if (lastSyncFriendTime == 0) {
                        [tempContactArr addObject:model];
                    } else {
                        //status好友状态 1：是好友 0：不是好友（已删除好友）
                        if (model.status == 1) {
                            [tempContactArr addObject:model];
                        } else {
                            [weakSelf toolDeleteMyFriendWith:model.friendUserUID];
                        }
                    }
                }
                if (tempContactArr.count > 0) {
                    //批量插入/更新好友信息
                    [weakSelf toolBacthDBUpdateMyFriendWith:tempContactArr];
                }
            });
            NSInteger totalPage = [[dict objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dict objectForKey:@"current"] integerValue];
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf requestFriendListFromServiceWith:currentPage + 1 withLastSyncFriendTime:lastSyncFriendTime];
            } else {
                NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_FRIEND_TIME_KEY, weakSelf.myUserID];
                [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];
                [[MMKV defaultMMKV] setBool:YES forKey:@"isSyncAllFriend"];
                //更新好友在线状态
                
                dispatch_async(self.friendListQueue, ^{
                    NSArray *friendList = [weakSelf toolGetMyFriendList];
                    [weakSelf requestFriendOnlineStatusFromServiceWith:1 friendList:friendList];
                });
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        //通讯录同步服务器错误
        [weakSelf.userDelegate imSdkUserContactsSyncFailed:msg];
        //更新好友在线状态
        dispatch_async(self.friendListQueue, ^{
            NSArray *friendList = [weakSelf toolGetMyFriendList];
            [weakSelf requestFriendOnlineStatusFromServiceWith:1 friendList:friendList];
        });
        
    }];
}

/// 服务端 更新通讯录好友在线状态
- (void)requestFriendOnlineStatusFromServiceWith:(NSInteger)page friendList:(NSArray<LingIMFriendModel *> *)friendList {
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:@(page) forKey:@"pageNumber"];
    [params setValue:@(100) forKey:@"pageSize"];
    [params setValue:@(0) forKey:@"pageStart"];
    [params setValue:[self myUserID] forKey:@"userUid"];
    
    [self getFriendGetOnlineStatusWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            NSArray *onlineFriendUidList = [dict objectForKey:@"rows"];
            
            BOOL tempOnlineStatus;
            NSMutableArray *tempOnlineArr = [NSMutableArray array];
            for (int i = 0; i < friendList.count; i++) {
                LingIMFriendModel *model = (LingIMFriendModel *)[friendList objectAtIndex:i];
                tempOnlineStatus = model.onlineStatus;
                if ([onlineFriendUidList containsObject:model.friendUserUID]) {
                    model.onlineStatus = YES;
                } else {
                    model.onlineStatus = NO;
                }
                if (tempOnlineStatus != model.onlineStatus) {
                    [tempOnlineArr addObject:model];
                }
            }
            
            if (tempOnlineArr.count > 0) {
                //批量插入/更新好友信息
                dispatch_async(weakSelf.friendOnlineQueue, ^{
                    [weakSelf toolBacthDBUpdateMyFriendWith:tempOnlineArr];
                });
            }
            
            NSInteger totalPage = [[dict objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dict objectForKey:@"current"] integerValue];
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf requestFriendOnlineStatusFromServiceWith:currentPage + 1 friendList:friendList];
            } else {
                NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_FRIEND_TIME_KEY, weakSelf.myUserID];
                [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];

                //好友通讯录同步完成
                [weakSelf.userDelegate imSdkUserContactsSyncFinish];
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        //好友通讯录同步完成
        [weakSelf.userDelegate imSdkUserContactsSyncFinish];
    }];
}

/// 服务端 更新群组数据
- (void)requestGroupListFromServiceWith:(NSInteger)page withLastSyncGroupTime:(long long)lastSyncGroupTime {
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:@(page) forKey:@"pageNumber"];
    [params setValue:@(100) forKey:@"pageSize"];
    [params setValue:@(0) forKey:@"pageStart"];
    [params setValue:[self myUserID] forKey:@"userUid"];
    if (lastSyncGroupTime != 0) {
        [params setValue:@(self.lastSyncGroupTime) forKey:@"lastSyncTime"];
    }
    
    [self groupListWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            NSArray *groupList = [dict objectForKey:@"rows"];
            __block NSMutableArray *tempGroupArr = [NSMutableArray array];
            
            dispatch_async(self.groupListQueue, ^{
                [groupList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    LingIMGroupModel *model = [LingIMGroupModel mj_objectWithKeyValues:obj];
                    LingIMGroupModel *localGroupModel = [weakSelf toolCheckMyGroupWith:model.groupId];
                    model.lastSyncMemberTime = localGroupModel.lastSyncMemberTime;
                    model.lastSyncActiviteScoreime = localGroupModel.lastSyncActiviteScoreime;
                    if (localGroupModel) {
                        model.isMessageInform = localGroupModel.isMessageInform;
                        model.isActiveEnabled = localGroupModel.isActiveEnabled;
                    } else {
                        model.isMessageInform = 1;
                        model.isActiveEnabled = 1;
                    }
                    if (lastSyncGroupTime != 0) {
                        //groupStatus (0 封禁，1正常，2已删除) , leaveGroupStatus（离群状态（0：正常；1：退群））
                        if (model.groupStatus == 2 || model.leaveGroupStatus == 1) {
                            [weakSelf toolDeleteMyGroupWith:model.groupId];
                        } else {
                            [tempGroupArr addObject:model];
                        }
                    } else {
                        [tempGroupArr addObject:model];
                    }
                }];
                
                if (tempGroupArr.count > 0) {
                    [weakSelf toolBatchInsertOrUpdateGroupModelWith:tempGroupArr];
                }
            });
            
            NSInteger totalPage = [[dict objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dict objectForKey:@"current"] integerValue];
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf requestGroupListFromServiceWith:currentPage + 1 withLastSyncGroupTime:lastSyncGroupTime];
            }else {
                NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_GROUP_TIME_KEY, weakSelf.myUserID];
                [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];

                //群组数据同步完成
                [weakSelf.groupDelegate imSdkGroupSyncFinish];
            }
            
        }
        
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        [weakSelf.groupDelegate imSdkGroupSyncFailed:msg];
    }];
    
}

/// 服务端，更新会话列表数据
- (void)requestSessionListFromServiceWith:(NSInteger)page withLastSyncTime:(long long)lastSyncTime {
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:@(page) forKey:@"pageNumber"];
    [params setValue:@(100) forKey:@"pageSize"];
    [params setValue:@(0) forKey:@"pageStart"];
    [params setValue:[self myUserID] forKey:@"userUid"];
    if (lastSyncTime != 0) {
        [params setValue:@(lastSyncTime) forKey:@"lastSyncTime"];
    }
    
    [self getConversationsFromServer:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        dispatch_async(strongSelf.sessionListUpdateQueue, ^{
            if (![data isKindOfClass:[NSDictionary class]]) {
                return;
            }
            
            NSDictionary *dict = (NSDictionary *)data;
            NSArray *sessionList = [dict objectForKey:@"items"];
            
            NSMutableArray *tempSessionList = [NSMutableArray array];
            NSMutableArray *tempTopSessionList = [NSMutableArray array];
            
            if (!sessionList || sessionList.count == 0) {
                NSInteger totalPage = [[dict objectForKey:@"pages"] integerValue];
                NSInteger currentPage = [[dict objectForKey:@"currentPage"] integerValue];
                
                if (totalPage <= currentPage) {
                    dispatch_async(strongSelf.dbQueue, ^{
                        // 所有已提交的 DB 写入都在此之前完成
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [strongSelf.sessionDelegate imSdkSessionSyncFinish];
                            // 更新未读数等
                            dispatch_async(strongSelf.unreadCountQueue, ^{
                                NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                                [strongSelf.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
                            });
                            // 同步配置及持久化 lastSyncTime
                            [strongSelf syncAppUserAndSessionTranslateInfoServer];
                            NSString *key = [NSString stringWithFormat:@"%@_%@", LAST_SYNC_SESSION_TIME_KEY, strongSelf.myUserID];
                            [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];
                            // 清理内存数据（在业务队列或主线程都行，保持一致）
                            dispatch_async(strongSelf.sessionListUpdateQueue, ^{
                                [strongSelf.allSessionList removeAllObjects];
                                strongSelf.clearReadNumSMsgIdDict = nil;
                            });
                        });
                    });
                }
                return;
            }
            
            for (NSDictionary *obj in sessionList) {
                LIMSessionModel *tempSessionModel = [LIMSessionModel mj_objectWithKeyValues:obj];
                LingIMSessionModel *sessionModel = nil;
                switch (tempSessionModel.dialogType) {
                    case 0:
                    case 1:
                        sessionModel = [strongSelf updateSessionModelWith:tempSessionModel isFirst:lastSyncTime == 0];
                        break;
                    case 3:
                        sessionModel = [strongSelf updateSessionMassMessageWith:tempSessionModel];
                        break;
                    case 5:
                        if ([tempSessionModel.peerUid isEqualToString:@"100008"]) {
                            //系统消息(目前是群助手)
                            sessionModel = [strongSelf updateSessionGroupHelperWith:tempSessionModel];
                        } else if ([tempSessionModel.peerUid isEqualToString:@"100009"]) {
                            //系统消息(支付通知)
                            sessionModel = [strongSelf updateSessionPaymentAssistantWith:tempSessionModel];
                        }
                        break;
                    default:
                        CIMLog(@"新增的会话类型:%ld--%@", tempSessionModel.dialogType, tempSessionModel.userName);
                        break;
                }
                
                if (!sessionModel) {
                    continue;
                }
                
                if (tempSessionModel.delFlag == 1) {
                    [strongSelf toolDeleteSessionModelWith:sessionModel andDeleteAllChatModel:YES];
                } else {
                    [tempSessionList addObject:sessionModel];
                    if (sessionModel.sessionTop) {
                        [tempTopSessionList addObject:sessionModel];
                    }
                    if (lastSyncTime != 0) {
                        //会话列表同步
                        [strongSelf.sessionDelegate cimToolSessionUpdateWith:sessionModel];
                    }
                }
            }
            
            if (tempSessionList.count > 0) {
                if (lastSyncTime == 0) {
                    [strongSelf.sessionDelegate cimToolSessionListUpdateWith:tempSessionList topSessionList:tempTopSessionList isFirstPage:(page == 1)];
                }
                [strongSelf.allSessionList addObjectsFromArray:tempSessionList];
            }
            
            NSInteger totalPage = [[dict objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dict objectForKey:@"currentPage"] integerValue];
            
            dispatch_async(strongSelf.dbQueue, ^{
                // 存储当前获取到的数据
                [DBTOOL insertOrUpdateSessionModelListWith:tempSessionList];
                if (totalPage > currentPage) {
                    //还有未加载的数据, 在 DB 写入完成后再触发下一页请求 —— 保证顺序性与数据落库
                    dispatch_async(dispatch_get_main_queue(), ^{
                        CIMLog(@"[获取会话消息] 获取会话数据成功，还有未加载的数据，继续请求");
                        [strongSelf requestSessionListFromServiceWith:currentPage + 1 withLastSyncTime:lastSyncTime];
                    });
                    
                } else {
                    // 最后一页数据，同步完成
                    CIMLog(@"[获取会话消息] 获取会话数据成功，全部消息获取完成");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        //会话列表同步服务器完成
                        [strongSelf.sessionDelegate imSdkSessionSyncFinish];
                    });
                    
                    //更新会话的消息表最新消息
                    //更新未读消息数
                    dispatch_async(self.unreadCountQueue, ^{
                        NSInteger totalUnread = [IMSDKManager toolGetAllSessionUnreadCount];
                        [strongSelf.sessionDelegate cimToolSessionTotalUnreadCountChange:totalUnread];
                    });
                    
                    //同步用户和会话的翻译配置信息
                    [strongSelf syncAppUserAndSessionTranslateInfoServer];
                    //更新lastSessionUpdateTime
                    NSString *key = [NSString  stringWithFormat:@"%@_%@", LAST_SYNC_SESSION_TIME_KEY, strongSelf.myUserID];
                    [[MMKV defaultMMKV] setInt64:[NSDate getCurrentServerMillisecondTime] forKey:key];
                    
                    // 清理内存数据（在业务队列或主线程都行，保持一致）
                    dispatch_async(strongSelf.sessionListUpdateQueue, ^{
                        [strongSelf.allSessionList removeAllObjects];
                        strongSelf.clearReadNumSMsgIdDict = nil;
                    });
                }
            });
        });
        
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        //会话列表同步服务器失败
        CIMLog(@"[获取会话消息] 获取会话数据失败");
        // 确保失败回滚也走 dbQueue
        dispatch_async(strongSelf.sessionListUpdateQueue, ^{
            [strongSelf.allSessionList removeAllObjects];
        });
        [strongSelf.sessionDelegate imSdkSessionSyncFailed:msg];
    }];
}


/// 服务端，更新离线系统通知数据(200 215类型消息，创建群聊，邀请入群)
- (void)requestServerOfflineListFromServiceWith:(NSInteger)page {
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:@(page) forKey:@"pageNumber"];
    [params setValue:@(100) forKey:@"pageSize"];
    [params setValue:@(0) forKey:@"pageStart"];
    [params setValue:[self myUserID] forKey:@"userUid"];
    
    [self queryOfflineMsgRecord:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            NSArray *serviceMessageList = [dict objectForKey:@"rows"];
            [serviceMessageList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                LIMServerMessageModel *tempModel = [LIMServerMessageModel mj_objectWithKeyValues:obj];
                IMServerMessage *serverMessage = [tempModel getChatMessageFromServerMessageModel];
                if (serverMessage) {
                    [weakSelf toolDealReceiveServiceMessageForGroupTip:serverMessage];
                }
            }];
            
            NSInteger totalPage = [[dict objectForKey:@"pages"] integerValue];
            NSInteger currentPage = [[dict objectForKey:@"current"] integerValue];
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf requestServerOfflineListFromServiceWith:currentPage + 1];
            }else {
                [weakSelf.sessionDelegate imSdkSessionSyncStart];
                
                //拉取会话列表数据
                [weakSelf reconnectSyncSessionsFromServer];
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        if (weakSelf.lastSyncSessionTime != 0) {
            [weakSelf.sessionDelegate imSdkSessionSyncStart];
        }
        //拉取会话列表数据
        [weakSelf reconnectSyncSessionsFromServer];
    }];
}


#pragma mark - 同步 服务端 会话列表 后，针对某个会话的处理

//更新 某会话 信息 (单聊，群聊)
- (LingIMSessionModel *)updateSessionModelWith:(LIMSessionModel *)tempSessionModel isFirst:(BOOL)isFirst{
    LingIMSessionModel *sessionModel;
    if (isFirst) {
        sessionModel = [[LingIMSessionModel alloc] init];
    } else {
        //转数据库存储model
        sessionModel = [IMSDKManager toolCheckMySessionWith:tempSessionModel.peerUid];
        if (sessionModel == nil) {
            sessionModel = [[LingIMSessionModel alloc] init];
        }
    }
    
    //对固定不变的内容赋值
    if (tempSessionModel.dialogType == 0) {
        //单聊
        sessionModel.sessionType = CIMSessionTypeSingle;
    }else if (tempSessionModel.dialogType == 1) {
        //群聊
        sessionModel.sessionType = CIMSessionTypeGroup;
        //普通群聊
        sessionModel.sessionGroupType = CIMGroupTypeNormal;
    }else if (tempSessionModel.dialogType == 3) {
        //群发助手
        sessionModel.sessionType = CIMSessionTypeMassMessage;
    }else if (tempSessionModel.dialogType == 5) {
        if ([tempSessionModel.peerUid isEqualToString:@"100008"]) {
            //系统消息(群助手)
            sessionModel.sessionType = CIMSessionTypeSystemMessage;
        }
        if ([tempSessionModel.peerUid isEqualToString:@"100009"]) {
            //系统消息支付通知
            sessionModel.sessionType = CIMSessionTypePaymentAssistant;
        }
    }else {
        //占位值
        sessionModel.sessionType = CIMSessionTypeDefault;
        CIMLog(@"新增的 未解析 会话类型:%ld", tempSessionModel.dialogType);
    }
    
    sessionModel.sessionID = tempSessionModel.peerUid;
    NSString *sessionChatTableName = [NSString stringWithFormat:@"CIMDB_%@_%@_Table",[IMSDKManager myUserID],tempSessionModel.peerUid];
//    [DBTOOL createTableWithName:sessionChatTableName model:LingIMChatMessageModel.class];
    sessionModel.sessionTableName = sessionChatTableName;
    
    //更新可变的内容
    if([tempSessionModel.remarks isEqualToString:@""] || !tempSessionModel.remarks){
        sessionModel.sessionName = tempSessionModel.userName;
    }else{
        sessionModel.sessionName = tempSessionModel.remarks;
    }
    
    sessionModel.sessionStatus = 1;
    sessionModel.sessionAvatar = tempSessionModel.avatar;
    sessionModel.sessionTop = tempSessionModel.pinnedTime > 0 ? YES : NO;
    sessionModel.sessionNoDisturb = tempSessionModel.dnd;
    sessionModel.sessionTopTime = tempSessionModel.pinnedTime;
    sessionModel.sessionLatestServerMsgID = tempSessionModel.lastMsgId;
    sessionModel.sessionUnreadCount = tempSessionModel.unReadCount > 0 ? tempSessionModel.unReadCount : 0;
    if (tempSessionModel.dialogTime > sessionModel.sessionLatestTime) {
        sessionModel.sessionLatestTime = tempSessionModel.dialogTime;
    }
    
    //服务器返回的当前最新消息
    NoaIMChatMessageModel *sessionLatestMessage = tempSessionModel.sessionLatestMessage;
    //当前回话未读数
    NSInteger currentSessionUnread = tempSessionModel.unReadCount;
    //处理
    if (sessionLatestMessage) {
        //服务器返回了最新可展示消息
        if (sessionLatestMessage.messageType == CIMChatMessageType_TextMessage && sessionLatestMessage.textContent.length <= 0) {
            //过滤掉单聊打招呼的空白消息(如果后台没设置过打招呼语)
            sessionModel.sessionLatestMessage = nil;
            sessionModel.sessionLatestServerMsgID = nil;
            sessionModel.sessionUnreadCount = 0;
        } else {
            //当前会话的本地最新消息，更新最新消息
            sessionModel.sessionLatestMessage = sessionLatestMessage;
            //注意此时红点需要用服务端同步过来的值，因为上面的存储方法会新增1红点，但是此处不需要自增
            NSString *lastSMsgId = (NSString *)[self.clearReadNumSMsgIdDict objectForKey:tempSessionModel.peerUid];
            if (lastSMsgId != nil && lastSMsgId.length > 0) {
                if ([tempSessionModel.sessionLatestMessage.serviceMsgID longLongValue] > [lastSMsgId longLongValue]) {
                    sessionModel.sessionUnreadCount = currentSessionUnread;
                    //本地以 key -value方式，记录一个属性 clearReadNumSMsgId
                    [self updateSessionReadNumSMsgIdWithSessionId:tempSessionModel.peerUid lastSMsgId:tempSessionModel.sessionLatestMessage.serviceMsgID];
                } else {
                    sessionModel.sessionUnreadCount = 0;
                }
            } else {
                sessionModel.sessionUnreadCount = currentSessionUnread;
            }
        }
    } else {
        //服务器没有返回最新可展示消息，此时需清空本地聊天数据
        /*
        if ([IMSDKManager lastSyncSessionTime] != 0) {
            if ([DBTOOL isTableStateOkWithName:sessionChatTableName model:LingIMChatMessageModel.class]) {
                dispatch_async(self.sessionListUpdateQueue, ^{
                    [DBTOOL deleteAllChatMessageWith:sessionChatTableName];
                });
            }
        }
        */
        sessionModel.sessionLatestMessage = nil;
        sessionModel.sessionLatestServerMsgID = nil;
        sessionModel.sessionUnreadCount = 0;
        //告知UI 数据清空
        //[self.messageDelegate cimToolMessageDeleteAll:sessionModel.sessionID];
        
    }
    
    return sessionModel;
}

//更新会话的 群发助手 信息
- (LingIMSessionModel *)updateSessionMassMessageWith:(LIMSessionModel *)tempSessionModel {
    //转数据库存储model
    LingIMSessionModel *sessionModel = [tempSessionModel getSessionModel];
    
    //服务器返回的当前群发助手最新消息
    LIMMassMessageModel *sessionLatestMassMessage = tempSessionModel.sessionLatestMassMessage;
    
    NSString *userKey = [NSString stringWithFormat:@"%@-MassMessage", [self myUserID]];
    if (sessionLatestMassMessage) {
        //服务器返回了最新的 群发助手消息
        //以服务器返回的最新消息为准，进行存储
        NSString *massMessageJson = [sessionLatestMassMessage mj_JSONString];
        [[MMKV defaultMMKV] setString:massMessageJson forKey:userKey];
    }else {
        //认为已清空了 群发助手 列表数据
        [[MMKV defaultMMKV] removeValueForKey:userKey];
    }
    
    
    //更新会话列表本地数据库
    return sessionModel;
}

- (void)updateSessionReadNumSMsgIdWithSessionId:(NSString *)sessionId lastSMsgId:(NSString *)lastSMsgId {
    NSMutableDictionary *clearReadNumSMsgIdDict = [[[MMKV defaultMMKV] getObjectOfClass:[NSDictionary class] forKey:@"clearReadNumSMsgIdDictKey"] mutableCopy];
    if (clearReadNumSMsgIdDict == nil) {
        clearReadNumSMsgIdDict = [[NSMutableDictionary alloc] init];
    }
    [clearReadNumSMsgIdDict setObject:(lastSMsgId ? lastSMsgId : @"0") forKey:sessionId];
    [[MMKV defaultMMKV] setObject:[clearReadNumSMsgIdDict copy] forKey:@"clearReadNumSMsgIdDictKey"];
}

//更新会话的 系统消息(群助手) 信息
- (LingIMSessionModel *)updateSessionGroupHelperWith:(LIMSessionModel *)tempSessionModel {
    
    //转数据库存储model
    LingIMSessionModel *sessionModel = [tempSessionModel getSessionModel];
    
    //当前回话未读数
    NSInteger currentSessionUnread = sessionModel.sessionUnreadCount;
    
    //服务器返回的当前最新消息(IMServerMessage) (tempSessionModel.sessionLatestMessage获得的是IMChatMessage)
    if (tempSessionModel.messageDialogHistory && [tempSessionModel.messageDialogHistory isKindOfClass:[NSDictionary class]]) {
        
        LIMServerMessageModel *tempModel = [LIMServerMessageModel mj_objectWithKeyValues:tempSessionModel.messageDialogHistory];
        
        IMServerMessage *serverMessage = [tempModel getChatMessageFromServerMessageModel];
        
        if (serverMessage) {
            //直接存储服务器返回的最新 系统消息(群助手)
            [self toolDealReceiveServiceMessageForGroupTip:serverMessage];
        }
    }
    
    //获得此时 本地数据库存储的最新申请入群消息
    NoaIMChatMessageModel *sessionLatestMessage = [self toolGetLatestChatMessageWithSessionID:sessionModel.sessionID];
    
    //更新最新消息
    sessionModel.sessionLatestMessage = sessionLatestMessage;
    //注意此时红点需要用服务端同步过来的值，因为上面的存储方法会新增1红点，但是此处不需要自增
    sessionModel.sessionUnreadCount = currentSessionUnread;
    
    //更新会话列表本地数据库
    return sessionModel;
}

//更新会话的 系统消息(支付通知) 信息
- (LingIMSessionModel *)updateSessionPaymentAssistantWith:(LIMSessionModel *)tempSessionModel {
    
    //转数据库存储model
    LingIMSessionModel *sessionModel = [tempSessionModel getSessionModel];
    
    //当前回话未读数
    NSInteger currentSessionUnread = sessionModel.sessionUnreadCount;
    
    //服务器返回的当前最新消息(IMServerMessage) (tempSessionModel.sessionLatestMessage获得的是IMChatMessage)
    if (tempSessionModel.messageDialogHistory && [tempSessionModel.messageDialogHistory isKindOfClass:[NSDictionary class]]) {
        
        LIMServerMessageModel *tempModel = [LIMServerMessageModel mj_objectWithKeyValues:tempSessionModel.messageDialogHistory];
        
        IMServerMessage *serverMessage = [tempModel getChatMessageFromServerMessageModel];
        
        if (serverMessage) {
            //直接存储服务器返回的最新 系统消息(支付通知)
            [self toolDealReceiveServiceMessageForPaymentAssistant:serverMessage];
        }
    }
    
    //获得此时 本地数据库存储的最新申请入群消息
    NoaIMChatMessageModel *sessionLatestMessage = [self toolGetLatestChatMessageWithSessionID:sessionModel.sessionID];
    
    //更新最新消息
    sessionModel.sessionLatestMessage = sessionLatestMessage;
    //注意此时红点需要用服务端同步过来的值，因为上面的存储方法会新增1红点，但是此处不需要自增
    sessionModel.sessionUnreadCount = currentSessionUnread;
    
    //更新会话列表本地数据库
    return sessionModel;
}

/// 服务端 同步敏感词数据
- (void)requestSensitiveContentFromServiceWith:(NSInteger)page {
    dispatch_group_t group = dispatch_group_create();
    //上次更新时间
    NSString *updateTime = [[MMKV defaultMMKV] getStringForKey:[IMSDKManager getTableNameForSensitive]];
    
    __weak typeof(self) weakSelf = self;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setValue:@(page) forKey:@"pageNumber"];
    [params setValue:@(200) forKey:@"pageSize"];
    [params setValue:@(0) forKey:@"pageStart"];
    [params setValue:(updateTime.length > 0 ? updateTime : @"") forKey:@"updateTime"];
    
    [self imSdkUpdateAppSensitiveWith:params onSuccess:^(id _Nullable data, NSString * _Nullable traceId) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)data;
            LingIMSensitivePageModel *model = [LingIMSensitivePageModel mj_objectWithKeyValues:dict];
            if (model.page.records.count > 0) {
                dispatch_group_enter(group);
                dispatch_async(self.imSdkUpdateAppSensitiveQueue, ^{
                    [weakSelf toolSaveLocalSensitiveDataWithSensitiveList:model.page.records];
                    dispatch_group_leave(group);
                });
            }
            
            NSInteger totalPage = model.page.pages;
            NSInteger currentPage = model.page.current;
            if (totalPage > currentPage) {
                //还有未加载的数据
                [weakSelf requestSensitiveContentFromServiceWith:currentPage + 1];
            } else {
                //敏感词数据库同步完成
                [[MMKV defaultMMKV] setString:(model.updateTime.length > 0 ? model.updateTime : @"") forKey:[IMSDKManager getTableNameForSensitive]];
                dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                    [weakSelf.messageDelegate imSdkChatMessageSensitiveSyncFinish];
                });
                return;
            }
        }
    } onFailure:^(NSInteger code, NSString * _Nullable msg, NSString * _Nullable traceId) {
        //敏感词同步服务器错误
        return;
    }];
}
@end
