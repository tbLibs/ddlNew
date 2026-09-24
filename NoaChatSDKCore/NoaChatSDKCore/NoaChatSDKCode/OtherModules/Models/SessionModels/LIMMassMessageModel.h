//
//  LIMMassMessageModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/4/23.
//

// 会话列表-群发助手-最新的消息Model

#import <Foundation/Foundation.h>
#import <MJExtension/MJExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface LIMMassMessageBodyModel : NSObject
@property (nonatomic, copy) NSString * _Nullable content;//文本消息-文本内容
@property (nonatomic, copy) NSString * _Nullable ext;    //文本消息 图片消息 视频消息 文件消息扩展字段
@property (nonatomic, copy) NSString * _Nullable name;   //图片消息原图地址，视频消息视频地址，文件消息文件名称
@property (nonatomic, copy) NSString * _Nullable iImg;   //图片消息缩略图地址
@property (nonatomic, assign) CGFloat width;             //图片消息原图宽
@property (nonatomic, assign) CGFloat height;            //图片消息原图高
@property (nonatomic, assign) CGFloat size;              //图片消息原图大小，文件消息文件大小
@property (nonatomic, copy) NSString * _Nullable cImg;   //视频消息-视频封面原图地址
@property (nonatomic, assign) CGFloat cWidth;            //视频消息-视频封面原图图宽
@property (nonatomic, assign) CGFloat cHeight;           //视频消息-视频封面原图高
@property (nonatomic, assign) CGFloat length;            //视频消息-视频大小
@property (nonatomic, copy) NSString * _Nullable path;   //文件消息-文件地址
@property (nonatomic, copy) NSString * _Nullable type;   //文件消息-文件类型
@end

@interface LIMMassMessageModel : NSObject
@property (nonatomic, copy) NSString *labelId;//群发组ID
@property (nonatomic, copy) NSString *taskId;//任务ID，该群发组ID下发送的第几条消息
@property (nonatomic, assign) NSInteger mtype;//0文本1图片2视频5文件
@property (nonatomic, copy) NSString *label;//标签
@property (nonatomic, copy) NSString *sendTime;//发送时间 YYYY-MM-dd HH:mm:ss 24小时制 
@property (nonatomic, assign) NSInteger errorCount;//接收失败人数
@property (nonatomic, assign) NSInteger status;//状态1发送中2发送完成3发送失败
@property (nonatomic, strong) LIMMassMessageBodyModel *bodyModel;//消息体内容

@property (nonatomic, assign) NSInteger totalCount;//总人数
@property (nonatomic, strong) NSArray *userUidList;//接收者列表
@property (nonatomic, copy) NSString *userUid;//群发消息发送者ID

@end

NS_ASSUME_NONNULL_END
