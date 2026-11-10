import Foundation

/// 来自xgd的SMS_country静态目录，随App发布；不请求远端登录配置。
nonisolated struct CallingCode: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let englishName: String
    let code: String
    let pinyin: String
    static let all: [CallingCode] = {
        guard let url = Bundle.main.url(forResource: "CallingCodes", withExtension: "json"),
              let data = try? Data(contentsOf: url), let rows = try? JSONDecoder().decode([CallingCode].self, from: data) else {
            return [CallingCode(id: "CN", name: "中国", englishName: "China", code: "86", pinyin: "zhongguo")]
        }
        return rows
    }()
    func matches(_ query: String) -> Bool {
        query.isEmpty || [name, englishName, code, pinyin].contains { $0.localizedCaseInsensitiveContains(query.replacingOccurrences(of: "+", with: "")) }
    }
}
