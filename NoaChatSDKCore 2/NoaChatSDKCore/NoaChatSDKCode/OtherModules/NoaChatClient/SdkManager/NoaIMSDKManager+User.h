//
//  NoaIMSDKManager+User.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/21.
//

#import "NoaIMSDKManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMSDKManager (User)

/// 查询用户
///  userName 用户账号
- (void)userSearchWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure;

/// 获取用户是否拥有某些操作的权限
/// @param params 请求参数{userUid:操作人ID, authorityType:ADDFRIEND是否可以添加好友,CREATEGROUP是否可以创建群聊,UPFILE是否可以上传文件,LOGINWEB,LOGINPC,LOGINAPP,LOGINALL}
- (void)userGetUserAuthorityWith:(NSMutableDictionary *)params
                       onSuccess:(LingIMSuccessCallback)onSuccess
                       onFailure:(LingIMFailureCallback)onFailure;

/// 获取STS TOKEN
- (void)userGetFileUploadTokenWithOnSuccess:(LingIMSuccessCallback)onSuccess
                                  onFailure:(LingIMFailureCallback)onFailure;


/// 更新用户的头像
/// @param params 操作参数{ avatar:头像地址 userUid:当前操作用户 }
- (void)userAvatarChangeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 更新用户的昵称
/// @param params 操作参数{ nickname:昵称 userUid:当前操作用户 }
- (void)userNicknameChangeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 更新用户的账号
/// @param params 操作参数{ userName:账号 userUid:当前操作用户 }
- (void)userAccountChangeWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取某个用户信息
/// @param params 操作参数{ userUid:被查询用户 }
- (void)getUserInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取用户的消息提醒方式
/// @param params 操作参数 { userUid:当前用户 }
- (void)userGetMessageRemindWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户消息提醒方式设置
/// @param params 操作参数 { userUid:当前用户 isNewMsgNotify:是否开启消息提醒 0否1是(默认1) isShakeNotice:是否震动提醒 0否1是(默认1) isVoiceNotice:是否声音提醒 0否1是(默认1)}
- (void)userMessageRemindSetWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取 我的收藏 列表
/// @param params 操作参数 { pageNumber:起始页 pageSize:每页数据量 pageStart:起始索引 userUid:操作人 }
- (void)userMyCollectionListWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 删除 我的收藏 列表中某条收藏
/// @param params 操作参数 { collectId:收藏ID msgId:收藏的消息的消息ID userUid:操作人 }
- (void)userCollectionMsgDeleteWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/**
 @brief 校验密码是否一致
 encryptKey 密钥
 password 密码
 userUid 用户ID
*/
- (void)userCheckUserPasswordWith:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/**
 @brief 更新密码
 encryptKey 密钥
 password 密码
 userUid 用户ID
*/
- (void)userResetPasswordWith:(NSMutableDictionary * _Nullable)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;


/// 系统投诉接口
/// @param params 操作参数
/*
{
    ufbComment:反馈内容
    ufbContentGroup:反馈内容分类 (1发布违法有害信息 2发布垃圾广告 3种族歧视 4存在文化歧视 5辱骂骚扰 6帐号可能被盗 7其他 8存在欺诈行为)
    ufbImages:反馈图片 以"," 分隔最多9个 列子 http://ccc.com/111/ccc.png,http://ccc.com/222/bbb.png
    ufbTo:所属的IP,域名，邀请码
    ufbToGroupId:投诉的用户id，投诉的用户id 或者 群id 只能有一个
    ufbToType:0:用户投诉，1:群投诉
    ufbToUserId:投诉的用户id，投诉的用户id 或者 群id 只能有一个
    ufbUserEmail:反馈用户邮箱
    userUid:用户ID不可为空
}
 */
- (void)userAddFeedBackWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 邀请码投诉接口
/// - Parameters:
///   - params: 参数
///   - onSuccess: 成功回调
///   - onFailure: 失败回调
- (void)ssoFeedBackWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

/// 获取用户角色权限
///  userUid 用户账号
- (void)userGetRoleAuthorityListWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure;

/// 设置离线时长
///  userUid 用户账号
- (void)userSetShowOffLineStatusWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure;

/// 获取当前用户默认设置
///  userUid 用户账号
- (void)userTranslateDefaultWith:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure;

/// 上传用户翻译默认设置
///  userUid 用户账号
- (void)userTranslateDefaultUpload:(NSMutableDictionary * _Nullable)params
             onSuccess:(LingIMSuccessCallback)onSuccess
             onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
