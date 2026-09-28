//
//  DDLApiRequest.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import RxSwift

/// 旧回调式请求入口的类型和订阅容器。
class DDLApiRequest {
    typealias RequestSuccessCallBack<T> = (_ response: T) -> Void
    typealias RequestFailCallBack = (_ response: Error?) -> Void
    static let share = DDLApiRequest()
    required init() { }
    let disposeBag = DisposeBagHelper.share.disposeBag
}
