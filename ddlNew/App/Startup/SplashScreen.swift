//
//  SplashScreen.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 保留原版启动屏包装；当前启动等待页面使用 LaunchWaitingView。
struct SplashScreen: UIViewControllerRepresentable {
    // 复用系统启动屏，等待本地状态恢复完成。
    func makeUIViewController(context: Context) -> UIViewController {
        UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController() ?? UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}
