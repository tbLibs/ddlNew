//
//  LegacyRemoteImageProcessor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Kingfisher
import UIKit

/// 好友、群头像和聊天图片共用旧端媒体解码，普通图片仍交给Kingfisher。
struct LegacyRemoteImageProcessor: ImageProcessor {
    let identifier = "ddlNew.legacy-media.v1"

    /// 先解除XOR/AES包装再解析图片或GIF，损坏格式返回占位而非错误图片。
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case .image(let image): return image
        case .data(let data):
            guard let decoded = try? LegacyChatMediaCodec.decode(data) else { return nil }
            return DefaultImageProcessor.default.process(item: .data(decoded), options: options)
        }
    }
}
