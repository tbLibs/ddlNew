//
//  NoaIMHttpManager+Stickers.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/10/27.
//

#import "NoaIMHttpManager.h"

NS_ASSUME_NONNULL_BEGIN

//获取收藏表情列表(GET)
#define Sticker_Get_Collect_List_Url                @"/biz/stickersCollect/findList"
//添加表情到收藏列表(POST)
#define Sticker_Add_To_CollectList_Url              @"/biz/stickersCollect/add"
//从收藏列表移除表情(POST)
#define Sticker_Remove_From_CollectList_Url         @"/biz/stickersCollect/remove"
//根据表情名称获取表情列表(GET)
#define Sticker_Find_For_Name_Url                   @"/biz/stickers/findList"
//添加表情包(POST)
#define Sticker_Package_Add_Url                     @"/biz/stickersSet/add"
//获取表情包列表 - 用户未下载的表情包(GET)
#define Sticker_UnDownload_Package_Url              @"/biz/stickersSet/findNotUseList"
//获取表情包列表 - 用户正在使用的表情包列表(GET)
#define Sticker_Find_Use_Package_Url                @"/biz/stickersSet/findYetUseList"
//获取表情包表情详情(GET)
#define Sticker_Get_Package_Detail_Url              @"/biz/stickersSet/getInfo"
//根据表情ID查询表情包 - 当前有效的唯一表情包(GET)
#define Sticker_Find_Package_For_StickersId_Url     @"/biz/stickersSet/getInfoByStickersId"
//移除表情包(POST)
#define Sticker_Remove_Used_Package_Url             @"/biz/stickersSet/remove"

@interface NoaIMHttpManager (Stickers)

/// 获取收藏表情列表
/// @param params {lastUpdateTime:最后一次更新时间, pageNumber:起始页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始):, userUid:用户UID}
- (void)userGetCollectStickersList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 添加表情到收藏列表
/// @param params {
/// id:主键(添加自消息是取该表情消里的表情id，如果添加自相册id=0)
/// height:文件高度
/// width:文件宽度
/// size:文件大小
/// sort:排序
/// stickersKey:如果是消息中的表情，对应的是message里面的表情id，如果是来自相册，根据文件路径以及文件大小MD5一个唯一的key
/// contentUrl:原始URL
/// thumbUrl:缩略图URL
/// updateTime:修改时间
/// userUid:用户UID
///}
- (void)userAddStickersToCollectList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 从收藏列表移除表情
/// @param params {idList:被移除的表情id数组, userUid:用户UID}
- (void)userRemoveStickersFromCollectList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 根据表情名称获取表情列表
/// @param params {name:表情名称-为空则查全部未收藏的管理后台上传表情, pageNumber:起始页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始), userUid:用户UID}
- (void)userFindStickersForName:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 添加表情包
/// @param params {tickersSetId:每页数据大小, userUid:用户UID（必传参数}
- (void)userAddStickersPackage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取表情包列表 - 用户未下载的表情包
/// @param params {pageNumber:起始页(从1开始), pageSize:每页数据大小, pageStart:起始索引(从0开始), userUid:用户UID}
- (void)userFindUnUsedStickersPackageList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取表情包列表 - 用户正在使用的表情包列表
/// @param params {lastUpdateTime:用户最后的更新时间 - long时间戳, userUid:用户UID}
- (void)userFindUsedStickersPackageList:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 获取表情包表情详情
/// @param params {stickersSetId:表情包ID, userUid:用户UID}
- (void)userGetStickersPackageDetail:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 根据表情ID查询表情包 - 当前有效的唯一表情包
/// @param params {stickersId:表情包ID, userUid:用户UID}
- (void)userGetPackageFromStickersId:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

/// 移除表情包
/// @param params {stickersSetId:表情包ID, userUid:用户UID}
- (void)userRemoveusedStickersPackage:(NSMutableDictionary * _Nullable)params onSuccess:(LingIMSuccessCallback)onSuccess onFailure:(LingIMFailureCallback)onFailure;

@end

NS_ASSUME_NONNULL_END
