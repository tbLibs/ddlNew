//
//  InformationPage.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum InformationPage: String, Identifiable {
    case loginHelp = "登录帮助", announcements = "俱乐部公告", benefits = "会员权益", rules = "活动规则", contact = "联系俱乐部", privacy = "隐私与安全"
    var id: Self { self }
    var paragraphs: [String] {
        switch self {
        case .loginHelp: return ["请检查邀请码、会员卡号或账号及密码是否输入正确。", "如仍无法登录，请在“使用支持”中查看联系方式。"]
        case .announcements: return ["本月活动报名规则调整", "取消报名请至少提前12小时，名额将按顺序释放给候补会员。", "请提前到达集合点，阅读活动须知，并按领队指引完成个人签到。"]
        case .benefits: return ["发现专属活动", "浏览俱乐部发布的户外活动，查看时间、集合点和参与要求。", "便捷管理参与记录", "在个人中心查看报名、候补和签到记录。"]
        case .rules: return ["选择适合自身状态和体能的活动，报名前认真阅读参与须知。", "取消报名请至少提前12小时；名额释放后，候补会员按顺序递补。", "到达集合点后完成个人签到，活动中遵守领队指引并保护自然环境。"]
        case .contact: return ["请联系向你提供邀请码的俱乐部工作人员，获取最新联系方式。", "如遇登录、报名或签到问题，请告知工作人员你的会员卡号和活动名称。"]
        case .privacy: return ["账号、活动、通讯录和消息相关信息用于提供对应功能。", "退出登录不会清除活动记录；如需注销账号，可前往“我的 → 设置 → 注销账号”。详细说明请查看隐私政策。"]
        }
    }
}
