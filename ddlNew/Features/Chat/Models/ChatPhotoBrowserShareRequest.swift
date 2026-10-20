import Foundation

/// 分享面板持有点击时的文件快照，不依附会随菜单关闭/后台清理而消失的预览状态。
struct ChatPhotoBrowserShareRequest: Identifiable {
    let id = UUID()
    let file: URL
}
