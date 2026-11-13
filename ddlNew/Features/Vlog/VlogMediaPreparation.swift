import UIKit
import AVFoundation
import ImageIO

nonisolated enum VlogMediaPreparation {
    static func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vlog-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func image(_ image: UIImage) throws -> VlogPrepared {
        try Task.checkCancellation()
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let ratio = min(1, 4096 / max(pixels.width, pixels.height))
        let size = CGSize(width: max(1, pixels.width * ratio), height: max(1, pixels.height * ratio))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        let root = try makeDirectory(); var success = false
        defer { if !success { try? FileManager.default.removeItem(at: root) } }
        guard let bytes = normalized.jpegData(compressionQuality: 0.9) else { throw VlogError.invalidMedia }
        let file = root.appendingPathComponent("media.jpg")
        try bytes.write(to: file)
        guard let preview = thumbnail(file, maximum: 640)?.jpegData(compressionQuality: 0.8) else { throw VlogError.invalidMedia }
        try preview.write(to: root.appendingPathComponent("thumbnail.jpg"))
        try Task.checkCancellation()
        success = true
        return VlogPrepared(directory: root, kind: .photo, filename: "media.jpg", bytes: Int64(bytes.count), width: size.width, height: size.height, duration: 0)
    }
    static func prepare(file: URL, kind: VlogKind) async throws -> VlogPrepared {
        try Task.checkCancellation()
        if kind == .photo {
            guard let image = thumbnail(file, maximum: 4096) else { throw VlogError.invalidMedia }
            return try self.image(image)
        }
        let ext = file.pathExtension.lowercased()
        guard ["mov", "mp4", "m4v"].contains(ext) else { throw VlogError.invalidMedia }
        let root = try makeDirectory(); var success = false
        defer { if !success { try? FileManager.default.removeItem(at: root) } }
        let name = "media." + ext
        let media = root.appendingPathComponent(name)
        try FileManager.default.copyItem(at: file, to: media)
        let asset = AVURLAsset(url: media)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0,
              let track = try await asset.loadTracks(withMediaType: .video).first else { throw VlogError.invalidMedia }
        let natural = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let bounds = CGRect(origin: .zero, size: natural).applying(transform)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 640, height: 640)
        let preview = try generator.copyCGImage(at: .zero, actualTime: nil)
        guard let data = UIImage(cgImage: preview).jpegData(compressionQuality: 0.8) else { throw VlogError.invalidMedia }
        try data.write(to: root.appendingPathComponent("thumbnail.jpg"))
        try Task.checkCancellation()
        let bytes = Int64(try media.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        success = true
        return VlogPrepared(directory: root, kind: .video, filename: name, bytes: bytes, width: abs(bounds.width), height: abs(bounds.height), duration: duration)
    }
    /// ImageIO downsamples at decode time; the grid never decodes full-resolution originals.
    static func thumbnail(_ file: URL, maximum: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximum,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
