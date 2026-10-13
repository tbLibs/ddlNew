// Created by taobo on 2026/10/13.
import Foundation

@MainActor
protocol ConversationOperationsClient: AnyObject {
    /// 请求成功并完成必要的本地数据库更新后返回。
    func perform(_ action: ConversationAction, conversation: ConversationRecord, userUID: String) async throws
}
