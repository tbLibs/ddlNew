import SwiftUI
import UIAdapter

/// 设置页展示，账户来源与敏感操作由父页面持有。
struct SettingsPageContent<DeleteDestination: View>: View {
    let displayName: String
    let account: String
    let deleteDestination: DeleteDestination
    let openPrivacyPolicy: () -> Void
    let openSupport: () -> Void
    let logout: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 28.zoom()) {
            accountSummary
            section("隐私与支持") {
                VStack(spacing: 0) {
                    Button(action: openPrivacyPolicy) {
                        row("隐私政策", detail: "了解个人信息的使用与保护", symbol: "hand.raised")
                    }
                    .accessibilityIdentifier("settings.privacyPolicy")
                    divider
                    Button(action: openSupport) {
                        row("使用支持", detail: "查看帮助与联系方式", symbol: "questionmark.circle")
                    }
                    .accessibilityIdentifier("settings.support")
                }
                .padding(.horizontal, 16.zoom())
                .background(HomeTheme.surface)
            }
            section("账户管理") {
                NavigationLink(destination: deleteDestination) {
                    row("注销账号", detail: "永久注销，操作不可撤销", symbol: "person.crop.circle.badge.minus")
                        .padding(.horizontal, 16.zoom())
                }
                .accessibilityIdentifier("deleteAccountEntry")
                .background(HomeTheme.surface)
            }

        }
        .padding(.horizontal, 20.zoom())
        .padding(.top, 24.zoom()).padding(.bottom, 32.zoom())
        .foregroundStyle(HomeTheme.text)
        .buttonStyle(SettingsPressStyle())
    }

    var logoutFooter: some View {
        VStack(spacing: 12.zoom()) {
            Button(role: .destructive, action: logout) {
                Text("退出登录").font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(MessagingActionButtonStyle(fullWidth: true))
            .accessibilityIdentifier("settings.logout")
            Text("退出登录后，活动记录会保留。")
                .font(.footnote).foregroundStyle(HomeTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20.zoom()).padding(.vertical, 12.zoom())
        .frame(maxWidth: HomeTheme.contentWidth).frame(maxWidth: .infinity)
        .background(HomeTheme.surface)
    }

    private var accountSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16.zoom()))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16.zoom()))
        return layout {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 28.zoom(), weight: .regular))
                .foregroundStyle(HomeTheme.forest)
                .frame(width: 56.zoom(), height: 56.zoom())
                .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 18.zoom()))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7.zoom()) {
                Text(displayName).font(.title3.weight(.semibold))
                    .accessibilityIdentifier("settings.displayName")
                if !account.isEmpty {
                    Text("账号：\(account)").font(.subheadline)
                        .foregroundStyle(HomeTheme.secondaryText)
                        .accessibilityIdentifier("settings.account")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20.zoom())
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeTheme.surface)
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

    private var divider: some View { Rectangle().fill(HomeTheme.border).frame(height: 0.5).accessibilityHidden(true) }
}

private struct SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
