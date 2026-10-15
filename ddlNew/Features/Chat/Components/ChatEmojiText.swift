//
//  ChatEmojiText.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import UIKit

/// 收发正文均识别旧端标记，未知方括号文本和系统Unicode emoji原样显示。
struct ChatEmojiText: View {
    let value: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 22

    var body: some View {
        rendered.accessibilityLabel(value)
    }

    private var rendered: Text {
        ChatEmojiCatalog.runs(in: value).reduce(Text("")) { result, run in
            if let item = run.emoji, let image = ChatEmojiArtwork.image(item.image, size: size) {
                return result + Text(Image(uiImage: image)).baselineOffset(-3)
            }
            return result + Text(verbatim: run.text)
        }
    }
}

/// 图片按字号缩放后缓存，避免每个气泡反复创建绘图上下文。
@MainActor private enum ChatEmojiArtwork {
    static let cache = NSCache<NSString, UIImage>()
    static func image(_ name: String, size: CGFloat) -> UIImage? {
        let key = "\(name)-\(size)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let source = UIImage(named: name) else { return nil }
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            source.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        cache.setObject(image, forKey: key); return image
    }
}
