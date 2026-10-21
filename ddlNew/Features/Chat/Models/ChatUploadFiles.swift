//
//  ChatUploadFiles.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation

/// 上传原件由应用目录持有，系统临时目录清理不能让失败消息失去重传数据。
enum ChatUploadFiles {
    nonisolated static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatUploads", isDirectory: true)
    }

    nonisolated static func localURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let url = (path.hasPrefix("ddlNewUpload:")
            ? directory.appendingPathComponent(String(path.dropFirst("ddlNewUpload:".count)))
            : URL(fileURLWithPath: path)).standardizedFileURL
        return url.path.hasPrefix(directory.standardizedFileURL.path + "/") ? url : nil
    }

    /// SDK只保存应用目录相对路径，覆盖安装后沙盒根路径变化仍能恢复。
    nonisolated static func storedPath(_ file: URL?) -> String? {
        guard let file, let url = localURL(file.path) else { return nil }
        return "ddlNewUpload:" + String(url.path.dropFirst(directory.standardizedFileURL.path.count + 1))
    }

    /// 已保留的原件重试时原位使用；首次发送复制到独立目录，失败继续保留。
    nonisolated static func retain(_ attachment: ChatAttachment) throws -> ChatAttachment {
        if localURL(attachment.file.path) != nil { return attachment }
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var excluded = folder; try excluded.setResourceValues(values)
            let file = folder.appendingPathComponent("media").appendingPathExtension(attachment.file.pathExtension)
            try FileManager.default.copyItem(at: attachment.file, to: file)
            var preview: URL?
            if let source = attachment.previewFile {
                let target = folder.appendingPathComponent("cover").appendingPathExtension(source.pathExtension)
                try FileManager.default.copyItem(at: source, to: target); preview = target
            }
            return ChatAttachment(file: file, type: attachment.type, name: attachment.name, bytes: attachment.bytes,
                duration: attachment.duration, width: attachment.width, height: attachment.height, previewFile: preview)
        } catch { try? FileManager.default.removeItem(at: folder); throw error }
    }

    /// 只删除本模块创建的单条目录，不接受其他本机路径。
    nonisolated static func remove(_ file: URL?) {
        guard let file, let url = localURL(file.path) else { return }
        let folder = url.deletingLastPathComponent()
        guard folder.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL,
              UUID(uuidString: folder.lastPathComponent) != nil else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}
