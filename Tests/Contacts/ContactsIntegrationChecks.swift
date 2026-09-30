//
//  ContactsIntegrationChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import ObjectMapper

/// 验证真实通讯录状态边界，不使用测试账号、网络或 SDK 数据库。
@main
struct ContactsIntegrationChecks {
    @MainActor
    static func main() async {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let chinese = ContactRecord(id: "friend-a", account: "alpha", nickname: "阿哲")
        let renamed = ContactRecord(id: "friend-b", account: "bravo", nickname: "张三", remarks: "小雨")
        let deleted = ContactRecord(id: "deleted", nickname: "阿明", disableStatus: 4)
        let digit = ContactRecord(id: "digit", nickname: "123")
        let system = ContactRecord(id: "helper", nickname: "文件助手", userType: 1)
        check(chinese.initial == "A", "中文姓名应按拼音首字母分组")
        check(renamed.displayName == "小雨" && renamed.initial == "X", "备注优先于昵称参与显示和排序")
        check(deleted.displayName == "账号已注销" && deleted.initial == "#", "已注销账号应使用专用文案和分组")
        check(ContactRecord(id: "only-id").displayName == "only-id", "缺少名称时回退 UID")
        check(ContactSorter.sortName(for: "阿 哲") == "AZ", "排序键应去除空格和声调")
        let records = ContactSorter.sorted([deleted, system, digit, renamed, chinese, chinese, ContactRecord(id: "")])
        check(records.map(\.id) == ["friend-a", "friend-b", "digit", "deleted"], "过滤系统账号、空 UID、重复 UID，并将注销账号置后")
        check(ContactSorter.sections(from: records).map(\.id) == ["A", "X", "#"], "# 分组位于最后")
        check(ContactSorter.sections(from: records, matching: "张三").flatMap(\.contacts).map(\.id) == ["friend-b"], "备注修改后仍可以搜索原昵称")
        check(ContactSorter.sections(from: records, matching: " BRAVO ").flatMap(\.contacts).map(\.id) == ["friend-b"], "账号搜索忽略大小写及边界空格")
        check(ContactSorter.sections(from: records, matching: "不存在").isEmpty, "未匹配时返回真实空列表")
        let baseURL = URL(string: "https://files.example.com:3001")
        let avatar = ContactRecord(id: "avatar", avatar: "/oss/头像.png")
        check(avatar.avatarURL(relativeTo: baseURL)?.host == "files.example.com", "相对头像使用导航 Host")
        check(ContactRecord(id: "full", avatar: "https://cdn.example.com/a.png").avatarURL(relativeTo: baseURL)?.host == "cdn.example.com", "完整头像地址不重复拼接")
        check(deleted.avatarURL(relativeTo: baseURL) == nil, "已注销好友不加载真实头像")

        let client = MockContactsClient()
        let store = ContactsStore(client: client)
        store.prepare(for: "user-a")
        check(store.contacts.isEmpty && store.isSyncing, "AUTH 前只能监听，不能展示旧用户缓存")
        client.contacts = [chinese]
        await store.reload()
        check(store.contacts == [chinese], "AUTH 后读取 SDK 本地缓存")
        client.contacts = [renamed, chinese]
        client.onChange?(.syncFinished)
        await store.reload()
        check(store.contacts.count == 2 && !store.isSyncing, "首轮同步完成刷新列表")
        client.contacts = [renamed]
        client.onChange?(.changed)
        await store.reload()
        check(store.contacts == [renamed], "好友删除后刷新本地快照")
        client.onChange?(.syncFailed("网络异常"))
        check(store.contacts == [renamed] && store.errorMessage == "网络异常", "同步失败保留已有好友")
        client.onChange?(.syncFinished)
        await store.reload()
        check(store.errorMessage == "网络异常", "在线状态兜底完成不能掩盖好友同步失败")
        client.onChange?(.syncStarted)
        check(store.errorMessage == nil && store.isSyncing, "重连新一轮同步清除上一轮错误")
        let lateCallback = client.onChange
        store.reset()
        check(store.contacts.isEmpty && client.onChange == nil && !store.isSyncing, "退出时清理数据并移除代理")
        lateCallback?(.changed)
        check(store.contacts.isEmpty, "退出后的迟到回调不能恢复旧账号好友")
        client.activeUserUID = "user-b"
        client.contacts = [digit]
        store.prepare(for: "user-b")
        await store.reload()
        lateCallback?(.syncFinished)
        check(store.contacts == [digit] && store.isSyncing, "旧账号的完成事件不能污染新账号状态")
        client.failure = NSError(domain: "ContactsChecks", code: 2)
        await store.reload()
        check(store.contacts == [digit] && store.errorMessage != nil, "缓存读取失败不能覆盖已有列表")
        client.failure = nil
        client.contacts = []
        client.onChange?(.syncFinished)
        await store.reload()
        check(store.contacts.isEmpty, "无好友时显示真实空状态，不回退演示数据")
        check(store.errorMessage == nil, "缓存恢复成功后必须清除读取错误，不能继续显示列表不可用")
        check(!ContactSorter.sections(from: [ContactRecord(id: "pinyin", nickname: "张三")], matching: "zhangsan").isEmpty,
              "好友搜索应支持完整拼音，不只支持首字母")
        client.suspendNextLoad = true
        let oldRead = Task { await store.reload() }
        while client.pendingLoad == nil { await Task.yield() }
        let continuation = client.pendingLoad
        client.pendingLoad = nil
        store.reset()
        client.activeUserUID = "user-c"
        client.contacts = [chinese]
        store.prepare(for: "user-c")
        await store.reload()
        continuation?.resume(returning: [digit])
        await oldRead.value
        check(store.contacts == [chinese], "旧账号正在读取的缓存迟到后不能覆盖新账号")
        var versions = ContactRequestVersions()
        let oldVersion = versions.begin(for: "friend-a")
        let newVersion = versions.begin(for: "friend-a")
        let otherVersion = versions.begin(for: "friend-b")
        check(!versions.accepts(oldVersion, for: "friend-a") && versions.accepts(newVersion, for: "friend-a"),
              "同一好友的旧备注响应必须失效")
        versions.finish(oldVersion, for: "friend-a")
        check(versions.accepts(newVersion, for: "friend-a") && versions.accepts(otherVersion, for: "friend-b"),
              "过期响应不能移除最新请求，好友之间互不干扰")
        versions.finish(newVersion, for: "friend-a")
        check(!versions.accepts(newVersion, for: "friend-a"), "已完成资料请求不再接受重复响应")
        let cleared = Mapper<ContactProfilePayload>().map(JSON: ["remarks": NSNull(), "descRemark": NSNull()])
        check(cleared?.remarks == "" && cleared?.description == "", "服务端显式 null 应清空备注和描述")
        let missing = Mapper<ContactProfilePayload>().map(JSON: ["nickname": "新昵称"])
        check(missing?.remarks == nil && missing?.nickname == "新昵称", "缺失字段不能清空旧备注")
        let beforeBatch = client.loadCount
        client.onChange?(.changed)
        client.onChange?(.changed)
        await store.reload()
        check(client.loadCount == beforeBatch + 1, "同一批 SDK 变化事件只读取一次缓存")
        check(Mapper<ContactProfilePayload>().map(JSON: [:]) == nil, "空好友资料响应不能当作有效更新")
        check(Mapper<ContactProfilePayload>().map(JSON: ["remarks": ["错误类型"]]) == nil,
              "备注类型错误必须拒绝，不能当作更新成功")
        check(Mapper<ContactProfilePayload>().map(JSON: ["disableStatus": "4"])?.disableStatus == 4,
              "好友状态兼容整数字符串")
        check(Mapper<ContactProfilePayload>().map(JSON: ["disableStatus": 1.5]) == nil,
              "小数状态不能作为有效资料")
        client.contacts = [renamed]
        client.onChange?(.syncFailed("在线状态查询失败"))
        await store.reload()
        check(store.contacts == [renamed] && store.errorMessage == "在线状态查询失败",
              "同步失败仍应读取已经落库的好友，不隐藏已成功同步的数据")
        print("通讯录离线验证通过：\(checks) 项")
    }
}
