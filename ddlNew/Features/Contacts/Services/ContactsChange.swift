//
//  ContactsChange.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

/// SDK 用户代理转给通讯录的数据事件，不携带跨线程可变 SDK 对象。
nonisolated enum ContactsChange: Sendable {
    /// AUTH 成功后 SDK 自动开始新一轮通讯录同步。
    case syncStarted
    /// 好友或分组发生变化，需要重新读取 SDK 数据库。
    case changed
    /// 跨端修改备注后，先请求最新好友资料再更新 SDK 数据库。
    case remarkChanged(String)
    case syncFinished
    /// 保留已有好友列表，并向页面显示同步失败原因。
    case syncFailed(String)
}
