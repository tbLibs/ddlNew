//
//  ZDateRequestTool.m
//  DateDemo
//
//  Created by Candy on 2023/8/4.
//

#import "ZDateRequestTool.h"
#import <AFNetworking/AFNetworking.h>

@implementation ZDateRequestTool

+ (void)configDefaultServerTime {
    [NSDate getDefaultServerTimeFromSystem];
}

+ (void)requestDate {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.connectionProxyDictionary = @{}; // 关闭系统代理
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://www.baidu.com"] sessionConfiguration:config];
    [manager HEAD:@"https://www.baidu.com" parameters:nil headers:nil success:^(NSURLSessionDataTask * _Nonnull task) {
        [NSDate getMillisecondTimeFromServerWith:task.response];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [NSDate getMillisecondTimeFromServerWith:task.response];
    }];
//    [[AFHTTPSessionManager manager] HEAD:@"https://www.google.com" parameters:nil headers:nil success:^(NSURLSessionDataTask * _Nonnull task) {
//        [NSDate getMillisecondTimeFromServerWith:task.response];
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//        [NSDate getMillisecondTimeFromServerWith:task.response];
//    }];
}

@end
