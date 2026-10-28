//
//  MineAvatarPicker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/28.
//
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 原生相册/相机只选择一张图片，并提供方形裁剪。
struct MineAvatarPicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        /// 系统裁剪结果优先，取消不产生临时文件或服务器请求。
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
    }
}

/// 头像与旧端一致输出200像素正方形，避免按屏幕scale生成大图。
enum MineAvatarPreparation {
    static func file(from image: UIImage) throws -> URL {
        guard image.size.width > 0, image.size.height > 0 else { throw OwnProfileError.invalid("图片无法读取，请重新选择") }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let result = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            let scale = max(200 / image.size.width, 200 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (200 - size.width) / 2, y: (200 - size.height) / 2, width: size.width, height: size.height))
        }
        for step in stride(from: 10, through: 1, by: -1) {
            if let data = result.jpegData(compressionQuality: CGFloat(step) / 10), data.count <= 50 * 1024 {
                let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                try data.write(to: file, options: .atomic)
                return file
            }
        }
        throw OwnProfileError.invalid("图片处理失败，请选择其他图片")
    }
}
