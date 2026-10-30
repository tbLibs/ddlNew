//
//  ComplaintView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import PhotosUI
import UIAdapter

/// 系统投诉沿旧表单组织证据与原因；失败保留全部草稿，成功由上层展示Toast。
struct ComplaintView: View {
    let target: ComplaintTarget
    let targetName: String
    var sourceGroupID: String? = nil
    var onSubmitted: () -> Void = {}
    @StateObject private var store = ComplaintStore(client: SDKComplaintClient())
    @State private var draft = ComplaintDraft()
    @State private var picks: [PhotosPickerItem] = []
    @State private var previews: [URL: UIImage] = [:]
    @State private var preparing = false
    @State private var photoTask: Task<Void, Never>?
    @State private var feedback: String?
    @State private var openedContext: ChatContext?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20.zoom()) {
                    Text(targetName.isEmpty ? "系统投诉" : "投诉对象：" + targetName).font(.headline).foregroundStyle(MessagingTheme.text)
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 12.zoom()) {
                            Text("投诉原因").font(.subheadline.weight(.semibold))
                            Picker("投诉原因", selection: $draft.reason) { ForEach(ComplaintReason.allCases) { Text($0.title).tag($0) } }
                                .pickerStyle(.menu).tint(MessagingTheme.accent)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 15)
                                .background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12))
                            evidence
                            Divider()
                            HStack { Text("投诉内容（选填）").font(.subheadline.weight(.semibold)); Spacer(); Text("\(draft.content.utf16.count)/200").font(.caption).monospacedDigit().foregroundStyle(draft.content.utf16.count > 200 ? MessagingTheme.error : MessagingTheme.secondaryText) }
                            TextEditor(text: $draft.content).focused($focused).scrollContentBackground(.hidden).padding(10).frame(minHeight: 120.zoom()).background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("投诉内容，最多200字")
                            if draft.content.utf16.count > 200 { Text("投诉内容最多200字，请精简后提交。").font(.footnote).foregroundStyle(MessagingTheme.error) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10.zoom()) {
                            Text("联系邮箱（必填）").font(.subheadline.weight(.semibold))
                            TextField("用于联系处理结果", text: $draft.email).padding(.horizontal, 15).padding(.vertical, 4).background(HomeTheme.background, in: RoundedRectangle(cornerRadius: 12)).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused).frame(minHeight: 44).accessibilityLabel("联系邮箱")
                            if !draft.email.isEmpty && !draft.hasValidEmail { Text("请输入有效的联系邮箱。").font(.footnote).foregroundStyle(MessagingTheme.error) }
                            Text("请填写可正常收信的邮箱。").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                        }
                    }
                }.frame(maxWidth: 640).frame(maxWidth: .infinity).padding(20)
                    .disabled(preparing || store.isSubmitting)
            }
            .scrollDismissesKeyboard(.interactively).background(MessagingTheme.surface.ignoresSafeArea())
            .navigationTitle("投诉与支持").modifier(MessagingPageChrome())
            .safeAreaInset(edge: .bottom) {
                Button { focused = false; Task { await submit() } } label: { Text("确认提交投诉").frame(maxWidth: .infinity) }
                    .buttonStyle(MessagingActionButtonStyle(fullWidth: true)).disabled(draft.validationMessage != nil || store.isSubmitting || preparing || store.submitted)
                    .frame(maxWidth: 640).frame(maxWidth: .infinity).padding(20).background(MessagingTheme.surface)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { photoTask?.cancel(); store.close(); dismiss() } } }
            .messagingLoadingToast(preparing || store.isSubmitting, title: preparing ? "正在准备证据图片" : "正在提交投诉")
            .messagingFeedbackToast(store.errorMessage ?? feedback)
            .onChange(of: picks) { items in if !items.isEmpty { photoTask?.cancel(); photoTask = Task { await prepare(items) } } }
            .task {
                openedContext = makeContext()
                let owner = store
                ChatRuntime.shared.registerCleanup(owner: owner) { [weak owner] in owner?.close() }
            }
            .onDisappear {
                photoTask?.cancel(); store.close()
                for file in draft.images { try? FileManager.default.removeItem(at: file) }
            }
            .interactiveDismissDisabled(store.isSubmitting || preparing)
        }
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12.zoom()) {
                HStack { Text("图片证据（必填）").font(.subheadline.weight(.semibold)); Spacer(); Text("\(draft.images.count)/9").font(.caption).monospacedDigit().foregroundStyle(MessagingTheme.secondaryText) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84.zoom()), spacing: 12.zoom())], spacing: 12.zoom()) {
                    ForEach(draft.images, id: \.self) { file in
                        ZStack(alignment: .topTrailing) {
                            if let image = previews[file] { Image(uiImage: image).resizable().scaledToFill().frame(height: 96.zoom()).clipped().accessibilityLabel("投诉证据图片") }
                            Button { remove(file) } label: { Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.palette).foregroundStyle(MessagingTheme.text, MessagingTheme.surface).frame(width: 44, height: 44) }.accessibilityLabel("移除证据图片")
                        }.clipShape(RoundedRectangle(cornerRadius: 8.zoom()))
                    }
                    if draft.images.count < 9 {
                        PhotosPicker(selection: $picks, maxSelectionCount: 9 - draft.images.count, matching: .images) {
                            VStack(spacing: 8.zoom()) { Image(systemName: "plus").font(.title2); Text("添加图片").font(.caption) }.frame(maxWidth: .infinity).frame(height: 96.zoom())
                                .foregroundStyle(MessagingTheme.accent).background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 8.zoom()))
                        }.accessibilityLabel("添加投诉证据，最多9张")
                    }
                }
                Text("请上传与投诉相关的图片，最多9张。").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
            }
        }
    }

    /// 逐张处理并检查取消；只有真实可读图片加入草稿，读取失败不占用名额。
    @MainActor private func prepare(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        preparing = true; feedback = nil
        defer { preparing = false; picks = [] }
        do {
            for item in items where draft.images.count < 9 {
                try Task.checkCancellation()
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ComplaintError.invalidInput("无法读取图片，请重新选择") }
                let file = try await Task.detached { try ComplaintImagePreparation.prepare(data) }.value
                guard !Task.isCancelled else { try? FileManager.default.removeItem(at: file); return }
                guard let preview = UIImage(contentsOfFile: file.path) else { try? FileManager.default.removeItem(at: file); throw ComplaintError.invalidInput("无法读取证据图片") }
                previews[file] = preview; draft.images.append(file)
            }
        } catch { if !(error is CancellationError) { feedback = error.localizedDescription } }
    }

    /// 关闭表单只删除该表单创建的临时图片。
    private func remove(_ file: URL) { draft.images.removeAll { $0 == file }; previews.removeValue(forKey: file); try? FileManager.default.removeItem(at: file) }

    /// 提交时复核打开表单时的认证轮次及来源群资格，切号后不得借新身份提交。
    @MainActor private func submit() async {
        guard let context = openedContext, ChatRuntime.shared.isCurrent(context),
              let user = UserSessionStore.shared.currentUser, user.userUID == context.userUID else { feedback = "登录状态已变化，请重新打开页面"; return }
        guard await LoginSessionService.shared.contactBusiness.checkGroupAccess(sourceGroupID), ChatRuntime.shared.isCurrent(context) else { feedback = "当前不允许访问该用户资料"; return }
        if await store.submit(draft, target: target, context: context, nickname: user.nickname, account: user.userName) { onSubmitted(); dismiss() }
    }

    /// 表单出现即绑定认证轮次，旧页面不得在切号后借新身份提交旧目标。
    private func makeContext() -> ChatContext? {
        guard let user = UserSessionStore.shared.currentUser else { return nil }
        let route: ChatRoute
        switch target {
        case .user(let id): route = ChatRoute(id: id, kind: .single, title: targetName, avatarURL: "", sourceGroupID: sourceGroupID)
        case .group(let id): route = ChatRoute(id: id, kind: .group, title: targetName, avatarURL: "")
        case .general: route = ChatRoute(id: user.userUID, kind: .single, title: "系统投诉", avatarURL: "")
        }
        return ChatRuntime.shared.context(for: route)
    }
}
