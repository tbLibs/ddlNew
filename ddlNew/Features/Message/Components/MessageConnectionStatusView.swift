//
//  MessageConnectionStatusView.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//

import SwiftUI

struct MessageConnectionStatusView: View {
    @ObservedObject private var monitor = MessageConnectionMonitor.shared
    @ObservedObject private var recovery = MessageSessionRecovery.shared

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(monitor.status.title).font(.callout)
            if recovery.failureMessage != nil {
                Button("重试") { recovery.retry() }.frame(minHeight: 44)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(MessagingTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("messageConnectionState")
        .messagingFeedbackToast(recovery.failureMessage)
    }

    private var color: Color {
        switch monitor.status {
        case .online: return MessagingTheme.online
        case .connecting, .reconnecting: return .orange
        case .retrying, .offline, .localFailure: return .red
        }
    }
}
