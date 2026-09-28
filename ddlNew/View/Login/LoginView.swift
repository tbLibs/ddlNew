//
//  LoginView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import SwiftUI
import TBBasicLib

/// 独立的登录页面，支持更换俱乐部和打开网页，不依赖旧版页面或会员状态。
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    /// 共享登录前连接状态；页面显示不代表 SDK 已完成握手。
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    /// 用户输入的会员卡号与密码；密码不写入本地缓存。
    @State private var card = ""
    @State private var password = ""
    /// 两个网页入口共用一个 Safari 弹窗，避免同时呈现多个浏览器。
    @State private var webLink: TBBasicLib.WebLink?
    /// 输入焦点仅用于键盘展示和收起，不影响 App 路由。
    @FocusState private var cardFocused: Bool
    @FocusState private var passwordFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                brandHeader
                loginForm
                auxiliaryActions
                legalEntries
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .background(LoginBackground())
        .scrollDismissesKeyboard(.interactively)
        .onSubmit(dismissKeyboard)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if cardFocused || passwordFocused {
                keyboardDismissBar
            }
        }
        .sheet(item: $webLink) { link in
            TBBasicLib.SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .onDisappear {
            viewModel.cancelLogin()
            password = ""
        }
    }

    /// 保留旧版品牌展示，后续接入系统配置时再替换名称和图标。
    private var brandHeader: some View {
        VStack(spacing: 16) {
            Text("远山")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(LoginPalette.darkTeal)
                .frame(width: 74, height: 74)
                .background(LoginPalette.wash)
                .clipShape(RoundedRectangle(cornerRadius: 25))

            Text("远山户外俱乐部")
                .font(.system(size: 25, weight: .bold))

            Text("会员登录")
                .font(.system(size: 12))
                .foregroundColor(LoginPalette.secondary)
        }
        .padding(.top, 48)
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            LoginField(
                title: "会员卡号",
                placeholder: "请输入会员卡号",
                icon: "person",
                text: $card,
                focus: $cardFocused
            )
            .disabled(viewModel.loginPhase.isBusy)

            Text("例如 YS20260018，会员卡号区分字母和数字")
                .font(.system(size: 11))
                .foregroundColor(LoginPalette.secondary)

            LoginField(
                title: "密码",
                placeholder: "请输入密码",
                icon: "lock",
                text: $password,
                secure: true,
                focus: $passwordFocused
            )
            .disabled(viewModel.loginPhase.isBusy)
            .padding(.top, 12)

            Text("密码由俱乐部创建会员账户时提供")
                .font(.system(size: 11))
                .foregroundColor(LoginPalette.secondary)
                .accessibilityIdentifier("loginHint")

            // 不因缓存重连禁用按钮；请求期间防止重复提交，发送前由服务检查真实连接。
            Button(viewModel.loginPhase.buttonTitle, action: login)
                .buttonStyle(LoginButtonStyle())
                .disabled(card.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || viewModel.loginPhase.isBusy)
                .padding(.top, 10)
                .accessibilityIdentifier("login")

            loginRequestStatus

            Text(connection.phase.message)
                .font(.footnote)
                .foregroundColor(LoginPalette.secondary)
                .accessibilityIdentifier("loginConnectionStatus")
            if case .failed = connection.phase {
                Button("重试连接") {
                    viewModel.cancelLogin()
                    connection.startCachedReconnect()
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("retryLoginConnection")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoginPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LoginPalette.border, lineWidth: 1)
        }
    }

    /// 成功只确认接口返回，不把当前页面伪装成已经建立完整登录会话。
    @ViewBuilder
    private var loginRequestStatus: some View {
        switch viewModel.loginPhase {
        case .fetchingKey, .submitting:
            ProgressView()
                .accessibilityLabel(viewModel.loginPhase.buttonTitle)
        case .succeeded:
            Text("登录请求成功，后续会话处理尚未接入")
                .font(.footnote)
                .foregroundColor(LoginPalette.darkTeal)
                .accessibilityIdentifier("loginRequestSuccess")
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundColor(.red)
                .accessibilityIdentifier("loginRequestError")
        case .idle:
            EmptyView()
        }
    }

    private var auxiliaryActions: some View {
        HStack(spacing: 32) {
            // 仅保留帮助入口样式，暂不打开帮助页面。
            Button("登录遇到问题？", action: dismissKeyboard)
            Button("更换俱乐部", action: changeClub)
                .accessibilityIdentifier("changeClub")
        }
        .font(.system(size: 14))
        .foregroundColor(LoginPalette.darkTeal)
        .padding(.top, 5)
    }

    /// 使用 Safari 内嵌浏览器打开在线网页，不引用旧版法律页面或资源文件。
    private var legalEntries: some View {
        HStack(spacing: 24) {
            Button("隐私政策") { openWebPage(privacyPolicyURLString) }
                .accessibilityIdentifier("openPrivacyPolicy")
            Button("使用支持") { openWebPage(usageSupportURLString) }
                .accessibilityIdentifier("openSupport")
        }
        .font(.footnote)
        .foregroundColor(LoginPalette.darkTeal)
        .frame(minHeight: 44)
    }

    private var keyboardDismissBar: some View {
        HStack {
            Spacer()
            Button("完成", action: dismissKeyboard)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(LoginPalette.darkTeal)
                .frame(minWidth: 60, minHeight: 44)
                .accessibilityIdentifier("keyboardDone")
        }
        .padding(.horizontal, 16)
        .background(LoginPalette.card)
    }

    private func dismissKeyboard() {
        cardFocused = false
        passwordFocused = false
    }

    private func login() {
        dismissKeyboard()
        viewModel.login(account: card, password: password)
    }

    private func changeClub() {
        dismissKeyboard()
        card = ""
        password = ""
        viewModel.changeClub()
    }

    private func openWebPage(_ address: String) {
        dismissKeyboard()
        // Safari 只接受 HTTP/HTTPS；配置中统一使用 HTTPS，不加载本地旧版文档。
        guard let url = URL(string: address), url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        webLink = TBBasicLib.WebLink(url: url)
    }
}

