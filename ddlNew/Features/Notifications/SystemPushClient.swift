import Foundation
import UserNotifications
import UIKit
import AudioToolbox
import CryptoKit

@MainActor final class SystemPushClient: PushSystemClient {
    private let center = UNUserNotificationCenter.current()
    func requestPermission() async -> String {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined { _ = try? await center.requestAuthorization(options:[.alert,.badge,.sound]) }
        return await permissionStatus()
    }
    func permissionStatus() async -> String {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized: return L10n.tr("已开启")
        case .provisional, .ephemeral: return L10n.tr("已允许静默通知")
        case .denied: return L10n.tr("系统通知已关闭")
        case .notDetermined: return L10n.tr("尚未允许通知")
        @unknown default: return L10n.tr("请查看系统通知设置")
        }
    }
    func registerRemote() { UIApplication.shared.registerForRemoteNotifications() }
    private func identifier(_ event: PushEvent, owner: PushIdentity) -> String {
        let raw = "\(owner.tenantID)|\(owner.userUID)|\(owner.sessionID)|\(event.destination)|\(event.id)"
        return "ddl.push." + SHA256.hash(data:Data(raw.utf8)).map { String(format:"%02x",$0) }.joined()
    }
    func post(_ event: PushEvent, identity: PushIdentity, sound: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = event.title; content.body = event.body
        content.userInfo = PushPayload(destination:event.destination,userUID:identity.userUID,tenantID:identity.tenantID,
                                       processID:PushProcess.id,sessionID:identity.sessionID).info
        if sound { content.sound = .default }
        let request = UNNotificationRequest(identifier:identifier(event,owner:identity),content:content,trigger:nil)
        do { try await center.add(request) }
        catch { /* 授权状态在设置页展示；不记录私人通知正文。 */ }
    }
    func remove(_ event: PushEvent, identity: PushIdentity) {
        let ids = [identifier(event,owner:identity)]
        center.removePendingNotificationRequests(withIdentifiers:ids); center.removeDeliveredNotifications(withIdentifiers:ids)
    }
    func clear() {
        center.removeAllPendingNotificationRequests(); center.removeAllDeliveredNotifications(); badge(0)
    }
    func play(sound: Bool, vibration: Bool) {
        // 不切换AVAudioSession类别，不中断现有通话/录音/播放器。
        if sound { AudioServicesPlaySystemSound(1004) }
        if vibration { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
    }
    func badge(_ count: Int) { UIApplication.shared.applicationIconBadgeNumber = count }
}

extension PushCoordinator {
    static let shared: PushCoordinator = {
        let value = PushCoordinator(client:SDKPushClient(),system:SystemPushClient())
        value.audioBusy = { CallCoordinator.shared.isPresented || ChatRuntime.shared.hasActiveNotificationAudio }
        return value
    }()
}
