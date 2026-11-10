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
        var fragments = ChatEmojiCatalog.runs(in: value).map { run -> Text in
            if let item = run.emoji, let image = ChatEmojiArtwork.image(item.image, size: size) {
                return Text(Image(uiImage: image)).baselineOffset(-3)
            }
            return Text(verbatim: run.text)
        }
        // Text + Text保留嵌套结构。逐个累加会使大量表情在SwiftUI解析时栈溢出。
        // 相邻片段逐层合并，保持原顺序和全部内容，把嵌套深度从N降为log2(N)。
        while fragments.count > 1 {
            var merged: [Text] = []
            merged.reserveCapacity((fragments.count + 1) / 2)
            for index in stride(from: 0, to: fragments.count, by: 2) {
                merged.append(index + 1 < fragments.count
                    ? fragments[index] + fragments[index + 1]
                    : fragments[index])
            }
            fragments = merged
        }
        return fragments.first ?? Text("")
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
