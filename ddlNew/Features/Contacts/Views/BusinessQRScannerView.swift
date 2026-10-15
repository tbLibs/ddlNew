//
//  BusinessQRScannerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import PhotosUI
import CoreImage
import AlertToast

/// 业务扫码只到用户资料或群申请，不恢复导航和PC认证路径。
struct BusinessQRScannerView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    @State private var cameraRevision = UUID()
    @State private var photo: PhotosPickerItem?
    @State private var showingFeedback = false
    @State private var feedbackMessage = ""
    @State private var resumeAfterFeedback = false
    @State private var reason = ""
    @State private var target: BusinessQRTarget?
    @State private var profileID: String?
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @State private var joinedRoute: ChatRoute?
    @State private var scanRevision = UUID()

    var body: some View {
        Group {
            if let target {
                Form {
                    destination(target)
                }
                .modifier(MessagingPageChrome())
            } else {
                camera
            }
        }
        .navigationTitle("扫一扫")
        .navigationBarTitleDisplayMode(.inline)
        .toast(isPresenting: Binding(get: { businessStore.isSubmitting }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: "正在处理",
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
        .toast(isPresenting: $showingFeedback, duration: 3, alert: {
            AlertToast(type: .regular, title: feedbackMessage,
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }, completion: {
            // 相机单次识别会停止捕获，业务失败提示结束后自动恢复，避免需要额外按钮。
            if resumeAfterFeedback && target == nil && !businessStore.isSubmitting {
                resumeAfterFeedback = false
                cameraRevision = UUID()
            }
        })
        .onDisappear { resumeAfterFeedback = false; scanRevision = UUID() }
        .onChange(of: photo) { item in Task { await recognize(item) } }
        .navigationDestination(isPresented: Binding(get: { profileID != nil }, set: { if !$0 { profileID = nil; cameraRevision = UUID() } })) {
            if let profileID {
                ContactRecordDetailView(store: LoginSessionService.shared.contacts, businessStore: businessStore,
                    contactID: profileID, fileHost: connection.current?.getFileHost)
            }
        }
        .navigationDestination(isPresented: Binding(get: { joinedRoute != nil }, set: { if !$0 { joinedRoute = nil; target = nil; cameraRevision = UUID() } })) { if let joinedRoute { ChatRoomView(route: joinedRoute) } }
    }

    /// 相机直接放入当前导航页面，取消或返回不会露出额外的扫码入口表单。
    private var camera: some View {
        BusinessQRCameraView(onCode: { value in Task { await decode(value, resumeCameraOnFailure: true) } }, onError: { showFeedback($0) })
            .id(cameraRevision)
            .overlay {
                GeometryReader { proxy in
                    let side = max(0, min(proxy.size.width - 48.zoom(), 297.zoom()))
                    RoundedRectangle(cornerRadius: 12.zoom()).stroke(.white.opacity(0.9), lineWidth: 2)
                        .frame(width: side, height: side).frame(maxWidth: .infinity, maxHeight: .infinity)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12.zoom()) {
                    Text("将好友或群二维码放入取景区域").font(.subheadline).multilineTextAlignment(.center)
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("从相册选择", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                    }.buttonStyle(MessagingActionButtonStyle(fill: .white.opacity(0.12), foreground: .white, border: .white))
                        .disabled(businessStore.isSubmitting)
                }.foregroundStyle(.white).tint(.white).padding(16.zoom()).background(.black.opacity(0.75))
            }
            .background(.black)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onDisappear { scanRevision = UUID() }
    }

    private func showFeedback(_ message: String, resumeCamera: Bool = false) {
        feedbackMessage = message
        resumeAfterFeedback = resumeCamera
        showingFeedback = true
    }

    /// 识别后的用户码只能打开资料；是否添加好友仍是独立动作。
    @ViewBuilder private func destination(_ target: BusinessQRTarget) -> some View {
        switch target {
        case .user: EmptyView()
        case .group(let id, let name, let avatar, let inviter, let isMember, let needsApproval):
            Section(name) {
                if isMember { EmptyView() }
                else {
                    if needsApproval { TextField("填写入群理由", text: $reason) }
                    Button(needsApproval ? "申请加入群聊" : "加入群聊") { Task {
                        let identity = businessStore.identity
                        if await businessStore.perform(.joinGroup(id: id, inviter: inviter, reason: reason)), businessStore.identity == identity {
                            if needsApproval { showFeedback("申请已提交，请等待群管理员审核") }
                            else { joinedRoute = ChatRoute(id: id, kind: .group, title: name, avatarURL: avatar) }
                        } else if businessStore.identity == identity, let error = businessStore.errorMessage { showFeedback(error) }
                    } }.disabled(businessStore.isSubmitting || (needsApproval && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
    }

    /// 二维码转换失败后保留页面，用户可重新扫描或选择其他图片。
    private func decode(_ content: String, resumeCameraOnFailure: Bool = false) async {
        guard !businessStore.isSubmitting else { return }
        let revision = UUID(); scanRevision = revision
        let identity = businessStore.identity
        target = nil; showingFeedback = false; resumeAfterFeedback = false; reason = ""
        let succeeded = await businessStore.perform(.decodeQR(content))
        guard scanRevision == revision, businessStore.identity == identity else { return }
        guard succeeded, let decoded = businessStore.qrTarget else {
            showFeedback(businessStore.errorMessage ?? "此二维码暂时无法识别", resumeCamera: resumeCameraOnFailure)
            return
        }
        // 服务端转换确认后的用户和已入群目标直接push，未入群仍展示真实申请表单。
        switch decoded {
        case .user(let id): profileID = id
        case .group(let id, let name, let avatar, _, let isMember, _):
            if isMember { joinedRoute = ChatRoute(id: id, kind: .group, title: name, avatarURL: avatar) }
            else { target = decoded }
        }
    }

    /// 相册选择由系统授权，离线只识别文本，真实业务仍需SDK转换。
    private func recognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let revision = UUID(); scanRevision = revision
        let identity = businessStore.identity
        target = nil; showingFeedback = false; resumeAfterFeedback = false
        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard scanRevision == revision, businessStore.identity == identity else { return }
            guard let data, let image = CIImage(data: data),
                  let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
                  let code = detector.features(in: image).compactMap({ ($0 as? CIQRCodeFeature)?.messageString }).first else { showFeedback("图片中没有识别到二维码"); return }
            guard scanRevision == revision, businessStore.identity == identity else { return }
            await decode(code)
        } catch { if scanRevision == revision, businessStore.identity == identity { showFeedback("图片读取失败，请重新选择") } }
    }
}
