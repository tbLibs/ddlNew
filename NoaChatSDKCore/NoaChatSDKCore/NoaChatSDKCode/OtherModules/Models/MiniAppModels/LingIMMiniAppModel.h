//
//  LingIMMiniAppModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/21.
//

#import <Foundation/Foundation.h>

@interface LingIMMiniAppModel : NSObject
//小程序唯一标识
@property(nonatomic, copy) NSString *qaUuid;
//小程序头像
@property (nonatomic, copy) NSString *qaAppPic;
//小程序地址
@property (nonatomic, copy) NSString *qaAppUrl;
//小程序名字
@property (nonatomic, copy) NSString *qaName;
//小程序设置密码(0关闭1开启)
@property (nonatomic, assign) NSInteger qaPwdOpen;
//小程序创建时间
@property (nonatomic, copy) NSString *qaCreateDateTime;
//小程序更新时间
@property (nonatomic, copy) NSString *qaUpdateDateTime;
//小程序创建者
@property (nonatomic, copy) NSString *qaOwnerUid;
//小程序访问密码(不存储)
@property (nonatomic, copy) NSString *qaPwd;
//是否允许用户删除（0=不允许，1=允许）
@property (nonatomic,assign) NSInteger allowUserDelete;
//应用类型，0=系统应用，1=用户手机端新建应用
@property(nonatomic,assign) NSInteger appType;

@end
