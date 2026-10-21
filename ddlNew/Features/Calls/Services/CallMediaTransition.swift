//
//  CallMediaTransition.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation

/// 两家 SDK 共用系统音频会话；下一通等待上一通实际停流/销毁完成，包含跨供应商切换。
@MainActor enum CallMediaTransition {
    static var pending: Task<Void, Never>?
}
