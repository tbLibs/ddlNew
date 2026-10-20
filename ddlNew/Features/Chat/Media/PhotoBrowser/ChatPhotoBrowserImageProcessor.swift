//
//  ChatPhotoBrowserImageProcessor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import Kingfisher
import UIKit

/// 静态大图限制解码像素，GIF 保留动画数据；预取和展示共用同一缓存键。
struct ChatPhotoBrowserImageProcessor: ImageProcessor {
    let identifier = "ddlNew.gallery.2048.v1"

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        if case .data(let data) = item, data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return DefaultImageProcessor.default.process(item: item, options: options)
        }
        return DownsamplingImageProcessor(size: CGSize(width: 2048, height: 2048)).process(item: item, options: options)
    }

    static var options: KingfisherOptionsInfo {
        [.processor(Self()), .scaleFactor(1), .backgroundDecode, .cacheMemoryOnly, .memoryCacheExpiration(.seconds(120))]
    }

    /// 在邻页尚未进入屏幕时解码本地文件，避免把处理推迟到滑动中途。
    @MainActor static func prefetch(_ file: URL) -> (() -> Void) {
        let prefetcher = ImagePrefetcher(urls: [file], options: options)
        prefetcher.start()
        return { prefetcher.stop() }
    }
}
