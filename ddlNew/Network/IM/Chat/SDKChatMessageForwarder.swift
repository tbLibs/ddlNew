//
//  SDKChatMessageForwarder.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

/// 透明转发原消息代理，只在原SDK执行同步selector后观察不可变业务快照。
nonisolated class SDKChatMessageForwarder: NSObject, @unchecked Sendable {
    let original: NSObject
    private let inspect: @Sendable (NSObject?) -> Void
    /// 强持有原SDK代理，弱Socket代理切换不会释放原处理者。
    init(original: NSObject, inspect: @escaping @Sendable (NSObject?) -> Void) { self.original = original; self.inspect = inspect }
    /// 所有原SDK声明的消息与ACK selector保持响应，不截断原逻辑。
    override func responds(to aSelector: Selector!) -> Bool { super.responds(to: aSelector) || original.responds(to: aSelector) }
    /// 未实现selector完整交还原SDK，包括正文、ACK、编辑和系统事件。
    override func forwardingTarget(for aSelector: Selector!) -> Any? { original.responds(to: aSelector) ? original : super.forwardingTarget(for: aSelector) }
    /// 先执行原SDK同步逻辑再观察，避免应用层抢先替代SDK处理。
    @objc(noaMessageSystemMessageSynchroMessageWith:) func inspectSync(_ message: NSObject?) {
        let selector = NSSelectorFromString("noaMessageSystemMessageSynchroMessageWith:")
        if original.responds(to: selector) { _ = original.perform(selector, with: message) }
        inspect(message)
    }
}
