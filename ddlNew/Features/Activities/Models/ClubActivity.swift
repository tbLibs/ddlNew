//
//  ClubActivity.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

struct ClubActivity: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let date: String
    let place: String
    let meetingPoint: String
    let capacity: Int
    let requirement: String
    let notice: String
    let checkInCode: String
    let checkInTime: String
    static let samples: [ClubActivity] = [
        .init(id: "hike", title: "周六日落轻徒步", category: "户外 · 轻徒步", date: "10月16日 16:30", place: "北山森林公园", meetingPoint: "北山游客中心", capacity: 4, requirement: "6公里轻徒步，需要基础体能", notice: "请穿防滑运动鞋，携带饮用水。取消报名请至少提前12小时。", checkInCode: "6812", checkInTime: "16:00–16:45"),
        .init(id: "ride", title: "城市夜骑 · 江畔线", category: "户外 · 骑行", date: "10月15日 19:30", place: "滨江广场", meetingPoint: "滨江广场", capacity: 8, requirement: "自备自行车与头盔，适合有骑行经验的会员", notice: "请检查车灯和刹车，全程佩戴头盔，遵守领队指引。取消报名请至少提前12小时。", checkInCode: "6812", checkInTime: "19:00–19:45"),
        .init(id: "bird", title: "森林观鸟晨行", category: "自然 · 观鸟", date: "10月24日 06:30", place: "东湖湿地入口", meetingPoint: "东湖湿地入口", capacity: 0, requirement: "适合所有会员，请轻声观察，保护自然", notice: "建议携带望远镜、饮用水与防蚊用品。候补名额会按顺序通知。", checkInCode: "6812", checkInTime: "06:00–06:45")
    ]
}
