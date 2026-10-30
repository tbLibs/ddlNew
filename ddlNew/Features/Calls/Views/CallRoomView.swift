import SwiftUI
import Combine
import UIAdapter
import Kingfisher

@MainActor final class CallLayoutPreferences: ObservableObject {
    @Published var prefersLocalVideo = false
}

/// 页面只展示当前通话，房间和设备始终由根协调器持有。
struct CallRoomView: View {
    @ObservedObject var coordinator: CallCoordinator
    @ObservedObject var layout: CallLayoutPreferences

    var body: some View {
        ZStack {
            HomeTheme.heroBackground.ignoresSafeArea()
            if let call = coordinator.session {
                let immersiveVideo = call.context.route.kind == .single && call.kind == .video && call.phase != .incoming
                if immersiveVideo { mainVideo(call).ignoresSafeArea() }
                VStack(spacing: 20.zoom()) {
                    header(call)
                    if immersiveVideo { secondaryVideo(call).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) }
                    else { participants(call).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    controls(call)
                }
                .padding(.horizontal, 20.zoom()).padding(.vertical, 16.zoom())
            }
        }
        .foregroundStyle(.white)
        .tint(MessagingTheme.accent)
        .sheet(item: additionalSelection) { request in
            CallMemberSelectionView(request: request, coordinator: coordinator)
        }
    }

    private var additionalSelection: Binding<CallSelectionRequest?> {
        Binding(get: { coordinator.selection?.isAdditionalInvite == true ? coordinator.selection : nil },
                set: { if $0 == nil { coordinator.cancelSelection() } })
    }

    private func header(_ call: CallSession) -> some View {
        HStack(alignment: .top) {
            Button { coordinator.minimize() } label: {
                Image(systemName: "chevron.down").frame(width: 44, height: 44)
            }.accessibilityLabel("缩小通话")
            VStack(spacing: 6.zoom()) {
                Text(call.title).font(.title2.weight(.semibold)).lineLimit(2)
                if let started = call.connectedAt, call.phase == .connected {
                    Text(started, style: .timer).monospacedDigit().font(.subheadline)
                        .accessibilityLabel("通话时长")
                } else {
                    Text(status(call)).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                }
                if call.isIncoming && call.context.route.kind == .group && call.phase == .incoming {
                    Text((call.participants.first(where: { $0.id == call.callerID })?.name ?? "群成员") + " 邀请你加入")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                }
            }.frame(maxWidth: .infinity)
            if call.context.route.kind == .group && call.phase == .connected {
                Button { Task { await coordinator.inviteMembers() } } label: {
                    Image(systemName: "person.badge.plus").frame(width: 44, height: 44)
                }.accessibilityLabel("邀请成员").disabled(coordinator.busy)
            } else { Color.clear.frame(width: 44, height: 44) }
        }
    }

