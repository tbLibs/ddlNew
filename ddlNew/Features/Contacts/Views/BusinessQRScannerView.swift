//
//  BusinessQRScannerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import PhotosUI
import CoreImage

/// 业务扫码只到用户资料或群申请，不恢复导航和PC认证路径。
struct BusinessQRScannerView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    @State private var showingCamera = false
    @State private var photo: PhotosPickerItem?
    @State private var message: String?
    @State private var reason = ""
    @State private var input = ""
    @State private var target: BusinessQRTarget?
    @State private var joinedRoute: ChatRoute?

    var body: some View {
        Form {
            Section {
                Button("打开摄像头扫码") { target = nil; message = nil; showingCamera = true }
                PhotosPicker("从相册识别", selection: $photo, matching: .images)
                TextField("或粘贴业务二维码内容", text: $input, axis: .vertical)
                Button("识别内容") { Task { await decode(input) } }.disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || businessStore.isSubmitting)
            } footer: { Text("仅支持当前俱乐部的好友和群二维码。") }
            if let target { destination(target) }
            if businessStore.isSubmitting { ProgressView("正在识别") }
            if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
            if let message { Text(message).foregroundStyle(.secondary) }
        }
        .navigationTitle("扫一扫").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
        .sheet(isPresented: $showingCamera) {
            NavigationStack {
                BusinessQRCameraView(onCode: { value in showingCamera = false; Task { await decode(value) } }, onError: { error in showingCamera = false; message = error })
                    .navigationTitle("扫描业务二维码").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showingCamera = false } } }
            }
        }
        .onChange(of: photo) { item in Task { await recognize(item) } }
        .navigationDestination(isPresented: Binding(get: { joinedRoute != nil }, set: { if !$0 { joinedRoute = nil } })) { if let joinedRoute { ChatRoomView(route: joinedRoute) } }
    }

    /// 识别后的用户码只能打开资料；是否添加好友仍是独立动作。
    @ViewBuilder private func destination(_ target: BusinessQRTarget) -> some View {
        switch target {
        case .user(let id): NavigationLink("查看用户资料", value: ContactsRoute(contactID: id))
        case .group(let id, let name, let avatar, let inviter, let isMember, let needsApproval):
            Section(name) {
                if isMember { NavigationLink("进入群聊", value: ChatRoute(id: id, kind: .group, title: name, avatarURL: avatar)) }
                else {
                    if needsApproval { TextField("填写入群理由", text: $reason) }
                    Button(needsApproval ? "申请加入群聊" : "加入群聊") { Task {
                        let identity = businessStore.identity
                        if await businessStore.perform(.joinGroup(id: id, inviter: inviter, reason: reason)), businessStore.identity == identity {
                            if needsApproval { message = "申请已提交，请等待群管理员审核" }
                            else { joinedRoute = ChatRoute(id: id, kind: .group, title: name, avatarURL: avatar) }
                        }
                    } }.disabled(businessStore.isSubmitting || (needsApproval && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
    }

    /// 二维码转换失败后保留页面，用户可重新扫描或选择其他图片。
    private func decode(_ content: String) async {
        target = nil; message = nil
        guard await businessStore.perform(.decodeQR(content)) else { return }; target = businessStore.qrTarget
    }

    /// 相册选择由系统授权，离线只识别文本，真实业务仍需SDK转换。
    private func recognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = CIImage(data: data),
                  let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
                  let code = detector.features(in: image).compactMap({ ($0 as? CIQRCodeFeature)?.messageString }).first else { message = "图片中没有识别到二维码"; return }
            await decode(code)
        } catch { message = "图片读取失败，请重新选择" }
    }
}
