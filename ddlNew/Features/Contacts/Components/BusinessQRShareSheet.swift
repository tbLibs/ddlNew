//
//  BusinessQRShareSheet.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIKit

/// 系统分享面板只输出当前二维码图片，成功状态由接收应用处理。
struct BusinessQRShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    /// 复用平台分享面板，避免构造假的聊天发送结果。
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [image], applicationActivities: nil) }
    /// 图片快照在打开分享时固定，无额外状态同步。
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
