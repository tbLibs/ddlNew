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
                }

                // 邀请码输入卡片
                VStack(alignment: .leading, spacing: 10.zoom()) {
                    InvitationCodeField(text: $viewModel.invitationCode)

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

                LegalEntryLinks()
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

#Preview {
    InvitationCodeView()
}
