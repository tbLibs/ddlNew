//
//  LaunchWaitingView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import SwiftUI
import UIKit

/// 系统 LaunchScreen 由 iOS 自动关闭；业务等待页直接复用同一 storyboard 保持外观一致。
struct LaunchWaitingView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController() ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
