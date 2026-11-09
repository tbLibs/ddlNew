//
//  MiniAppEditorView.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI
import AVFoundation

/// 应用编辑保留本地草稿，只有服务器受理才关闭；选图取消不产生上传。
struct MiniAppEditorView: View {
    @ObservedObject var store: MiniAppsStore
    let record: MiniAppRecord?
    let saved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MiniAppDraft
    @State private var image: UIImage?
    @State private var picker: IconSource?
    @State private var choosingIcon = false
    @State private var confirmDiscard = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var appeared = false
    private let original: MiniAppDraft
    init(store: MiniAppsStore, record: MiniAppRecord?, password: String = "", saved: @escaping () -> Void) {
        self.store = store; self.record = record; self.saved = saved
        var value = MiniAppDraft(record: record); value.password = password; value.passwordBefore = password
        original = value; _draft = State(initialValue: value)
    }
    private enum IconSource: String, Identifiable { case library, camera; var id: String { rawValue } }
    private var dirty: Bool {
        image != nil || draft.name != original.name || draft.url != original.url || draft.password != original.password || draft.passwordEnabled != original.passwordEnabled
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { choosingIcon = true } label: {
                        HStack(spacing: 16) {
                            if let image { Image(uiImage: image).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true) }
                            else { MiniAppIcon(resource: draft.icon, size: 56) }
                            Text("更换应用图标").foregroundStyle(MessagingTheme.accent)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
                        }.frame(minHeight: 64).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Section("应用信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("名称").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                        TextField("应用名称", text: $draft.name, prompt: Text("应用名称").foregroundColor(MessagingTheme.secondaryText)).accessibilityLabel("应用名称")
                    }.padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("网址").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                        TextField("网站地址", text: $draft.url, prompt: Text("example.com").foregroundColor(MessagingTheme.secondaryText)).keyboardType(.URL).textContentType(.URL)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel("应用网址")
                    }.padding(.vertical, 4)
                }
                Section {
                    Toggle("访问密码", isOn: $draft.passwordEnabled)
                    if draft.passwordEnabled {
                        SecureField("设置访问密码", text: $draft.password, prompt: Text("设置访问密码").foregroundColor(MessagingTheme.secondaryText)).textContentType(.newPassword).accessibilityLabel("设置访问密码")
                    }
                } footer: { Text("开启后，打开或编辑此应用需要验证密码。").foregroundStyle(MessagingTheme.secondaryText) }
                if let message = error { Section { Text(message).foregroundStyle(MessagingTheme.error) } }
            }
            .disabled(store.isBusy)
            .navigationTitle(record == nil ? "添加应用" : "编辑应用").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if dirty { confirmDiscard = true } else { dismiss() } }.disabled(store.isBusy) }
                ToolbarItem(placement: .confirmationAction) { Button("保存", action: save).disabled(store.isBusy || draft.validationMessage != nil) }
            }
            .confirmationDialog("更换应用图标", isPresented: $choosingIcon, titleVisibility: .visible) {
                Button("从相册选择") { picker = .library }
                if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("拍照", action: requestCamera) }
                Button("取消", role: .cancel) {}
            }
            .alert("放弃未保存的修改？", isPresented: $confirmDiscard) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { dismiss() }
            }
            .fullScreenCover(item: $picker) { source in
                MineAvatarPicker(source: source == .camera ? .camera : .photoLibrary) { value in
                    if let value { image = value }; picker = nil
                }.ignoresSafeArea()
            }
            .messagingLoadingToast(store.isBusy, title: "正在保存应用")
        }.tint(MessagingTheme.accent).interactiveDismissDisabled(dirty || store.isBusy)
            .onAppear { appeared = true }
            .onDisappear { if picker == nil { appeared = false; task?.cancel(); draft.password = ""; draft.passwordBefore = "" } }
    }
    private func requestCamera() {
        task = Task { @MainActor in
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard appeared, !Task.isCancelled else { return }
            if allowed { picker = .camera } else { error = "请在系统设置中允许访问相机，或从相册选择图标" }
        }
    }
    private func save() {
        guard !store.isBusy else { return }; error = nil
        task = Task { @MainActor in
            do {
                let file = try image.map { try MineAvatarPreparation.file(from: $0) }
                let success = await store.save(draft, editing: record, iconFile: file)
                guard !Task.isCancelled else { return }
                if success { saved(); dismiss() } else { error = store.feedback ?? "保存失败，请重试" }
            } catch { self.error = error.localizedDescription }
        }
    }
}
