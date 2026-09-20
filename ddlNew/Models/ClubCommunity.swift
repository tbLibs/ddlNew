import Foundation
import Combine

struct ClubMessage: Identifiable {
    let id: String
    let title: String
    var preview: String
    let body: String
    var time: String
    let icon: String
    let isNotice: Bool
    var unread: Bool
    var contactID: String? = nil

    static let samples: [Self] = [
        .init(id: "hike-reminder", title: "周六日落轻徒步", preview: "领队阿哲：集合点已确认，周六见！", body: "大家好，本次轻徒步在北山游客中心集合。请提前 15 分钟到达，穿防滑运动鞋，并带好饮用水。期待和大家一起看日落。", time: "14:32", icon: "map", isNotice: false, unread: true),
        .init(id: "club-notice", title: "俱乐部通知", preview: "本月活动报名规则调整", body: "为了让更多伙伴有机会参加活动，取消报名请至少提前 12 小时。空出的名额将按候补顺序释放，请留意活动状态。感谢你的理解与配合。", time: "11:20", icon: "bell", isNotice: true, unread: true),
        .init(id: "welcome", title: "会员服务", preview: "林夏，欢迎加入远山户外俱乐部", body: "很高兴与你相遇！你可以在活动页找到感兴趣的活动，也可以在通讯录中认识领队和同行伙伴。让我们从下一次出发开始，收集更多美好的户外回忆。", time: "09:16", icon: "shield", isNotice: true, unread: true),
        .init(id: "ride-chat", title: "城市夜骑 · 江畔线", preview: "小雨：今晚沿江的风景一定很美", body: "今晚的集合地点是滨江广场。出发前请检查自行车、车灯和头盔，跟随领队保持队形，安全享受沿江风景。", time: "昨天", icon: "users", isNotice: false, unread: false),
        .init(id: "bird-chat", title: "森林观鸟晨行", preview: "领队林野：分享一份观鸟准备清单", body: "建议带上望远镜、饮用水和防蚊用品，穿低饱和度的衣服。观察时请保持安静，与野生动物保持距离，一起守护这片自然。", time: "星期三", icon: "note", isNotice: false, unread: false),
        .init(id: "signup", title: "活动助手", preview: "你的城市夜骑报名已确认", body: "你已报名城市夜骑 · 江畔线。活动当天可在活动详情中查看集合信息，并到达现场后使用领队提供的签到码完成签到。", time: "星期二", icon: "calendar", isNotice: true, unread: false)
    ]
}

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

struct ChatEntry: Identifiable {
    let id: UUID
    let text: String
    let isOutgoing: Bool
    let time: String

    init(text: String, isOutgoing: Bool, time: String) {
        id = UUID()
        self.text = text
        self.isOutgoing = isOutgoing
        self.time = time
    }
}

@MainActor final class ClubCommunity: ObservableObject {
    @Published private(set) var messages = ClubMessage.samples
    @Published private(set) var favorites: Set<String> = ["azhe", "xiaoyu"]
    @Published private(set) var conversations: [String: [ChatEntry]] = Dictionary(uniqueKeysWithValues:
        ClubMessage.samples.map { ($0.id, [ChatEntry(text: $0.body, isOutgoing: false, time: $0.time)]) }
    )
    @Published var drafts: [String: String] = [:]
    let contacts = ClubContact.samples
    var unreadCount: Int { messages.filter(\.unread).count }

    func openConversation(with contact: ClubContact) -> ClubMessage {
        let id = "contact-\(contact.id)"
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].unread = false
            return messages[index]
        }
        let conversation = ClubMessage(id: id, title: contact.name, preview: "点击开始聊天", body: "", time: "", icon: "person", isNotice: false, unread: false, contactID: contact.id)
        conversations[id] = []
        messages.insert(conversation, at: 0)
        return conversation
    }

    func markRead(_ id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].unread = false
    }
    func markAllRead() {
        for index in messages.indices { messages[index].unread = false }
    }
    func sendMessage(in conversationID: String) {
        let text = (drafts[conversationID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let index = messages.firstIndex(where: { $0.id == conversationID }) else { return }
        let time = Date().formatted(date: .omitted, time: .shortened)
        conversations[conversationID, default: []].append(ChatEntry(text: text, isOutgoing: true, time: time))
        drafts[conversationID] = ""
        var conversation = messages.remove(at: index)
        conversation.preview = "我：\(text)"
        conversation.time = "刚刚"
        conversation.unread = false
        messages.insert(conversation, at: 0)
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }
    func eraseSession() {
        messages = []
        conversations = [:]
        drafts = [:]
        favorites = []
    }
}
