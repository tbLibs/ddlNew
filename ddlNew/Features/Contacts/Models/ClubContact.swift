//
//  ClubContact.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 通讯录的本地演示模型。
struct ClubContact: Identifiable {
    let id: String
    let name: String
    let initial: String
    let role: String
    let interests: String
    let introduction: String
    let tone: Int
    var isLeader: Bool { role == "领队" }

    static let samples: [Self] = [
        .init(id: "azhe", name: "阿哲", initial: "A", role: "领队", interests: "轻徒步 · 山野露营", introduction: "喜欢带大家走进山野，在慢下来的路上发现风景。", tone: 0),
        .init(id: "chenmo", name: "陈默", initial: "C", role: "会员", interests: "骑行 · 城市漫步", introduction: "用骑行探索城市，也喜欢周末沿江走走。", tone: 1),
        .init(id: "dingding", name: "丁丁", initial: "D", role: "会员", interests: "观鸟 · 自然摄影", introduction: "收集清晨的鸟鸣与日落时分的光。", tone: 2),
        .init(id: "linye", name: "林野", initial: "L", role: "领队", interests: "自然观察 · 观鸟", introduction: "热爱湿地和森林，愿意分享自然观察的小经验。", tone: 2),
        .init(id: "mumu", name: "木木", initial: "M", role: "会员", interests: "徒步 · 植物观察", introduction: "享受每一次出发，也珍惜途中遇见的新朋友。", tone: 0),
        .init(id: "qiaoan", name: "乔安", initial: "Q", role: "会员", interests: "轻徒步 · 摄影", introduction: "相机里装着风景，也装着和伙伴们一起的回忆。", tone: 1),
        .init(id: "xiaoyu", name: "小雨", initial: "X", role: "领队", interests: "城市骑行 · 路线探索", introduction: "喜欢探索城市里的小路，带大家安全轻松地骑行。", tone: 0),
        .init(id: "xiaoman", name: "许小满", initial: "X", role: "会员", interests: "露营 · 户外咖啡", introduction: "希望在每个晴朗的周末，和伙伴们一起拥抱自然。", tone: 2),
        .init(id: "zhouzhou", name: "舟舟", initial: "Z", role: "会员", interests: "骑行 · 轻徒步", introduction: "正在尝试更多户外活动，期待下次一起出发。", tone: 1)
    ]
}
