import SwiftUI
import UIAdapter

/// 直接控制按钮整体高度，避免系统bordered样式在内容高度之外再次增加内边距。
struct MessagingActionButtonStyle: ButtonStyle {
    var fill: Color = MessagingTheme.primaryAction
    var foreground: Color = MessagingTheme.onPrimaryAction
    var border: Color? = nil
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16.zoom())
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .foregroundStyle(foreground)
            .background(fill, in: RoundedRectangle(cornerRadius: 12.zoom()))
            .overlay { RoundedRectangle(cornerRadius: 12.zoom()).stroke(border ?? .clear, lineWidth: 1) }
            .contentShape(RoundedRectangle(cornerRadius: 12.zoom()))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
