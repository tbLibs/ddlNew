import SwiftUI
import UIAdapter

/// 设置页展示，账户来源与敏感操作由父页面持有。
struct SettingsPageContent<Avatar: View, DeleteDestination: View>: View {
    @Environment(\.locale) private var localizationLocale
    let displayName: String
    let account: String
    let avatar: Avatar
    let deleteDestination: DeleteDestination
    let openPrivacyPolicy: () -> Void
    let openSupport: () -> Void
    let logout: () -> Void
    @State private var showingLanguageSettings = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 28.zoom()) {
            accountSummary
            section(L10n.tr("语言设置")) {
                Button { showingLanguageSettings = true } label: {
                    row(L10n.tr("语言"), detail: L10n.tr("简体中文、繁體中文、English"), symbol: "globe")
                        .padding(.horizontal, 16.zoom())
                }
                .accessibilityIdentifier("settings.language")
                .background(HomeTheme.surface, in: cardShape)
                .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
            }
            section(L10n.tr("消息通知")) {
                NavigationLink(destination: PushSettingsView()) {
                    row(L10n.tr("通知设置"), detail: L10n.tr("新消息通知、声音与震动"), symbol: "bell")
                        .padding(.horizontal, 16.zoom())
                }
                .accessibilityIdentifier("settings.notifications")
                .background(HomeTheme.surface, in: cardShape)
                .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
            }
            section(L10n.tr("隐私与支持")) {
                VStack(spacing: 0) {
                    Button(action: openPrivacyPolicy) {
                        row(L10n.tr("隐私政策"), detail: L10n.tr("了解个人信息的使用与保护"), symbol: "hand.raised")
                    }
                    .accessibilityIdentifier("settings.privacyPolicy")
                    divider
                    Button(action: openSupport) {
                        row(L10n.tr("使用支持"), detail: L10n.tr("查看帮助与联系方式"), symbol: "questionmark.circle")
                    }
                    .accessibilityIdentifier("settings.support")
                }
                .padding(.horizontal, 16.zoom())
                .background(HomeTheme.surface, in: cardShape)
                .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
            }
            section(L10n.tr("账户管理")) {
                NavigationLink(destination: deleteDestination) {
                    row(L10n.tr("注销账号"), detail: L10n.tr("永久注销，操作不可撤销"), symbol: "person.crop.circle.badge.minus")
                        .padding(.horizontal, 16.zoom())
                }
                .accessibilityIdentifier("deleteAccountEntry")
                .background(HomeTheme.surface, in: cardShape)
                .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
            }
            VStack(spacing: 12.zoom()) {
                Button(role: .destructive, action: logout) {
                    Text(L10n.tr("退出登录"))
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(HomeTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.vertical, 4.zoom())
                        .background(HomeTheme.surface, in: cardShape)
                        .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
                        .contentShape(cardShape)
                }
                .accessibilityIdentifier("settings.logout")
                Text(L10n.tr("退出登录后，活动记录会保留。"))
                    .font(.footnote).foregroundStyle(HomeTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20.zoom())
        .padding(.top, 24.zoom()).padding(.bottom, 32.zoom())
        .foregroundStyle(HomeTheme.text)
        .buttonStyle(SettingsPressStyle())
        .sheet(isPresented: $showingLanguageSettings) { LanguageSettingsView() }
    }

    private var accountSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16.zoom()))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16.zoom()))
        return layout {
            avatar.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7.zoom()) {
                Text(L10n.tr("当前账户")).font(.caption.weight(.medium))
                    .foregroundStyle(HomeTheme.secondaryText)
                Text(displayName).font(.title3.weight(.semibold))
                    .accessibilityIdentifier("settings.displayName")
                if !account.isEmpty {
                    Text(L10n.tr("账号：\(account)")).font(.subheadline)
                        .foregroundStyle(HomeTheme.secondaryText)
                        .accessibilityIdentifier("settings.account")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20.zoom())
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeTheme.mintSurface, in: cardShape)
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12.zoom()) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(HomeTheme.secondaryText)
                .padding(.leading, 4.zoom()).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func row(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12.zoom()) {
            Image(systemName: symbol).font(.system(size: 21.zoom()))
                .foregroundStyle(HomeTheme.forest)
                .frame(width: 26.zoom()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5.zoom()) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(HomeTheme.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.weight(.medium))
                .foregroundStyle(HomeTheme.secondaryText).accessibilityHidden(true)
        }
        .padding(.vertical, 18.zoom())
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 22.zoom(), style: .continuous) }
    private var divider: some View { Rectangle().fill(HomeTheme.border).frame(height: 0.5).accessibilityHidden(true) }
}

private struct SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
