//
//  AppDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import MMKV
import NetworkStatus
import UIKit
import UserNotifications
import NoaChatCore

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // SDK 单例初始化时会立即读写 MMKV，必须在主线程同步初始化，不能异步排队。
        MMKV.initialize(rootDir: nil)
        UNUserNotificationCenter.current().delegate = self
        NoaIMSDKManager.sharedTool().setApplicationManagesMessageAlerts(true)
        _ = PushCoordinator.shared
        // 配置sentry
        configSenTry()
        // SDK 的 TCP 连接依赖此网络状态；只在 App 启动时开启一次监听。
        NetWorkStatusManager.shared.startMonitoring()

        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushCoordinator.shared.receivedToken(deviceToken.map { String(format: "%02x", $0) }.joined())
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushCoordinator.shared.registrationFailed()
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 前台声音由实时SDK事件统一负责，避免APNs和在线消息重复提醒。
        completionHandler([])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let payload = PushPayload(info:response.notification.request.content.userInfo) else { completionHandler(); return }
        Task { @MainActor in
            let cached = try? UserSessionStore.shared.cachedSession()
            let owner = cached.map { (userUID:$0.credentials.userUID, tenantID:$0.credentials.lastLiceseId) }
            PushCoordinator.shared.receiveClick(payload,cachedOwner:owner)
            completionHandler()
        }
    }
}
