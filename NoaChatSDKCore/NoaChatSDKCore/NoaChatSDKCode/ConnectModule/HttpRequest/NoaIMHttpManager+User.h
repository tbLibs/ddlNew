//
//  NoaIMHttpManager+User.h
//  NoaChatSDKCore
//
//  Created by Candy on 2026/12/20.
//

//查询用户(用户搜索)[1.0.11不用]
//#define User_Search_By_UserName_Url             @"/biz/search/searchUserByUserName"
//查询用户新接口(用户搜索)[1.0.11开始使用]
#define User_Search_1_0_11_By_UserName_Url      @"/biz/search/v1_0_11/searchUserByUserName"
//获取用户是否有相应的操作权限
#define User_Get_User_Authority_Url             @"/biz/user/getUserAuthority"
//获取STS TOKEN
#define User_Get_File_Upload_Tolen_Url          @"/zim-file/file/v1/getSTS"

//更新用户头像
#define User_Update_Avatar_Url                  @"/biz/user/updateAvatar"
//更新用户昵称
#define User_Update_Nickname_Url                @"/biz/user/updateNickname"
//更新用户账号
#define User_Update_UserName_Url                @"/biz/user/updateUserName"
//获取用户信息
#define User_Get_UserInfo_Url                   @"/biz/user/userInfo"
//获取用户消息提醒信息
#define User_Get_Message_Remind_Url             @"/biz/system/getSystemSetByuId"
//设置用户消息提醒方式
#define User_Message_Remind_Set_Url             @"/biz/system/setSystemSet"
//获取 我的收藏 列表
#define User_Get_MyCollection_List_Url          @"/biz/collect/pageList"
//删除 我的收藏 列表中某条收藏
#define User_Delete_Single_Collection_Url       @"/biz/collect/delete"

//校验密码是否一致
#define User_Check_User_Password_url            @"/auth/user/checkUserPassword"
//更新密码
#define User_Reset_Password_Url                 @"/auth/user/resetPassword"
//投诉与支持-系统投诉
#define User_Feedback_Url                       @"/biz/feedback/addFeedBack"
//投诉与支持-邀请码投诉
#define Sso_Feedback_Url                       @"/biz/feedback/addCompanyFeedBack"
//获取用户角色权限
#define User_Role_AuthorityList_Url             @"/biz/user/getUserRoleAuthorityList"
//设置离线时长
#define User_setShowOffLineStatus_Url           @"/biz/user/setShowOffLineStatus"
//获取当前用户默认设置
#define User_TranslateDefault_Url               @"/biz/userTranslateDefault"
//上传用户翻译默认设置
#define User_TranslateDefault_upload_Url        @"/biz/userTranslateDefault/upload"

#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoaIMHttpManager (User)

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
/// @param onSuccess 成功回调
/// @param onFailure 失败回调
- (void)userUpdateAvatarWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 更新用户的昵称
/// @param params 操作参数{ nickname:昵称 userUid:当前操作用户 }
- (void)userUpdateNicknameWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 更新用户的账号
/// @param params 操作参数{ userName:账号 userUid:当前操作用户 }
- (void)userUpdateUserNameWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取某个用户信息
/// @param params 操作参数{ userUid:被查询用户 }
- (void)userGetUserInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取用户消息提醒信息
/// @param params 操作参数 { userUid:当前用户 }
- (void)userGetMessageRemindInfoWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 用户消息提醒方式设置
/// @param params 操作参数 { userUid:当前用户 isNewMsgNotify:是否开启消息提醒 0否1是(默认1) isShakeNotice:是否震动提醒 0否1是(默认1) isVoiceNotice:是否声音提醒 0否1是(默认1)}
- (void)userMessageRemindSetWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取 我的收藏 列表
/// @param params 操作参数 { pageNumber:起始页 pageSize:每页数据量 pageStart:起始索引 userUid:操作人 }
- (void)userGetMyCollectionListtWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;


/// 删除 我的收藏 列表中某条收藏
/// @param params 操作参数 { collectId:收藏ID msgId:收藏的消息的消息ID userUid:操作人 }
- (void)userDeleteCollectionMessageWith:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

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


/// 反馈与支持
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
- (void)ssoAddFeedBackWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

#pragma mark - 获取用户角色权限
/**
 @brief 获取用户角色权限
 userUid 用户ID
*/
- (void)getRoleAuthorityListWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

#pragma mark - 设置离线时长
/**
 @brief 设置离线时长
 userUid 用户ID
*/
- (void)setShowOffLineStatusWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

#pragma mark - 获取当前用户默认设置
/**
 @brief 获取当前用户默认设置
 userUid 用户ID
*/
- (void)userTranslateDefaultWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

#pragma mark - 上传用户翻译默认设置
/**
 @brief 上传用户翻译默认设置
 userUid 用户ID
*/
- (void)userTranslateDefaultUploadWith:(NSMutableDictionary *)params onSuccess:(nullable LingIMSuccessCallback)onSuccess onFailure:(nullable LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
