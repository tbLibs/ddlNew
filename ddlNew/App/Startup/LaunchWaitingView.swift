//
//  LaunchWaitingView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import UIKit

/// 系统启动与业务恢复共用品牌构图；真实恢复进度与状态由 App 根页面统一展示。
struct LaunchWaitingView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController() ?? UIViewController()
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
