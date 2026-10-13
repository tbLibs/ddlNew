//
//  ChatFilePreview.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import QuickLook

struct ChatFilePreview: UIViewControllerRepresentable {
    let file: URL
    /// 系统QuickLook提供支持的真实文件格式预览。
    func makeUIViewController(context: Context) -> QLPreviewController { let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller }
    /// 下载完成文件变更后刷新系统预览。
    func updateUIViewController(_ controller: QLPreviewController, context: Context) { context.coordinator.file = file; controller.reloadData() }
    /// 数据源只暴露当前用户已下载的文件。
    func makeCoordinator() -> Coordinator { Coordinator(file) }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var file: URL
        /// 保存当前用户隔离后的真实文件URL。
        init(_ file: URL) { self.file = file }
        /// 系统详情只预览本次选中的一个文件。
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        /// QuickLook不从原聊天的本地路径拼接其他用户资源。
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { file as NSURL }
    }
}
