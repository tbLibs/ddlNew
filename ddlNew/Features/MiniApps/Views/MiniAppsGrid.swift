//
//  MiniAppsGrid.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI

/// 常规字号使用自适应应用网格，辅助字号保留完整名称和独立操作按钮。
struct MiniAppsGrid: View {
    let items: [MiniAppRecord]
    let managing: Bool
    let select: (MiniAppRecord) -> Void
    let delete: (MiniAppRecord) -> Void
    let add: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(items) { record in
                    ZStack(alignment: .topLeading) {
                        Button { select(record) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                MiniAppIcon(resource: record.icon).frame(width: 72, alignment: .leading)
                                name(record).frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(minHeight: 64, alignment: .top).contentShape(Rectangle())
                        }.buttonStyle(MiniAppButtonStyle()).disabled(managing && !record.canEdit)
                        if managing && record.canDelete { deleteButton(record).offset(x: 26, y: -22).transition(.opacity.combined(with: .scale(scale: 0.75, anchor: .topTrailing))) }
                    }.padding(.top, 22)
                }
                addButton
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76, maximum: 108), spacing: 12, alignment: .top)], spacing: 16) {
                ForEach(items) { record in
                    ZStack(alignment: .top) {
                        Button { select(record) } label: {
                            VStack(spacing: 8) {
                                MiniAppIcon(resource: record.icon)
                                name(record).multilineTextAlignment(.center).lineLimit(2)
                            }.frame(maxWidth: .infinity, minHeight: 90, alignment: .top).contentShape(Rectangle())
                        }.buttonStyle(MiniAppButtonStyle()).disabled(managing && !record.canEdit)
                        if managing && record.canDelete { deleteButton(record).offset(x: 24, y: -22).transition(.opacity.combined(with: .scale(scale: 0.75, anchor: .topTrailing))) }
                    }.padding(.top, 22)
                }
                addButton.padding(.top, 22)
            }
        }
    }
    private func name(_ record: MiniAppRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if record.passwordEnabled { Image(systemName: "lock.fill").font(.caption2).accessibilityHidden(true) }
            Text(record.name).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }.foregroundStyle(MessagingTheme.text)
            .accessibilityLabel(record.name + (record.passwordEnabled ? "，需要访问密码" : "") + (managing && !record.canEdit ? "，系统应用不可编辑" : ""))
    }
    private func deleteButton(_ record: MiniAppRecord) -> some View {
        Button(role: .destructive) { delete(record) } label: {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .symbolRenderingMode(.palette).foregroundStyle(.white, MessagingTheme.error)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(MiniAppButtonStyle()).accessibilityLabel("删除" + record.name)
    }
    private var addButton: some View {
        Button(action: add) {
            VStack(spacing: 8) {
                Image(systemName: "plus").font(.title2).frame(width: 48, height: 48)
                    .background(MessagingTheme.avatarBackground, in: RoundedRectangle(cornerRadius: 12))
                Text("添加应用").font(.subheadline)
            }.foregroundStyle(MessagingTheme.accent).frame(maxWidth: .infinity, minHeight: 90, alignment: .top).contentShape(Rectangle())
        }.buttonStyle(MiniAppButtonStyle())
    }
}
