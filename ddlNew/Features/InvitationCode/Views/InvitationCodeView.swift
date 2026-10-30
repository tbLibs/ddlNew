//
//  InvitationCodeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import SwiftUI
import UIAdapter

/// 邀请码入口页，仅负责界面展示，不包含校验、网络请求或页面跳转逻辑。
struct InvitationCodeView: View {
    
    /// 页面状态和后续业务逻辑统一由 ViewModel 管理。
    @StateObject private var viewModel = InvitationCodeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 22.zoom()) {
                // 顶部品牌区
                HStack(spacing: 10) {
                    InvitationCodeLogo(size: 42)
                    Text("叮咚聊").font(.title2.weight(.semibold))
                    Spacer()
                }.padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("连接俱乐部")
                        .font(.largeTitle.weight(.semibold))
                    Text("输入俱乐部提供的邀请码").font(.body).foregroundStyle(InvitationCodePalette.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 56)

                // 邀请码输入
                VStack(alignment: .leading, spacing: 10.zoom()) {
                    InvitationCodeField(text: $viewModel.invitationCode)

                    Button("连接俱乐部") {
                        viewModel.clickClub()
                    }
                    .buttonStyle(InvitationCodeButtonStyle())
                    .padding(.top, 54)
                    .accessibilityIdentifier("connectClub")
                    .disabled(viewModel.isRacing)


                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4.zoom())

                LegalEntryLinks()
                .font(.footnote)
                .foregroundStyle(InvitationCodePalette.darkTeal)
                .frame(minHeight: 44.zoom())

                Spacer(minLength: 24.zoom())
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 460.zoom())
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(InvitationCodeBackground())
        .messagingLoadingToast(viewModel.isRacing, title: "正在连接俱乐部")
        .messagingFeedbackToast(viewModel.isRacing ? nil : viewModel.statusMessage)
        .foregroundStyle(InvitationCodePalette.ink)
    }
}

#Preview {
    InvitationCodeView()
}
