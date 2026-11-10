//
//  LoginSecurityNotice.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Darwin

/// 业务码与 SDK 转换后的下线类型分别映射；白名单地址只使用服务端实际返回值。
nonisolated enum LoginSecurityNotice {
    static func businessMessage(code: Int, message: String) -> String? {
        switch code {
        case 40015: return L10n.tr("此账号已被封禁，请联系俱乐部管理员")
        case 40029: return L10n.tr("此设备已被封禁，请联系俱乐部管理员")
        case 40030: return L10n.tr("当前登录 IP 已被封禁，请联系俱乐部管理员")
        case 90018:
            let address = whitelistAddress(from: message)
            return address.isEmpty ? L10n.tr("当前登录 IP 不在白名单内，请联系俱乐部管理员")
                : L10n.tr("登录 IP：\(address) 不在白名单内，请联系俱乐部管理员")
        case 40045: return L10n.tr("密码连续输入错误，请 5 分钟后重试")
        case 40062: return L10n.tr("密码连续输入错误，请 24 小时后重试")
        case 40035, 40038, 40061, 10002, 10005, 10007: return L10n.tr("登录身份已失效，请重新登录")
        case 900017: return L10n.tr("此账号已注销，请联系俱乐部管理员")
        default: return nil
        }
    }

    /// 白名单失败消息约定为真实 IP；拒绝向页面转发混入临时验证凭据的其他内容。
    static func whitelistAddress(from message: String) -> String {
        let value = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        guard value.withCString({ inet_pton(AF_INET, $0, &ipv4) == 1 || inet_pton(AF_INET6, $0, &ipv6) == 1 }) else { return "" }
        return value
    }

    static func sessionMessage(code: Int, message: String) -> String {
        if let notice = businessMessage(code: code, message: message) { return notice }
        switch code {
        case 2: return L10n.tr("此账号已被封禁，请联系俱乐部管理员")
        case 10: return L10n.tr("当前登录 IP 已被封禁，请联系俱乐部管理员")
        case 11: return L10n.tr("此设备已被封禁，请联系俱乐部管理员")
        case 13: return L10n.tr("账号信息已发生变化，请重新登录")
        case 888: return L10n.tr("此账号已注销，请联系俱乐部管理员")
        case 999:
            // SDK 也把未知 AUTH 错误转换为 999 且清空消息，不能把所有 999 当作封禁。
            return message.isEmpty ? L10n.tr("登录身份已失效，请重新登录") : L10n.tr("\(message)，请重新登录")
        default: return message.isEmpty ? L10n.tr("账号已被强制下线，请重新登录") : L10n.tr("\(message)，请重新登录")
        }
    }
}
