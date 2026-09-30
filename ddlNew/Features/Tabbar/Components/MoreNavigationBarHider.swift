//
//  MoreNavigationBarHider.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import UIKit
import SwiftUIIntrospect

/// 保留原版溢出 Tab 的导航栏适配；当前四栏布局不启用。
struct MoreNavigationBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.updateBar() }

    final class Controller: UIViewController {
        private weak var moreNavigationController: UINavigationController?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            DispatchQueue.main.async { [weak self] in self?.updateBar() }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            moreNavigationController?.setNavigationBarHidden(false, animated: false)
        }

        func updateBar() {
            guard isViewLoaded, view.window != nil,
                  let more = tabBarController?.moreNavigationController,
                  more.viewControllers.count > 1 else { return }
            moreNavigationController = more
            more.setNavigationBarHidden(true, animated: false)
        }
    }
}
