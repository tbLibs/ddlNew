//
//  MineProfileView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/28.
//
import SwiftUI
import Kingfisher
import UIAdapter
import AVFoundation

/// 编辑页持有本次AUTH快照，导航子页和系统选图共用同一提交状态。
struct MineProfileView: View {
    let context: ChatContext
    @StateObject private var editor: OwnProfileStore
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @ObservedObject private var runtime = ChatRuntime.shared
    @Environment(\.dismiss) private var dismiss
    @State private var choosingAvatar = false
    @State private var picker: AvatarSource?
    @State private var pendingImage: UIImage?
    @State private var errorMessage: String?
    @State private var uploadTask: Task<Void, Never>?
    @State private var cameraPermissionPending = false
    @State private var editingNickname = false
    @State private var active = true

    init(context: ChatContext, nickname: String) {
        self.context = context
        _editor = StateObject(wrappedValue: OwnProfileStore(context: context, nickname: nickname,
            client: SDKOwnProfileClient(), isCurrent: { ChatRuntime.shared.isCurrent($0) }))
    }

    var body: some View {
        NavigationStack {
            MessagingScroll {
                MessagingCard(padding: 0) {
                    VStack(spacing: 0) {
                        Button { errorMessage = nil; choosingAvatar = true } label: {
                            HStack(spacing: 16.zoom()) {
                                Text("头像").foregroundStyle(MessagingTheme.text)
                                Spacer(minLength: 0)
                                avatar
                                chevron
                            }.padding(16.zoom()).contentShape(Rectangle())
                        }.buttonStyle(MessagingRowStyle()).accessibilityLabel("修改头像")
                        Divider()
                        Button {
                            editor.beginNickname(session.currentUser?.nickname ?? "")
                            editingNickname = true
                        } label: {
                            row("昵称", value: session.currentUser?.nickname ?? "", editable: true)
                        }.buttonStyle(MessagingRowStyle()).accessibilityLabel("修改昵称")
                        Divider()
                        row("账号", value: session.currentUser?.userName ?? "", editable: false)
                    }
                }.padding(16.zoom()).disabled(editor.busy || cameraPermissionPending)
            }
            .navigationTitle("编辑个人资料")
            .modifier(MessagingPageChrome())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() }.disabled(editor.busy) }
            }
            .navigationDestination(isPresented: $editingNickname) { MineNicknameEditor(editor: editor) }
            .confirmationDialog("修改头像", isPresented: $choosingAvatar, titleVisibility: .visible) {
                Button("从相册选择") { picker = .library }
                if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("拍照") { requestCamera() } }
                Button("取消", role: .cancel) {}
            }
            .fullScreenCover(item: $picker, onDismiss: uploadSelectedImage) { source in
                MineAvatarPicker(source: source == .camera ? .camera : .photoLibrary) { image in
                    pendingImage = image; picker = nil
                }.ignoresSafeArea()
            }
            .messagingLoadingToast(editor.busy && !editingNickname, title: "正在更新头像")
            .messagingFeedbackToast(errorMessage ?? editor.feedback, isEnabled: !editingNickname)
        }
        .tint(HomeTheme.forest)
        .interactiveDismissDisabled(editor.busy)
        .onAppear {
            active = true
            let owner = editor
            ChatRuntime.shared.registerCleanup(owner: owner) { [weak owner] in owner?.close() }
        }
        .onChange(of: runtime.revision) { _ in
            guard !runtime.isCurrent(context) else { return }
            pendingImage = nil; picker = nil; uploadTask?.cancel(); editor.close(); dismiss()
        }
        .onDisappear {
            if picker == nil { active = false; uploadTask?.cancel(); editor.close(); pendingImage = nil }
        }
    }

    /// 当前登录资料更新会立即刷新头像，并保持现有解包下载链路。
    private var avatar: some View {
        let host = connection.current?.getFileHost
        return KFImage(RemoteAvatarURL.resolve(session.currentUser?.avatar ?? "", relativeTo: host))
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 64.zoom(), height: 64.zoom())))
            .placeholder { Image(systemName: "person.fill").foregroundStyle(HomeTheme.forest).frame(width: 64.zoom(), height: 64.zoom()).background(HomeTheme.mintSurface) }
            .resizable().scaledToFill().frame(width: 64.zoom(), height: 64.zoom()).clipShape(Circle()).accessibilityHidden(true)
    }

    private var chevron: some View { Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true) }

    /// 账号只读；长昵称可换行，行触点不低于44点。
    private func row(_ title: String, value: String, editable: Bool) -> some View {
        HStack(spacing: 16.zoom()) {
            Text(title).foregroundStyle(MessagingTheme.text)
            Spacer(minLength: 0)
            Text(value.isEmpty ? "未设置" : value).foregroundStyle(MessagingTheme.secondaryText)
                .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
            if editable { chevron }
        }.padding(16.zoom()).frame(minHeight: 54.zoom()).contentShape(Rectangle())
    }

    /// 只在用户选择拍照后请求权限，迟到授权不得在新会话弹出相机。
    private func requestCamera() {
        cameraPermissionPending = true
        Task { @MainActor in
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionPending = false
            guard active, runtime.isCurrent(context), !Task.isCancelled else { return }
            if granted { picker = .camera }
            else { errorMessage = "相机权限未开启，请在系统设置中允许访问相机" }
        }
    }

    /// 等系统选图完整退出后再显示上传反馈，选择取消不触发提交。
    private func uploadSelectedImage() {
        guard let image = pendingImage else { return }
        pendingImage = nil
        guard runtime.isCurrent(context) else { return }
        do {
            let file = try MineAvatarPreparation.file(from: image)
            uploadTask = Task { _ = await editor.saveAvatar(file) }
        } catch { errorMessage = error.localizedDescription }
    }

    private enum AvatarSource: String, Identifiable { case library, camera; var id: String { rawValue } }
}

/// 昵称保存失败留在编辑页并保留输入，成功才返回资料页。
private struct MineNicknameEditor: View {
    @ObservedObject var editor: OwnProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MessagingScroll {
            VStack(alignment: .leading, spacing: 12.zoom()) {
                MessagingCard {
                    HStack(alignment: .top) {
                        TextField("请输入昵称", text: $editor.nickname, axis: .vertical)
                            .lineLimit(1...4).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .accessibilityIdentifier("mine.nickname")
                        Button { editor.nickname = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                        }.accessibilityLabel("清空昵称").foregroundStyle(MessagingTheme.secondaryText)
                    }
                }
                Text("\(editor.normalizedNickname.utf16.count)/30")
                    .font(.footnote).foregroundStyle(editor.normalizedNickname.utf16.count > 30 ? .red : MessagingTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("最多30个字符，部分表情占2个或更多字符。")
                    .font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
            }.padding(16.zoom()).disabled(editor.busy)
        }
        .navigationTitle("修改昵称").modifier(MessagingPageChrome())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { Task { if await editor.saveNickname() { dismiss() } } }
                    .disabled(!editor.canSaveNickname)
            }
        }
        .messagingLoadingToast(editor.busy, title: "正在保存昵称")
        .messagingFeedbackToast(editor.feedback)
    }
}
