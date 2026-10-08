import SwiftUI

enum RecordKind: String { case registered = "我的报名", waiting = "候补记录", checkedIn = "签到记录", past = "已参加活动" }
struct RecordsScreen: View {
    @EnvironmentObject private var store: ClubStore
    let kind: RecordKind
    private var records: [ClubActivity] {
        switch kind {
        case .registered: return store.activities(with: [.registered, .checkedIn])
        case .waiting: return store.activities(with: [.waiting])
        case .checkedIn, .past: return store.activities(with: [.checkedIn])
        }
    }
    var body: some View {
        ActivityNavigationScope {
        ClubScroll {
            VStack(spacing: 12) {
                if records.isEmpty {
                    EmptyClubState(title: "还没有相关记录", message: "参加一场感兴趣的活动，留下新的回忆。")
                    Button("发现活动") { store.selectedTab = .activities }.buttonStyle(ClubButtonStyle())
                } else { ForEach(records) { ActivityCard(activity: $0) } }
            }.padding(20)
        }.navigationBarHidden(false).navigationTitle(kind.rawValue).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CheckInSelectionScreen: View {
    @EnvironmentObject private var store: ClubStore
    var body: some View {
        ClubScroll {
            VStack(spacing: 14) {
                let activities = store.activities(with: [.registered, .checkedIn])
                if activities.isEmpty {
                    EmptyClubState(title: "暂无可签到的活动", message: "报名后，到达集合点即可输入活动签到码。")
                }
                ForEach(activities) { activity in
                    NavigationLink(destination: CheckInScreen(activity: activity)) {
                        ClubCard {
                            HStack(spacing: 14) {
                                ClubIcon(name: "scan", size: 24)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(activity.title).font(.headline)
                                    Text(activity.date).font(.caption).foregroundColor(ClubTheme.secondary)
                                }
                                Spacer()
                                ClubBadge(text: store.status(activity) == .checkedIn ? "已签到" : "去签到")
                            }.padding(.vertical, 10)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }.navigationBarHidden(false).navigationTitle("选择签到活动").navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyClubState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            ClubIcon(name: "calendar", size: 34).foregroundColor(ClubTheme.darkTeal)
                .frame(width: 78, height: 78).background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 24))
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundColor(ClubTheme.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 44)
    }
}

enum InformationPage: String, Identifiable {
    case loginHelp = "登录帮助", announcements = "俱乐部公告", benefits = "会员权益", rules = "活动规则", contact = "联系俱乐部", privacy = "隐私与安全"
    var id: Self { self }
    var paragraphs: [String] {
        switch self {
        case .loginHelp: return ["请检查邀请码、会员卡号或账号及密码是否输入正确。", "如仍无法登录，请在“使用支持”中查看联系方式。"]
        case .announcements: return ["本月活动报名规则调整", "取消报名请至少提前12小时，名额将按顺序释放给候补会员。", "请提前到达集合点，阅读活动须知，并按领队指引完成个人签到。"]
        case .benefits: return ["发现专属活动", "浏览俱乐部发布的户外活动，查看时间、集合点和参与要求。", "便捷管理参与记录", "在个人中心查看报名、候补和签到记录。"]
        case .rules: return ["选择适合自身状态和体能的活动，报名前认真阅读参与须知。", "取消报名请至少提前12小时；名额释放后，候补会员按顺序递补。", "到达集合点后完成个人签到，活动中遵守领队指引并保护自然环境。", "当前活动不判断实际日期。"]
        case .contact: return ["如需帮助，请联系俱乐部工作人员。", "如遇登录、报名或签到问题，请告知工作人员你的会员卡号和活动名称。"]
        case .privacy: return ["账号、活动、通讯录和消息相关信息用于提供对应功能。", "黑名单和消息举报记录可在“我的”页面查看。", "退出登录不会清除活动记录；如需注销账号，可前往“我的 → 设置 → 注销账号”。详细说明请查看隐私政策。"]
        }
    }
}

struct InformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let page: InformationPage
    var body: some View {
        NavigationView {
            ClubScroll {
                ClubCard(padding: 22) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(page.paragraphs, id: \.self) { Text($0).font(.system(size: 15)).lineSpacing(6).textSelection(.enabled) }
                    }
                }.padding(20)
            }.navigationTitle(page.rawValue).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var store: ClubStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false
    @State private var legalDocument: LegalDocument?
    var body: some View {
        NavigationView {
            Form {
                Section("会员账户") {
                    if let account = store.snapshot.activeAccount {
                        LabeledContentCompat(title: "账号", value: account)
                    } else {
                        LabeledContentCompat(title: "昵称", value: "林夏")
                        LabeledContentCompat(title: "会员卡号", value: "YS****18")
                    }
                }
                Section("隐私与支持") {
                    Button("隐私政策") { legalDocument = .privacy }
                    Button("使用支持") { legalDocument = .support }
                }
                Section {
                    Button("退出登录", role: .destructive) { confirmLogout = true }
                    NavigationLink(destination: DeleteAccountScreen()) {
                        Text("注销账号").foregroundColor(ClubTheme.error)
                    }.accessibilityIdentifier("deleteAccountEntry")
                } footer: { Text("活动空间") }
            }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .alert("退出会员空间？", isPresented: $confirmLogout) {
                    Button("取消", role: .cancel) { }
                    Button("退出登录", role: .destructive) { dismiss(); Task { await store.signOut() } }
                } message: { Text("退出登录后，活动记录会保留。") }
                .sheet(item: $legalDocument) { LegalDocumentScreen(document: $0) }
        }.navigationViewStyle(.stack).tint(ClubTheme.darkTeal)
    }
}
private struct LabeledContentCompat: View {
    let title: String
    let value: String
    var body: some View { HStack { Text(title); Spacer(); Text(value).foregroundColor(ClubTheme.secondary) } }
}
