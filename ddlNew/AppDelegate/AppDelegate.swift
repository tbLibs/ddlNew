//
//  AppDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 配置sentry
        configSenTry()
        
        
        return true
    }
}
