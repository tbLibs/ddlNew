import Foundation

/// 仅供展示：真实地址继续用于请求与结果匹配，不进入可复制／朗读的文本。
nonisolated enum NetworkDiagnosticAddress {
    static func masked(_ address: String) -> String {
        guard !address.isEmpty, !address.contains(where: { $0.isWhitespace || $0.isNewline }) else { return "***" }
        let hasScheme = address.contains("://")
        guard let parts = URLComponents(string: hasScheme ? address : "tcp://" + address),
              let scheme = parts.scheme?.lowercased(), ["http", "https", "tcp"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.port == nil || (1...65535).contains(parts.port!) else { return "***" }
        let port = parts.port.map { ":\($0)" } ?? ""
        let prefix = hasScheme ? scheme + "://" : ""
        // 路径可能含企业号；账号、查询参数和片段也一律不展示。
        let path = parts.path.isEmpty || parts.path == "/" ? "" : "/***"
        return prefix + maskedHost(host) + port + path
    }

    private static func maskedHost(_ host: String) -> String {
        let bare = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if bare.contains(":") {
            let first = bare.split(separator: ":", omittingEmptySubsequences: false).first.map(String.init) ?? ""
            guard !first.isEmpty, first.count <= 4, first.allSatisfy({ $0.isHexDigit }) else { return "[****]" }
            return "[\(first):****]"
        }
        let labels = bare.split(separator: ".", omittingEmptySubsequences: false)
        if labels.count == 4, labels.allSatisfy({ label in
            !label.isEmpty && label.allSatisfy(\.isNumber) && UInt8(label) != nil
        }) {
            return "\(labels[0]).***.***.\(labels[3])"
        }
        return labels.map { label in
            guard label.count > 2, let first = label.first, let last = label.last,
                  label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return "***" }
            return "\(first)***\(last)"
        }.joined(separator: ".")
    }
}
