import SwiftUI
import UIKit

struct PushSettingsView: View {
    @ObservedObject private var push = PushCoordinator.shared
    @Environment(\.scenePhase) private var phase
    var body: some View {
        Form {
            Section {
                LabeledContent("系统通知", value:push.permission)
                Button("打开系统通知设置") {
                    if let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Section {
                Toggle("新消息通知",isOn:binding(\.enabled)).accessibilityIdentifier("push.enabled")
                Toggle("声音",isOn:binding(\.sound)).disabled(!push.preferences.enabled).accessibilityIdentifier("push.sound")
                Toggle("震动",isOn:binding(\.vibration)).disabled(!push.preferences.enabled).accessibilityIdentifier("push.vibration")
            } footer: {
                Text("声音和震动适用于应用内提醒。后台通知的声音和震动同时受系统设置控制。")
            }
            .disabled(!push.preferencesReady || push.isSaving || push.isLoading)
            if push.isLoading || push.isSaving { ProgressView(push.isSaving ? "正在保存…":"正在读取…") }
            if let error=push.errorMessage {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("重试") { push.refreshPreferences() }
                }
            }
            if let error=push.registrationError {
                Section { Text(error).foregroundStyle(.secondary); Button("重试注册") { push.retry() } }
            }
        }
        .navigationTitle("消息通知").navigationBarTitleDisplayMode(.inline)
        .tint(HomeTheme.forest)
        .task { push.refreshPreferences(); push.setForeground(phase == .active) }
    }
    private func binding(_ key: WritableKeyPath<PushPreferences,Bool>) -> Binding<Bool> {
        Binding(get:{push.preferences[keyPath:key]},set:{ value in
            var settings=push.preferences; settings[keyPath:key]=value
            Task { await push.savePreferences(settings) }
        })
    }
}
