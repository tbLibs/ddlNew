//
//  NetworkImageDownloader.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import Kingfisher

/// 网络图片统一使用 Kingfisher，缓存和请求去重由库管理。
@MainActor
enum NetworkImageDownloader {
    private static var downloaders: [String: ImageDownloader] = [:]

    /// 与业务接口一致：临时信任导航文件 Host 的无效证书，其他 Host 仍使用系统校验。
    /// 服务端修复证书后应移除 trustedHosts，不能全局放开所有图片服务器。
    static func downloader(for fileHost: URL?) -> ImageDownloader {
        guard let host = fileHost?.host else { return .default }
        if let downloader = downloaders[host] { return downloader }
        let downloader = ImageDownloader(name: "navigation-images-\(host)")
        downloader.trustedHosts = [host]
        downloaders[host] = downloader
        return downloader
    }
}
