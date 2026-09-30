//
//  ClubMessage.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 消息列表的本地演示模型。
struct ClubMessage: Identifiable {
    let id: String
    let title: String
    var preview: String
    let body: String
    var time: String
    let icon: String
    let isNotice: Bool
    var unread: Bool
    var contactID: String? = nil

    static let samples: [Self] = [
        .init(id: "hike-reminder", title: "周六日落轻徒步", preview: "领队阿哲：集合点已确认，周六见！", body: "大家好，本次轻徒步在北山游客中心集合。请提前 15 分钟到达，穿防滑运动鞋，并带好饮用水。期待和大家一起看日落。", time: "14:32", icon: "map", isNotice: false, unread: true),
        .init(id: "club-notice", title: "俱乐部通知", preview: "本月活动报名规则调整", body: "为了让更多伙伴有机会参加活动，取消报名请至少提前 12 小时。空出的名额将按候补顺序释放，请留意活动状态。感谢你的理解与配合。", time: "11:20", icon: "bell", isNotice: true, unread: true),
        .init(id: "welcome", title: "会员服务", preview: "林夏，欢迎加入远山户外俱乐部", body: "很高兴与你相遇！你可以在活动页找到感兴趣的活动，也可以在通讯录中认识领队和同行伙伴。让我们从下一次出发开始，收集更多美好的户外回忆。", time: "09:16", icon: "shield", isNotice: true, unread: true),
        .init(id: "ride-chat", title: "城市夜骑 · 江畔线", preview: "小雨：今晚沿江的风景一定很美", body: "今晚的集合地点是滨江广场。出发前请检查自行车、车灯和头盔，跟随领队保持队形，安全享受沿江风景。", time: "昨天", icon: "users", isNotice: false, unread: false),
        .init(id: "bird-chat", title: "森林观鸟晨行", preview: "领队林野：分享一份观鸟准备清单", body: "建议带上望远镜、饮用水和防蚊用品，穿低饱和度的衣服。观察时请保持安静，与野生动物保持距离，一起守护这片自然。", time: "星期三", icon: "note", isNotice: false, unread: false),
        .init(id: "signup", title: "活动助手", preview: "你的城市夜骑报名已确认", body: "你已报名城市夜骑 · 江畔线。活动当天可在活动详情中查看集合信息，并到达现场后使用领队提供的签到码完成签到。", time: "星期二", icon: "calendar", isNotice: true, unread: false)
    ]
}
