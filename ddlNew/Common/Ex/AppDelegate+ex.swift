//
//  AppDelegate+ex.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Sentry

extension AppDelegate {
    
    /// 配置sentry
    func configSenTry() {
        SentrySDK.start { options in
            options.dsn = "https://409608a0222777ddfcb9c4ed803aa40f@o4511874010578944.ingest.de.sentry.io/4512122692173904"
            options.debug = true
            options.tracesSampleRate = 1.0
        }
    }
    
}
