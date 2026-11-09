//
//  MinePageContent.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import SwiftUI
import UIAdapter

/// 个人中心的展示布局；身份由登录会话传入，导航沿用当前 Tab 的值路由。
struct MinePageContent<Avatar: View>: View {
    let displayName: String
    let account: String
    let isSignedIn: Bool
    let avatar: Avatar
    let copyAccount: () -> Void
    let openProfile: () -> Void
    let openComplaint: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var nameSize = 24

    var body: some View {
        VStack(spacing: 0) {
            profile
            VStack(alignment: .leading, spacing: 24.zoom()) {
                section("账户与支持") { accountServices }
            }
            .padding(.horizontal, 20.zoom())
            .padding(.top, 24.zoom())
            .padding(.bottom, 28.zoom())
        }
        .foregroundStyle(HomeTheme.text)
        .buttonStyle(MinePressStyle())
    }

    /// 辅助字号改为纵向，给长昵称和账号完整的可换行宽度。
    private var profile: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16.zoom()))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16.zoom()))
        return layout {
            Button(action: openProfile) { avatar.accessibilityHidden(true) }
                .disabled(!isSignedIn)
                .accessibilityLabel("编辑个人资料，修改头像")
                .accessibilityIdentifier("mine.editAvatar")
            VStack(alignment: .leading, spacing: 4.zoom()) {
                Button(action: openProfile) {
                    HStack(spacing: 8.zoom()) {
                        Text(displayName)
                            .font(.system(size: nameSize, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if isSignedIn { chevron }
                    }.frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .disabled(!isSignedIn)
                .accessibilityLabel("编辑个人资料，昵称：\(displayName)")
                .accessibilityIdentifier("mine.editNickname")
                if isSignedIn, !account.isEmpty {
                    HStack(alignment: .top, spacing: 4.zoom()) {
                        Text("账号：\(account)")
                            .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 44, alignment: .leading)
                        Button(action: copyAccount) {
                            Image(systemName: "doc.on.doc")
                                .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("复制账号")
                        .accessibilityIdentifier("mine.copyAccount")
                    }
                }
                if isSignedIn {
                    NavigationLink(value: ContactsPageRoute.qrCode(groupID: nil, title: "我的二维码")) {
                        HStack(spacing: 8.zoom()) {
                            Image(systemName: "qrcode").accessibilityHidden(true)
                            Text("我的二维码").fixedSize(horizontal: false, vertical: true)
                            chevron
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HomeTheme.forest)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("mine.qrCode")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24.zoom())
        .padding(.vertical, 24.zoom())
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeTheme.surface, in: MineHeaderShape(radius: 28.zoom()))
    }

    private var accountServices: some View {
        VStack(spacing: 0) {
            NavigationLink(value: SafetyRoute.blacklist) { menuRow("黑名单", symbol: "person.crop.circle.badge.minus") }
                .accessibilityIdentifier("mine.blacklist")
            divider
            Button(action: openComplaint) { menuRow("投诉与支持", symbol: "headphones") }
                .accessibilityIdentifier("mine.complaint")
            divider
            NavigationLink(value: MineSupportRoute.network) { menuRow("网络检测", symbol: "network") }
                .accessibilityIdentifier("mine.network")
            divider
            NavigationLink(value: MineSupportRoute.about) { menuRow("关于我们", symbol: "info.circle") }
                .accessibilityIdentifier("mine.about")
        }
        .padding(.horizontal, 16.zoom())
        .background(HomeTheme.surface, in: cardShape)
        .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12.zoom()) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(HomeTheme.secondaryText).padding(.leading, 4.zoom())
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func menuRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12.zoom()) {
            Image(systemName: symbol).font(.system(size: 21.zoom()))
                .foregroundStyle(HomeTheme.forest).frame(width: 24.zoom()).accessibilityHidden(true)
            Text(title).font(.body).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            chevron
        }
        .padding(.vertical, 16.zoom())
        .frame(minHeight: max(44, 56.zoom()))
        .contentShape(Rectangle())
    }

    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 22.zoom(), style: .continuous) }
    private var divider: some View { Rectangle().fill(HomeTheme.border).frame(height: 0.5).accessibilityHidden(true) }
    private var chevron: some View {
        Image(systemName: "chevron.right").font(.caption.weight(.medium))
            .foregroundStyle(HomeTheme.secondaryText).accessibilityHidden(true)
    }
}

/// 按压只改变透明度，避免卡片缩放造成页面内容晃动。
private struct MinePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// iOS16 的身份区只圆下沿，顶部与原生导航栏自然相接。
private struct MineHeaderShape: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        return Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: r, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - r), control: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
