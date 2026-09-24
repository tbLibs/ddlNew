//
//  PublicIPResolver.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Darwin
import Foundation

/// 并发查询设备出口公网 IP，首个返回有效地址的服务胜出。
enum PublicIPResolver {
    /// 同时查询多个服务；全部失败时返回空字符串，供导航请求按旧协议兜底。
    static func resolve() async -> String {
        await withTaskGroup(of: String?.self) { group in
            for address in publicIPLookupURLs {
                group.addTask { await lookup(address) }
            }

            for await result in group {
                if let ip = result {
                    group.cancelAll()
                    return ip
                }
            }
            // 与旧项目一致：所有服务失败时仍允许请求继续，client_ip 留空。
            return ""
        }
    }

    private static func lookup(_ address: String) async -> String? {
        guard let url = URL(string: address) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  data.count <= 128,
                  let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            let ip = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // 只接受 IP 字面量，避免错误页或其他文本被写入 Protobuf 的 client_ip。
            var ipv4 = in_addr()
            var ipv6 = in6_addr()
            guard inet_pton(AF_INET, ip, &ipv4) == 1 ||
                    inet_pton(AF_INET6, ip, &ipv6) == 1 else {
                return nil
            }
            return ip
        } catch {
            return nil
        }
    }
}
