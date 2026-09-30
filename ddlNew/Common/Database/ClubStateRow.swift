//
//  ClubStateRow.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import WCDBSwift

/// 本地俱乐部快照对应的 WCDB 数据行。
nonisolated final class ClubStateRow: TableCodable {
    var id: Int = 1
    var payload: String = ""
    enum CodingKeys: String, CodingTableKey {
        typealias Root = ClubStateRow
        case id, payload
        nonisolated(unsafe) static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
        }
    }
}
