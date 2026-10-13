//
//  ChatCameraPicker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatCameraPicker: UIViewControllerRepresentable {
    let onResult: (UIImagePickerController.InfoKey, Any?) -> Void
    @Environment(\.dismiss) private var dismiss

    /// 原生相机承担拍摄权限、图片与视频采集。
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController(); controller.sourceType = .camera
        controller.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        controller.videoQuality = .typeHigh; controller.delegate = context.coordinator
        return controller
    }
    /// 相机设置由原生控制器持有，不重置进行中的拍摄。
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    /// Coordinator只处理用户明确拍摄与取消。
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ChatCameraPicker
        /// 持有本次原生拍摄结果回调。
        init(_ parent: ChatCameraPicker) { self.parent = parent }
        /// 完成后先返回媒体结果，后续上传仍需身份与禁言复核。
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let video = info[.mediaURL] { parent.onResult(.mediaURL, video) }
            else { parent.onResult(.originalImage, info[.originalImage]) }
            parent.dismiss()
        }
        /// 用户取消不准备附件也不调用发送。
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
