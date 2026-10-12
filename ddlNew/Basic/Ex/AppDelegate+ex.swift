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
            options.dsn = "https://773a0932ed430ce3fed1ab8a900ce27e@sentry.xingxinghai.uk/15"
            #if DEBUG
            options.debug = true
            options.environment = "develpment";
            #else
            options.debug = false
            #endif
            
            options.tracesSampleRate = 1.0
        }
        SentrySDK.logger.info("test ddlnew111")
    }
    
}
