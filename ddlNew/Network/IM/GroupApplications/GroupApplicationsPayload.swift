// Created by taobo on 2026/10/13.
import ObjectMapper

nonisolated struct GroupApplicationsPayload: Mappable {
    var records: [GroupApplicationPayload] = []
    var total = 0

    /// 整页校验后才接纳结果，坏行不能变成成功空页并触发通知清读。
    init?(map: Map) {
        guard let rows = map.JSON["records"] as? [[String: Any]],
              let total = GroupApplicationPayload.integer(map.JSON["total"]), total >= 0,
              rows.count <= total,
              rows.allSatisfy({ Mapper<GroupApplicationPayload>().map(JSON: $0) != nil }) else { return nil }
    }

    /// 保留真实分页总数，数字和字符串使用同一严格标量解析。
    mutating func mapping(map: Map) {
        records = (map.JSON["records"] as? [[String: Any]] ?? []).compactMap { Mapper<GroupApplicationPayload>().map(JSON: $0) }
        total = GroupApplicationPayload.integer(map.JSON["total"]) ?? 0
    }
}
