//
//  LegalDocument.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum LegalDocument: String, Identifiable {
    case privacy, support
    var id: String { rawValue }
    var title: String {
        switch self {
        case .privacy: return "隐私政策"
        case .support: return "使用支持"
        }
    }
    var onlineURL: URL? {
        guard let file = Bundle.main.url(forResource: "LegalLinks", withExtension: "json"),
              let data = try? Data(contentsOf: file),
              let links = try? JSONDecoder().decode([String: String].self, from: data),
              let value = links[rawValue], let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}
