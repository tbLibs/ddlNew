//
//  DisposeBagHelper.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import RxSwift

/// 保留旧 Rx 调用的订阅容器；async/await 的 DNS 请求不依赖它。
class DisposeBagHelper {
    public static let share = DisposeBagHelper()
    public required init() {}
    public let disposeBag = DisposeBag()
}
