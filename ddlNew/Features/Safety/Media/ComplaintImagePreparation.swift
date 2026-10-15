//
//  ComplaintImagePreparation.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 证据图片沿旧端转为JPEG并压缩，临时文件仅归当前表单所有。
enum ComplaintImagePreparation {
    nonisolated static func prepare(_ data: Data) throws -> URL {
        try autoreleasepool {
            // 先降采样再解码，九张大图不能同时按原始像素展开；方向变换由ImageIO处理。
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceShouldCacheImmediately: true]
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ComplaintError.invalidInput("证据图片无法读取") }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("complaint-" + UUID().uuidString + ".jpg")
            guard let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw ComplaintError.invalidInput("证据图片处理失败") }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.5] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { try? FileManager.default.removeItem(at: file); throw ComplaintError.invalidInput("证据图片保存失败") }
            return file
        }
    }
}
