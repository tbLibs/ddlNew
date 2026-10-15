//
//  ComplaintClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

@MainActor protocol ComplaintClient: AnyObject {
    /// 仅上传证据图片，不进入聊天消息队列。
    func upload(_ file: URL, context: ChatContext) async throws -> String
    /// 上传完成后才提交系统投诉，完整身份由客户端再次核验。
    func submit(_ parameters: [String: String], context: ChatContext) async throws
    /// 表单取消及根会话退出共同结束本轮传输与等待。
    func cancel()
}
