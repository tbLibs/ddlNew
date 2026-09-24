//
//  InvitationCodeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import SwiftUI
import TBBasicLib
import UIAdapter

/// 邀请码入口页，仅负责界面展示，不包含校验、网络请求或页面跳转逻辑。
struct InvitationCodeView: View {
    
    /// 页面状态和后续业务逻辑统一由 ViewModel 管理。
    @StateObject private var viewModel = InvitationCodeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 22.zoom()) {
                // 顶部品牌区
                InvitationCodeLogo(size: 60.zoom())
                    .padding(.top, 48.zoom())

                VStack(spacing: 10.zoom()) {
                    Text("连接你的俱乐部")
                        .font(.system(size: 25.zoom(), weight: .bold))

                    Text("输入邀请码后进入专属会员空间")
                        .font(.system(size: 12.zoom()))
                        .foregroundStyle(InvitationCodePalette.secondary)
                }

                // 邀请码输入卡片
                VStack(alignment: .leading, spacing: 10.zoom()) {
                    InvitationCodeField(text: $viewModel.invitationCode)

                    Text("请输入俱乐部提供的邀请码")
                        .font(.system(size: 11.zoom()))
                        .foregroundStyle(InvitationCodePalette.secondary)

                    Button("连接俱乐部") {
                        viewModel.clickClub()
                    }
                    .buttonStyle(InvitationCodeButtonStyle())
                    .padding(.top, 10.zoom())
                    .accessibilityIdentifier("connectClub")
                    .disabled(viewModel.isRacing)

                    if let statusMessage = viewModel.statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 11.zoom()))
                            .foregroundStyle(InvitationCodePalette.secondary)
                            .accessibilityIdentifier("ossRaceStatus")
                    }
                }
                .padding(20.zoom())
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(InvitationCodePalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 22.zoom(), style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22.zoom(), style: .continuous)
                        .stroke(InvitationCodePalette.border, lineWidth: 1.zoom())
                }
                .padding(.top, 4.zoom())

                // 辅助提示
                Text("没有邀请码？请联系俱乐部工作人员获取。")
                    .font(.system(size: 11.zoom()))
                    .foregroundStyle(InvitationCodePalette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14.zoom())
                    .background(InvitationCodePalette.card.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 15.zoom(), style: .continuous))

                // 仅保留入口文字，暂不接入跳转逻辑
                HStack(spacing: 24.zoom()) {
                    Text("隐私政策")
                    Text("使用支持")
                }
                .font(.footnote)
                .foregroundStyle(InvitationCodePalette.darkTeal)
                .frame(minHeight: 44.zoom())

                Spacer(minLength: 24.zoom())
            }
            .padding(.horizontal, 24.zoom())
            .frame(maxWidth: 460.zoom())
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(InvitationCodeBackground())
        .foregroundStyle(InvitationCodePalette.ink)
    }
}

/// 页面专属配色，颜色转换统一使用 TBBasicLib 提供的 Color(hex:)。
private enum InvitationCodePalette {
    static let background = Color(hex: "FAF8F4")
    static let card = Color(hex: "FFFDF9")
    static let ink = Color(hex: "173D3B")
    static let secondary = Color(hex: "667A77")
    static let teal = Color(hex: "00B9B1")
    static let darkTeal = Color(hex: "008C86")
    static let border = Color(hex: "DDD8CF")
    static let pale = Color(hex: "D1F2F0")
    static let wash = LinearGradient(
        colors: [
            pale,
            Color(hex: "F5F9F8")
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let action = LinearGradient(
        colors: [
            Color(hex: "00C7BE"),
            Color(hex: "00A69F")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 顶部俱乐部标志。
private struct InvitationCodeLogo: View {
    /// 调用方传入的尺寸已经通过 UIAdapter 适配。
    let size: CGFloat

    var body: some View {
        Image("club-logo")
            .resizable()
            .scaledToFit()
            .frame(width: size * 222 / 142, height: size * 234 / 142)
            .frame(width: size, height: size)
            .accessibilityLabel("活动空间")
    }
}

/// 邀请码标题与数字输入框。
private struct InvitationCodeField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10.zoom()) {
            Text("俱乐部邀请码")
                .font(.system(size: 12.zoom(), weight: .semibold))

            HStack(spacing: 12.zoom()) {
                Image("club-shield")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18.zoom(), height: 18.zoom())
                    .foregroundStyle(InvitationCodePalette.darkTeal)
                    .accessibilityHidden(true)

                TextField("例如 100001", text: $text)
                    .font(.system(size: 15.zoom()))
                    .foregroundStyle(InvitationCodePalette.ink)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .accessibilityLabel("俱乐部邀请码")
                    .accessibilityIdentifier("field.shield")
                    .frame(height: 36.zoom())
            }
            .padding(.horizontal, 16.zoom())
            .padding(.vertical, 14.zoom())
            .background(InvitationCodePalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 17.zoom(), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17.zoom(), style: .continuous)
                    .stroke(InvitationCodePalette.border, lineWidth: 1.zoom())
            }
        }
    }
}

/// “连接俱乐部”按钮的纯视觉样式。
private struct InvitationCodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15.zoom(), weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52.zoom())
            .background(InvitationCodePalette.action)
            .clipShape(RoundedRectangle(cornerRadius: 16.zoom(), style: .continuous))
            .shadow(
                color: InvitationCodePalette.teal.opacity(0.14),
                radius: 14.zoom(),
                y: 10.zoom()
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// 复刻旧页面的渐变背景与圆形装饰。
private struct InvitationCodeBackground: View {
    var body: some View {
        GeometryReader { proxy in
            InvitationCodePalette.wash
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(InvitationCodePalette.pale.opacity(0.3))
                        .overlay {
                            Circle()
                                .stroke(InvitationCodePalette.teal.opacity(0.12), lineWidth: 1.zoom())
                        }
                        .frame(width: 342.zoom(), height: 342.zoom())
                        .offset(x: (-139).zoom(), y: proxy.size.height * 0.14)
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    InvitationCodeView()
}
