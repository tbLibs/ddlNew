//
//  BusinessQRCodeView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import Photos

/// 二维码内容由真实SDK生成，仅在本机将服务器内容渲染成图片。
struct BusinessQRCodeView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    let groupID: String?
    let title: String
    @State private var image: UIImage?
    @State private var saveMessage: String?
    @State private var showingShare = false
    @State private var sharingToChat = false
    @ObservedObject private var session = UserSessionStore.shared

    var body: some View {
        ClubScroll {
            VStack(spacing: 20) {
                Text(title).font(.title2.bold())
                if groupID == nil, let user = session.currentUser {
                    ContactRecordAvatar(contact: ContactRecord(id: user.userUID, account: user.userName, nickname: user.nickname, avatar: user.avatar), fileHost: OSSConnectionBootstrap.shared.current?.getFileHost, size: 64)
                    Text(user.nickname).font(.headline)
                    Text(user.userName).font(.subheadline).foregroundStyle(ClubTheme.secondary)
                }
                if let image {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 280).padding(20).background(.white).clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityLabel("业务二维码")
                    if !businessStore.qrExpiry.isEmpty { Text("有效期：\(expiryLabel)").font(.caption).foregroundStyle(ClubTheme.secondary) }
                    HStack { Button("保存到相册") { save(image) }; Button("分享给聊天") { sharingToChat = true }; Button("系统分享") { showingShare = true } }.buttonStyle(.bordered)
                } else if businessStore.isSubmitting { ProgressView("正在生成二维码") }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
                if let saveMessage { Text(saveMessage).foregroundStyle(ClubTheme.secondary) }
                Button("重新生成") { Task { await generate() } }.disabled(businessStore.isSubmitting)
            }.padding(24)
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
        .task { await generate() }
        .sheet(isPresented: $sharingToChat) { if let data = image?.jpegData(compressionQuality: 1) { ContactsRecipientPickerView(content: .image(data)) } }
        .sheet(isPresented: $showingShare) { if let image { BusinessQRShareSheet(image: image) } }
    }

    /// 旧接口过期值单位为毫秒，只显示实际服务端给定日期。
    private var expiryLabel: String {
        guard let milliseconds = Double(businessStore.qrExpiry), milliseconds > 0 else { return businessStore.qrExpiry }
        return Date(timeIntervalSince1970: milliseconds / 1000).formatted(date: .numeric, time: .standard)
    }

    /// 仅接受SDK返回content，失败或为空时不制造本地UID二维码。
    private func generate() async {
        image = nil
        guard await businessStore.perform(.qrCode(groupID: groupID)), !businessStore.qrContent.isEmpty else { return }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(businessStore.qrContent.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)), let bitmap = CIContext().createCGImage(output, from: output.extent) else { saveMessage = "二维码图片生成失败"; return }
        image = UIImage(cgImage: bitmap)
    }

    /// 只申请相册添加权限，以系统写入回执显示保存结果。
    private func save(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { Task { @MainActor in saveMessage = "请在系统设置中允许添加照片" }; return }
            PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) } completionHandler: { success, _ in
                Task { @MainActor in saveMessage = success ? "已保存到相册" : "保存失败，请重试" }
            }
        }
    }
}
