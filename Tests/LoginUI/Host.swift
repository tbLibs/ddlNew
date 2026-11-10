import SwiftUI
import Combine

let mode = ProcessInfo.processInfo.arguments.dropFirst().first ?? "account"
let loginRememberPasswordAppStorageKey = "anonymous-auth-remember"
let privacyPolicyURLString = "https://example.invalid/privacy"
let usageSupportURLString = "https://example.invalid/support"
struct WebLink: Identifiable { let id = UUID(); let url: URL }
struct SafariView: View { let url: URL; var body: some View { Text("匿名预览：不访问外部文档") } }
extension View {
    func messagingLoadingToast(_ busy: Bool, title: String) -> some View { self }
    func messagingFeedbackToast(_ message: String?, isEnabled: Bool = true, presentInitial: Bool = false) -> some View { self }
}
@MainActor final class IMConnectionCoordinator: ObservableObject {
    enum Phase { case ready, failed; var message: String { "连接已就绪" } }
    static let shared = IMConnectionCoordinator()
    @Published var phase = Phase.ready
    @Published var loginConnectionID: UUID? = UUID()
    func ensureCachedReconnect() {}; func startCachedReconnect() {}; func reset() {}
}
struct UserInfo { var userUID = "anonymous-user" }
struct AccountLoginResponse { var userInfo: UserInfo? = UserInfo() }
struct RememberedLoginCredentials { var account: String; var password: String; var lastLiceseId: String; var loginType = 1; var areaCode = "" }
enum IMUserAuthenticationState: Equatable { case idle, ready, reconnecting, failed(String) }
@MainActor final class IMUserAuthenticationService { static let shared = IMUserAuthenticationService(); @Published var state = IMUserAuthenticationState.idle }
@MainActor final class UserSessionStore { static let shared = UserSessionStore(); var currentUser: UserInfo? }
@MainActor final class RememberedLoginStore {
 static let shared = RememberedLoginStore(); var record: RememberedLoginCredentials?
 func load(lastLiceseId: String) throws -> RememberedLoginCredentials? { record }
 func save(_ value: RememberedLoginCredentials) throws { record = value }; func clear() throws { record = nil }
}
@MainActor final class LoginSecurityCoordinator { static let shared = LoginSecurityCoordinator(); func prepareManualLoginPassword(_ p: String, userUID: String, lastLiceseId: String) {} }
@MainActor final class OSSConnectionBootstrap { static let shared = OSSConnectionBootstrap(); func clearCurrent() {} }
enum ShowAppPageType { case invitationCode }
@MainActor final class RouterTool { static let shared = RouterTool(); var showAppPage = ShowAppPageType.invitationCode }
@MainActor enum AppSessionRouter { static func enterMain() {} }
@MainActor final class AccountLoginService: AccountLoginServicing {
 static let shared = AccountLoginService()
 func login(account: String, password: String, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
  try await login(AccountLoginInput(identity: AccountIdentity(value: account), password: password), progress: progress)
 }
 func login(_ input: AccountLoginInput, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
  try input.validate(); progress(.submitting); try await Task.sleep(nanoseconds: 150_000_000); return AccountLoginResponse()
 }
}
@MainActor final class LoginSessionService: LoginSessionServicing {
 static let shared = LoginSessionService()
 func completeLogin(_ response: AccountLoginResponse, account: String, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws {
  progress(.authenticating); try await Task.sleep(nanoseconds: 150_000_000)
  if mode.contains("auth-fail") { throw AccountLoginError.businessFailure(code: 999, message: "匿名模拟认证失败") }
 }
 func cancelPendingLogin() {}; func clearSession() throws {}
}
@MainActor final class LoginSecurityNoticeStore: ObservableObject {
    static let shared = LoginSecurityNoticeStore(); @Published var message: String?
    func clear() { message = nil }
}
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore(); func lastUsableLiceseId() -> String? { "anonymous" }; func clearLastUsableEntry() throws {}
}
@MainActor protocol AccountRegistrationServicing {
 func register(_ input: AccountRegistrationInput, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse
}
@MainActor final class AccountRegistrationService: AccountRegistrationServicing {
 static let shared = AccountRegistrationService()
 static func currentContext() -> AccountRegistrationContext? { .init(connectionID: UUID(), registerMethod: "5", requiresInviteCode: false, requiresPasswordSymbol: false) }
 func register(_ input: AccountRegistrationInput, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
  try input.validate(in: Self.currentContext()!); progress(.submitting); try await Task.sleep(nanoseconds: 150_000_000); return AccountLoginResponse()
 }
}
nonisolated enum AccountCodePurpose: Int, Sendable { case registration = 1, login = 2 }
@MainActor protocol AccountCodeServicing { func send(to identity: AccountIdentity, purpose: AccountCodePurpose) async throws }
@MainActor final class AccountCodeService: AccountCodeServicing {
    static let shared = AccountCodeService()
    func send(to identity: AccountIdentity, purpose: AccountCodePurpose) async throws {
        if identity.kind == .phone {
            let data = UIGraphicsImageRenderer(size: CGSize(width: 180, height: 64)).image { _ in
                UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 180, height: 64))
                ("DEMO" as NSString).draw(at: CGPoint(x: 20, y: 14), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 28), .foregroundColor: UIColor.darkGray])
            }.pngData()
            _ = try await LoginVerificationCoordinator.shared.present(.init(kind: .imageCaptcha, message: "匿名预览：不会发送短信", imageData: mode.contains("bad-image") ? Data([0]) : data, title: "安全验证", submitTitle: "验证并发送", reloadImage: { try await Task.sleep(nanoseconds: 100_000_000); return data! }))
        }
    }
}
enum LoginCaptchaLoadState: Equatable { case loading, ready, failed(String); var isFailed: Bool { false } }
struct LoginCaptchaWebView: View {
    let kind: LoginVerificationKind; let stateChanged: (LoginCaptchaLoadState) -> Void
    let completed: (LoginVerificationAnswer) -> Void; let cancelled: () -> Void
    var body: some View { Text("匿名验证") }
}
struct Host: View {
    @ObservedObject private var language = AppLanguageStore.shared
    var body: some View {
        Group {
            if mode.contains("register") { AccountRegistrationView(initialKind: mode.contains("phone") ? .phone : .account) }
            else { LoginView() }
        }
        .environment(\.locale, language.locale)
        .environment(\.dynamicTypeSize, mode.contains("ax") ? .accessibility3 : .large)
        .task {
            if mode.contains("bottom") {
                try? await Task.sleep(nanoseconds: 700_000_000)
                func scroll(_ view: UIView) {
                    if let s = view as? UIScrollView, s.contentSize.height > s.bounds.height {
                        s.setContentOffset(CGPoint(x: 0, y: s.contentSize.height - s.bounds.height + s.adjustedContentInset.bottom), animated: false)
                    }
                    view.subviews.forEach(scroll)
                }
                UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).forEach(scroll)
            }
        }
    }
}
@main struct PreviewApp: App {
    init() {
        if mode != "language-restore" {
            AppLanguageStore.shared.select(mode.contains("english") ? .english : mode.contains("hant") ? .traditionalChinese : .simplifiedChinese)
        }
    }
    var body: some Scene { WindowGroup { Host() } } }
