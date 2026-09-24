//
//  LingIMTcpCommonTool.h
//  NoaChatSDKCore
//
//  Created by phl on 2025/6/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LingIMTcpCommonTool : NSObject

/// 接口返回的data解密处理
/// - Parameters:
///   - data: 接口返回的数据
///   - url: url地址
+ (id)responseDataDescryptWithDataString:(id)obj url:(NSString *)url;

/// 对象转换为字符串
/// - Parameter obj: 需要转换的对象
+ (NSString *)jsonEncode:(id)obj;

/// 字符串转换为json对象
/// - Parameter jsonString: json字符串
+ (id)jsonDecode:(NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
