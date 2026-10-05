//
//  RemoteAvatarURL.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

/// SDK 头像字段可能是完整链接，也可能是 OSS 文件 Host 下的相对路径。
nonisolated enum RemoteAvatarURL {
    static func resolve(_ avatar: String, relativeTo fileHost: URL?) -> URL? {
        let value = avatar.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if let scheme = URLComponents(string: value)?.scheme,
           scheme.lowercased() != "http" && scheme.lowercased() != "https" { return nil }

        let url: URL?
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            url = URL(string: value)
        } else {
            guard let fileHost else { return nil }
            // 导航 Host 没有末尾斜杠；相对路径有无开头斜杠都应落在同一 Host 下。
            let base = fileHost.appending(path: "")
            url = URL(string: value, relativeTo: base)?.absoluteURL
        }
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { return nil }
        return url
    }
}
