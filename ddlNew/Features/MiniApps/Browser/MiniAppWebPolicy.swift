//
//  MiniAppWebPolicy.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import Foundation

/// 应用入口与跳转统一限制网页协议，不允许本地文件和带明文凭据的地址。
enum MiniAppWebPolicy {
    /// 输入和历史应用可省略协议；网页内部跳转仍使用下面的严格协议校验。
    static func entryURL(_ value: String) -> URL? {
        let input = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !input.hasPrefix("/") || input.hasPrefix("//") else { return nil }
        if let scheme = URLComponents(string: input)?.scheme?.lowercased() {
            if ["http", "https"].contains(scheme) { return url(input) }
            // URLComponents会把example.com:8080或localhost:8080当成scheme。
            let authority = input.components(separatedBy: CharacterSet(charactersIn: "/?#")).first ?? ""
            let parts = authority.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].contains(".") || parts[0].lowercased() == "localhost",
                  let port = Int(parts[1]), (1...65535).contains(port) else { return nil }
        }
        return url(input.hasPrefix("//") ? "https:" + input : "https://" + input)
    }

    static func url(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
}
