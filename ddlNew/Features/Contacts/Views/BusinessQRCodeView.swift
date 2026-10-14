//
//  BusinessQRCodeView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import CoreImage.CIFilterBuiltins
import Photos
import AlertToast

/// 二维码内容由真实SDK生成，仅在本机将服务器内容渲染成图片。
struct BusinessQRCodeView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    let groupID: String?
    let title: String
    @State private var image: UIImage?
    @State private var saveMessage: String?
    @State private var showingSaveFeedback = false
    @State private var isSaving = false
    @ObservedObject private var groups = GroupsStore.shared
    @State private var sharingToChat = false
    @ObservedObject private var session = UserSessionStore.shared

    var body: some View {
        MessagingScroll {
            VStack(spacing: 20.zoom()) {
                MessagingCard(padding: 24.zoom()) {
                    VStack(spacing: 12.zoom()) {
                        if groupID == nil, let user = session.currentUser {
                            ContactRecordAvatar(contact: ContactRecord(id: user.userUID, account: user.userName, nickname: user.nickname, avatar: user.avatar), fileHost: OSSConnectionBootstrap.shared.current?.getFileHost, size: 80.zoom())
                            Text(user.nickname).font(.headline).foregroundStyle(MessagingTheme.text)
                            Text("账号：\(user.userName)").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                        } else if let group = groups.groups.first(where: { $0.id == groupID }) {
                            GroupRecordAvatar(group: group, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost)
                            Text(group.name).font(.headline).foregroundStyle(MessagingTheme.text)
                        }
                        if let image {
                            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                                .frame(maxWidth: 256.zoom()).padding(20.zoom()).background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12.zoom())).padding(.vertical, 12.zoom())
                                .accessibilityLabel(groupID == nil ? "我的业务二维码" : "群业务二维码")
                            Divider().overlay(MessagingTheme.divider)
                            Text(groupID == nil ? "扫一扫我的二维码，添加我为好友。" : "扫一扫二维码，加入群聊。")
                                .font(.subheadline).foregroundStyle(MessagingTheme.text).multilineTextAlignment(.center)
                            if !businessStore.qrExpiry.isEmpty { Text("有效期：\(expiryLabel)").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                        } else if businessStore.isSubmitting {
                            Color.clear.frame(minHeight: 240.zoom())
                        } else {
                            Image(systemName: "qrcode").font(.largeTitle).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
                            Text("二维码暂时不可用，请重新生成。").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                            Button("重新生成") { Task { await generate() } }.frame(minHeight: 44)
                        }
                    }.frame(maxWidth: .infinity)
                }
            }.padding(24.zoom())
        }
        .navigationTitle(title)
        .modifier(MessagingPageChrome())
        .messagingFeedbackToast(businessStore.errorMessage)
        .safeAreaInset(edge: .bottom) {
            if let image {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16.zoom()) { saveButton(image); chatShareButton }
                    VStack(spacing: 12.zoom()) { saveButton(image); chatShareButton }
                }.frame(maxWidth: 640).padding(16.zoom()).frame(maxWidth: .infinity).background(MessagingTheme.surface)
            }
        }
        .task { await generate() }
        .toast(isPresenting: Binding(get: { isSaving || businessStore.isSubmitting }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: isSaving ? "正在保存到相册" : "正在生成二维码",
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
        .toast(isPresenting: $showingSaveFeedback, duration: 3) {
            AlertToast(type: .regular, title: saveMessage,
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
        .onChange(of: saveMessage) { message in if message != nil { showingSaveFeedback = true } }
        .sheet(isPresented: $sharingToChat) { if let data = image?.pngData() { ContactsRecipientPickerView(content: .image(data)) } }
    }

    /// 保存与聊天分享沿用旧版底部双操作，大字号时自然改为纵向。
    private func saveButton(_ image: UIImage) -> some View {
        Button { save(image) } label: {
            Label("保存相册", systemImage: "square.and.arrow.down").fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
        }.buttonStyle(MessagingActionButtonStyle(fill: MessagingTheme.surface, foreground: MessagingTheme.accent, border: MessagingTheme.border)).disabled(isSaving || businessStore.isSubmitting)
    }

    /// 分享选择真实聊天接收人。
    private var chatShareButton: some View {
        Button { sharingToChat = true } label: {
            Label("分享", systemImage: "square.and.arrow.up").fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity)
        }.buttonStyle(MessagingActionButtonStyle()).disabled(isSaving || businessStore.isSubmitting)
    }

    /// 旧接口过期值单位为毫秒，只显示实际服务端给定日期。
    private var expiryLabel: String {
        guard let milliseconds = Double(businessStore.qrExpiry), milliseconds > 0 else { return businessStore.qrExpiry }
        return Date(timeIntervalSince1970: milliseconds / 1000).formatted(date: .numeric, time: .standard)
    }

    /// 仅接受SDK返回content，失败或为空时不制造本地UID二维码。
    private func generate() async {
        image = nil; saveMessage = nil
        guard await businessStore.perform(.qrCode(groupID: groupID)), !businessStore.qrContent.isEmpty else { return }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(businessStore.qrContent.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)), let bitmap = CIContext().createCGImage(output, from: output.extent) else { saveMessage = "二维码图片生成失败"; return }
        image = UIImage(cgImage: bitmap)
    }

    /// 只申请相册添加权限，以系统写入回执显示保存结果。
    private func save(_ image: UIImage) {
        guard !isSaving else { return }
        isSaving = true; saveMessage = nil; showingSaveFeedback = false
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { Task { @MainActor in saveMessage = "请在系统设置中允许添加照片"; isSaving = false }; return }
            PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: image) } completionHandler: { success, _ in
                Task { @MainActor in saveMessage = success ? "已保存到相册" : "保存失败，请重试"; isSaving = false }
            }
        }
    }
}
