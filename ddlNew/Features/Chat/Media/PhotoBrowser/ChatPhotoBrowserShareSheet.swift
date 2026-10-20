import SwiftUI

/// 挂在预览页的 sheet 上，由系统展示文件分享选项。
struct ChatPhotoBrowserShareSheet: UIViewControllerRepresentable {
    let file: URL
    let onComplete: (String?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, error in
            let feedback = error == nil ? nil : "分享失败，请重试"
            Task { @MainActor in onComplete(feedback) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
