//
//  BusinessQRCameraView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import AVFoundation

/// 相机只识别QR字符串，后续业务类型由服务端转换接口决定。
struct BusinessQRCameraView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void
    /// 原生相机视图在sheet出现时才创建捕获会话。
    func makeUIViewController(context: Context) -> BusinessQRCameraController {
        let controller = BusinessQRCameraController(); controller.onCode = onCode; controller.onError = onError; return controller
    }
    /// 回调随SwiftUI更新，捕获会话不重复创建。
    func updateUIViewController(_ uiViewController: BusinessQRCameraController, context: Context) { uiViewController.onCode = onCode; uiViewController.onError = onError }
    /// 返回或关闭时立即停止相机，避免后台耗电。
    static func dismantleUIViewController(_ uiViewController: BusinessQRCameraController, coordinator: ()) { uiViewController.stop() }
}
