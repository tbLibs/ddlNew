//
//  LegacyRemoteImageCacheSerializer.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Kingfisher

/// 原下载字节有旧包装时，从已解码图片决定缓存格式，避免GIF被误存成PNG。
struct LegacyRemoteImageCacheSerializer: CacheSerializer {
    /// 普通图片沿用原格式；旧包装不作为格式依据，保留图片内嵌的GIF动画数据。
    func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        let wrapped = original?.prefix(3) == Data("XOR".utf8) || original?.prefix(3) == Data("AES".utf8)
        return DefaultCacheSerializer.default.data(with: image, original: wrapped ? nil : original)
    }

    /// 缓存已经保存为真实图片格式，直接复用Kingfisher的图片创建选项。
    func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        DefaultCacheSerializer.default.image(with: data, options: options)
    }
}
