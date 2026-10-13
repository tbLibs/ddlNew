// Created by taobo on 2026/10/13.
import ObjectMapper

nonisolated struct GroupApplicationsPayload: Mappable {
    var records: [GroupApplicationPayload] = []
    var total = 0
    /// 响应结构缺少记录数组时视为格式错误。
    init?(map: Map) { guard map.JSON["records"] is [Any], map.JSON["total"] != nil else { return nil } }
    /// 保留服务器总数，页面不能凭单页十条推断全部完成。
    mutating func mapping(map: Map) { records <- map["records"]; total <- map["total"] }
}
