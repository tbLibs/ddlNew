//
//  MiniAppPresentation.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI

/// 浮窗挂在主Tab上，跨Tab可达；网页及密码呈现均由同一个认证所有者协调。
struct MiniAppPresentation: ViewModifier {
    @Environment(\.locale) private var localizationLocale
    @ObservedObject var feature: MiniAppsFeature
    @ObservedObject private var runtime = ChatRuntime.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floatingPosition = MiniAppFloatingPosition()
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    if !feature.floats.isEmpty && feature.active == nil {
                        Image(systemName: "square.stack.3d.up")
                                .font(.title3.weight(.medium)).foregroundStyle(MessagingTheme.onPrimaryAction)
                                .frame(width: 48, height: 48).background(MessagingTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(L10n.tr("应用浮窗，\(feature.floats.count)个网页"))
                        .accessibilityHint(L10n.tr("轻点恢复或管理网页，也可以拖动改变位置"))
                        .position(floatingPosition.position(in: proxy.size))
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("miniAppFloatingSpace")).onChanged { value in
                            floatingPosition.update(translation: value.translation, in: proxy.size)
                        }.onEnded { value in
                            var settled = floatingPosition
                            if settled.finish(translation: value.translation, in: proxy.size) {
                                floatingPosition = settled
                                feature.showsFloats = true
                            } else {
                                // 仅松手贴边时动画，拖动中的坐标更新始终即时跟手。
                                withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                                    floatingPosition = settled
                                }
                            }
                        })
                        .accessibilityAction { feature.showsFloats = true }
                        .accessibilityAction(named: L10n.tr("移到左侧")) { floatingPosition.rightEdge = false }
                        .accessibilityAction(named: L10n.tr("移到右侧")) { floatingPosition.rightEdge = true }
                        .accessibilityAction(named: L10n.tr("移到顶部")) { floatingPosition.restingY = 80 }
                        .accessibilityAction(named: L10n.tr("移到底部")) { floatingPosition.restingY = max(80, proxy.size.height - 120) }
                        .onDisappear { floatingPosition.cancel() }
                    }
                }.coordinateSpace(name: "miniAppFloatingSpace").allowsHitTesting(feature.active == nil && !feature.floats.isEmpty)
            }
            .fullScreenCover(item: $feature.active) { session in
                MiniAppBrowserView(session: session, close: { feature.finish(minimized: false) }, minimize: { feature.finish(minimized: true) })
                    .messagingFeedbackToast(feature.feedback)
            }
            .sheet(isPresented: $feature.showsFloats, onDismiss: feature.floatListDismissed) { MiniAppFloatList(feature: feature) }
            .sheet(item: $feature.passwordRequest, onDismiss: feature.passwordDismissed) { record in
                if let store = feature.store { MiniAppPasswordView(store: store, record: record) { value, _ in feature.acceptRestore(value) } }
            }
            .messagingLoadingToast(feature.busy, title: L10n.tr("正在恢复应用"))
            .messagingFeedbackToast(feature.feedback)
            .onAppear { feature.activate() }
            .onChange(of: runtime.revision) { _ in feature.activate() }
    }
}

private struct MiniAppFloatList: View {
    @Environment(\.locale) private var localizationLocale
    @ObservedObject var feature: MiniAppsFeature
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false
    var body: some View {
        NavigationStack {
            List {
                if feature.floats.isEmpty {
                    Text(L10n.tr("暂无浮窗网页")).foregroundStyle(MessagingTheme.secondaryText)
                }
                ForEach(feature.floats) { record in
                    HStack(spacing: 12) {
                        Button { feature.selectFloat(record) } label: {
                            HStack(spacing: 12) {
                                MiniAppIcon(resource: record.icon)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(record.title.isEmpty ? L10n.tr("应用网页") : record.title).font(.body).foregroundStyle(MessagingTheme.text).lineLimit(2)
                                    Text(MiniAppWebPolicy.url(record.url)?.host ?? L10n.tr("链接不可用")).font(.caption).foregroundStyle(MessagingTheme.secondaryText).lineLimit(1)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(minHeight: 56).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button(role: .destructive) { feature.removeFloat(id: record.id) } label: {
                            Image(systemName: "xmark.circle").frame(width: 44, height: 44)
                        }.buttonStyle(.borderless).accessibilityLabel(L10n.tr("移除浮窗：") + record.title)
                    }.padding(.vertical, 4)
                }
            }
            .navigationTitle(L10n.tr("应用浮窗")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("完成")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("清空"), role: .destructive) { confirmingClear = true }.disabled(feature.floats.isEmpty) }
            }
            .alert(L10n.tr("清空全部浮窗？"), isPresented: $confirmingClear) {
                Button(L10n.tr("取消"), role: .cancel) {}
                Button(L10n.tr("清空"), role: .destructive) { feature.clearFloats() }
            } message: { Text(L10n.tr("仅移除网页记录，不会删除我的应用。")) }
            .messagingFeedbackToast(feature.feedback)
        }.tint(MessagingTheme.accent)
    }
}
