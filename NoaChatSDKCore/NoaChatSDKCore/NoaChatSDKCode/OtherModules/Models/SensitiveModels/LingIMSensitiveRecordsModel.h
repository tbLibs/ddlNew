//
//  LingIMSensitiveRecordsModel.h
//  NoaChatSDKCore
//
//  Created by Candy on 2023/7/12.
//

#import <Foundation/Foundation.h>
#import <MJExtension/MJExtension.h>

@interface LingIMSensitiveRecordsModel : NSObject

@property (nonatomic, assign) NSInteger filterType; //过滤类型 1:替换过滤
@property (nonatomic, assign) NSInteger keyId; //主键
@property (nonatomic, assign) NSInteger sceneType;//应用场景，0:全部 1:会话文本 2:昵称/群组名称 3:搜索文本
@property (nonatomic, assign) NSInteger status; //状态，0:开启，1:关闭,2:删除
@property (nonatomic, copy) NSString *updateTime;//修改时间
@property (nonatomic, copy) NSString *wordText;//敏感词汇
@property (nonatomic, copy) NSString *decodeWordText;//敏感词汇


@end
