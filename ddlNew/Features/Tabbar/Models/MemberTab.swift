//
//  MemberTab.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum MemberTab: String, CaseIterable, Identifiable {
    var displayName: String { L10n.lookup(rawValue) }
    case messages = "消息", contacts = "通讯录", vlog = "Vlog", tasks = "事项", profile = "我的"
    var id: Self { self }
    var icon: String {
        switch self { case .messages: return "bubble.left.and.bubble.right"; case .contacts: return "person.2"; case .vlog: return "camera.aperture"; case .tasks: return "checklist"; case .profile: return "person.crop.circle" }
    }
}
