//
//  ChatAttachmentPreparation.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import UIKit
import AVFoundation

/// 媒体准备只生成本机文件，不产生任何成功消息。
enum ChatAttachmentPreparation {
    /// UIKit重绘矫正图片方向，>30MiB或最长边>25000按旧规则转文件。
    nonisolated static func image(_ data: Data, original: Bool = false) throws -> ChatAttachment {
        guard let image = UIImage(data: data) else { throw ChatClientError.unavailable("无法读取图片，请重新选择") }
        let fallback = data.count > 30 * 1024 * 1024 || max(image.size.width * image.scale, image.size.height * image.scale) > 25000
        let gif = data.starts(with: [0x47, 0x49, 0x46])
        let imageExtension = data.starts(with: [0x89, 0x50]) ? "png" : gif ? "gif" : "jpg"
        let name = UUID().uuidString + (fallback || gif || original ? "." + imageExtension : ".jpg")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if fallback { try data.write(to: file); return ChatAttachment(file: file, type: 5, name: "图片." + imageExtension, bytes: Int64(data.count)) }
        if gif || original { try data.write(to: file); return ChatAttachment(file: file, type: 1, name: name, bytes: Int64(data.count), width: image.size.width, height: image.size.height) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let encoded = upright.jpegData(compressionQuality: 0.88) else { throw ChatClientError.unavailable("图片转换失败") }
        try encoded.write(to: file)
        return ChatAttachment(file: file, type: 1, name: name, bytes: Int64(encoded.count), width: size.width, height: size.height)
    }

    /// 文件选择拷贝到当前任务临时目录，系统安全书签结束后仍可上传。
    nonisolated static func file(_ source: URL) throws -> ChatAttachment {
        let allowed = source.startAccessingSecurityScopedResource(); defer { if allowed { source.stopAccessingSecurityScopedResource() } }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        let size = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return ChatAttachment(file: destination, type: 5, name: source.lastPathComponent, bytes: Int64(size))
    }

    /// 视频独立生成封面，不把封面URI错填成原视频资源。
    nonisolated static func video(_ source: URL) async throws -> ChatAttachment {
        var result = try file(source)
        let asset = AVURLAsset(url: result.file)
        let duration = try await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        let image = UIImage(cgImage: cgImage)
        let preview = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let data = image.jpegData(compressionQuality: 0.75) else { throw ChatClientError.unavailable("视频封面转换失败") }
        try data.write(to: preview)
        result = ChatAttachment(file: result.file, type: 2, name: result.name, bytes: result.bytes, duration: duration.seconds, width: image.size.width, height: image.size.height, previewFile: preview)
        return result
    }
}
