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

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // SDK 单例初始化时会立即读写 MMKV，必须在主线程同步初始化，不能异步排队。
        MMKV.initialize(rootDir: nil)
        // 配置sentry
        configSenTry()
        // SDK 的 TCP 连接依赖此网络状态；只在 App 启动时开启一次监听。
        NetWorkStatusManager.shared.startMonitoring()

        return true
    }
}