    @ViewBuilder private func participants(_ call: CallSession) -> some View {
        if call.context.route.kind == .group {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12.zoom()), GridItem(.flexible(), spacing: 12.zoom())], spacing: 12.zoom()) {
                    ForEach(call.participants) { person in
                        participantTile(person, kind: call.kind)
                            .frame(height: 145.zoom()).clipShape(RoundedRectangle(cornerRadius: 16.zoom()))
                    }
                }
            }
        } else {
            VStack(spacing: 24.zoom()) {
                let peer = call.participants.first(where: { !$0.isLocal })
                CallAvatar(name: peer?.name ?? call.title, resource: peer?.avatar ?? call.context.route.avatarURL, size: 108.zoom())
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 只有主画面越过安全区；小窗跟随标题下方的安全区内容布局。
    @ViewBuilder private func mainVideo(_ call: CallSession) -> some View {
        let local = call.participants.first(where: \.isLocal)
        let remote = call.participants.first(where: { !$0.isLocal })
        if let main = layout.prefersLocalVideo ? local : remote {
            participantTile(main, kind: call.kind)
        }
    }

    @ViewBuilder private func secondaryVideo(_ call: CallSession) -> some View {
        let local = call.participants.first(where: \.isLocal)
        let remote = call.participants.first(where: { !$0.isLocal })
        if let small = layout.prefersLocalVideo ? remote : local {
            Button { layout.prefersLocalVideo.toggle() } label: {
                participantTile(small, kind: call.kind)
                    .frame(width: 110.zoom(), height: 160.zoom())
                    .clipShape(RoundedRectangle(cornerRadius: 14.zoom()))
                    .overlay(RoundedRectangle(cornerRadius: 14.zoom()).stroke(.white.opacity(0.3)))
            }.buttonStyle(.plain).accessibilityLabel("交换大小视频画面")
        }
    }

    private func participantTile(_ person: CallParticipant, kind: CallKind) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14.zoom()).fill(.white.opacity(0.08))
            if kind == .video && person.cameraEnabled && (person.isConnected || person.isLocal) {
                CallVideoSurface(participantID: person.id, coordinator: coordinator)
                    .clipped().accessibilityLabel(person.name + "的视频画面")
            } else {
                CallAvatar(name: person.name, resource: person.avatar, size: 64.zoom())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 4) {
                Text(person.isLocal ? "我" : person.name).lineLimit(1)
                Spacer(minLength: 0)
                if !person.isConnected && !person.isLocal { Image(systemName: "clock").accessibilityLabel("等待加入") }
                if !person.microphoneEnabled { Image(systemName: "mic.slash.fill").accessibilityLabel("麦克风已关闭") }
            }
            .font(.caption).padding(8.zoom())
            .background(.black.opacity(0.4))
            if !person.isConnected && !person.isLocal {
                Text(person.stateText).font(.caption).padding(8.zoom())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func controls(_ call: CallSession) -> some View {
        VStack(spacing: 22.zoom()) {
            if call.phase != .incoming {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18.zoom()) { mediaControls(call) }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14.zoom()) { mediaControls(call) }
                }.disabled(call.phase != .connected)
            }
            HStack(spacing: 24.zoom()) {
                primaryAction(call.phase == .incoming ? "拒绝" : call.phase == .outgoing ? "取消" : "挂断",
                       icon: "phone.down.fill", color: .red, enabled: call.phase != .ending) {
                    Task { await coordinator.hangUp() }
                }
                if call.phase == .incoming {
                    primaryAction("接听", icon: call.kind == .audio ? "phone.fill" : "video.fill",
                           color: Color(clubHex: 0x2859BC), enabled: !coordinator.busy) {
                        Task { await coordinator.accept() }
                    }
                }
            }
        }.padding(.bottom, 12.zoom())
    }

    @ViewBuilder private func mediaControls(_ call: CallSession) -> some View {
        action(call.microphoneEnabled ? "静音" : "取消静音", icon: call.microphoneEnabled ? "mic.fill" : "mic.slash.fill",
               selected: !call.microphoneEnabled) { coordinator.toggleMicrophone() }
        action(call.speakerEnabled ? "扬声器已开" : "扬声器", icon: call.speakerEnabled ? "speaker.wave.2.fill" : "speaker.fill",
               selected: call.speakerEnabled) { coordinator.toggleSpeaker() }
        if call.kind == .video {
            action(call.cameraEnabled ? "关闭摄像头" : "打开摄像头", icon: call.cameraEnabled ? "video.fill" : "video.slash.fill",
                   selected: !call.cameraEnabled) { coordinator.toggleCamera() }
            action("翻转摄像头", icon: "arrow.triangle.2.circlepath.camera", enabled: call.cameraEnabled) { coordinator.switchCamera() }
        }
    }

    /// 主通话动作独立于设备控件：来电双胶囊，通话中横向挂断。
    private func primaryAction(_ title: String, icon: String, color: Color, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 8.zoom()) {
                Image(systemName: icon).accessibilityHidden(true)
                Text(title).font(.body.weight(.medium))
            }.frame(maxWidth: .infinity, minHeight: 50.zoom()).foregroundStyle(.white)
                .background(color, in: Capsule())
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.45).accessibilityLabel(title)
    }

    private func action(_ title: String, icon: String, color: Color? = nil, selected: Bool = false,
                        enabled: Bool = true, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 8.zoom()) {
                Image(systemName: icon).font(.system(size: 24.zoom(), weight: .medium))
                    .frame(width: max(54, 58.zoom()), height: max(54, 58.zoom()))
                    .foregroundStyle(selected && color == nil ? Color.black : Color.white)
                    .background(color ?? (selected ? .white : .clear), in: RoundedRectangle(cornerRadius: 12.zoom()))
                Text(title).font(.caption).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(minWidth: 64.zoom(), minHeight: 82.zoom())
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(title)
    }

    private func status(_ call: CallSession) -> String {
        switch call.phase {
        case .incoming: return call.kind == .audio ? "邀请你进行语音通话" : "邀请你进行视频通话"
        case .outgoing: return "等待对方接听…"
        case .connecting: return "正在连接…"
        case .connected: return "通话中"
        case .ending: return "正在结束通话…"
        }
    }
}

struct CallAvatar: View {
    let name: String
    let resource: String
    let size: CGFloat
    @ObservedObject private var connection = OSSConnectionBootstrap.shared

    var body: some View {
        let host = connection.current?.getFileHost
        KFImage(RemoteAvatarURL.resolve(resource, relativeTo: host))
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: size, height: size)))
            .cancelOnDisappear(true)
            .placeholder {
                ZStack { MessagingTheme.avatarBackground; Text(String(name.prefix(1))).font(.title).foregroundStyle(MessagingTheme.accent) }
            }
            .resizable().scaledToFill().frame(width: size, height: size)
            .clipShape(Circle()).accessibilityHidden(true)
    }
}