/// 登录页专属配色，使用新项目的颜色转换能力。
private enum LoginPalette {
    static let background = Color(hex: "FAF8F4")
    static let card = Color(hex: "FFFDF9")
    static let ink = Color(hex: "173D3B")
    static let secondary = Color(hex: "667A77")
    static let teal = Color(hex: "00B9B1")
    static let darkTeal = Color(hex: "008C86")
    static let border = Color(hex: "DDD8CF")
    static let pale = Color(hex: "D1F2F0")
    static let wash = LinearGradient(
        colors: [pale, Color(hex: "F5F9F8")],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let action = LinearGradient(
        colors: [Color(hex: "00C7BE"), Color(hex: "00A69F")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 账号和密码输入组件，密码显隐状态只在当前组件内保存。
private struct LoginField: View {
    let title: String
    let placeholder: String
    /// 使用新项目 Assets 中的图标，不引用旧版图标组件。
    let icon: String
    @Binding var text: String
    var secure = false
    var focus: FocusState<Bool>.Binding
    @State private var passwordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            HStack(spacing: 12) {
                Image("club-\(icon)")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(LoginPalette.darkTeal)
                    .accessibilityHidden(true)

                Group {
                    if secure && !passwordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(LoginPalette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(secure ? .password : .username)
                .submitLabel(.done)
                .focused(focus)
                .accessibilityLabel(title)
                .accessibilityIdentifier("field.\(icon)")
                .frame(height: 36)

                if secure {
                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image("club-eye")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundColor(LoginPalette.darkTeal)
                            .frame(width: 44, height: 44)
                            .background(LoginPalette.wash)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(LoginPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(LoginPalette.border, lineWidth: 1)
            }
        }
    }
}

/// 登录按钮的纯视觉样式，禁用状态随输入是否为空更新。
private struct LoginButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background {
                LoginPalette.action.opacity(isEnabled ? 1 : 0.42)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: LoginPalette.teal.opacity(isEnabled ? 0.14 : 0), radius: 14, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 登录页渐变背景和圆形装饰，与其他页面没有代码依赖。
private struct LoginBackground: View {
    var body: some View {
        GeometryReader { proxy in
            LoginPalette.wash
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(LoginPalette.pale.opacity(0.3))
                        .overlay {
                            Circle().stroke(LoginPalette.teal.opacity(0.12), lineWidth: 1)
                        }
                        .frame(width: 342, height: 342)
                        .offset(x: -139, y: proxy.size.height * 0.14)
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    LoginView()
}
