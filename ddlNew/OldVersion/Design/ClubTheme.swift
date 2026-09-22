import SwiftUI
import SwiftUIIntrospect

enum ClubTheme {
    static let background = Color(hex: 0xFAF8F4)
    static let card = Color(hex: 0xFFFDF9)
    static let ink = Color(hex: 0x173D3B)
    static let secondary = Color(hex: 0x667A77)
    static let teal = Color(hex: 0x00B9B1)
    static let darkTeal = Color(hex: 0x008C86)
    static let border = Color(hex: 0xDDD8CF)
    static let pale = Color(hex: 0xD1F2F0)
    static let error = Color(hex: 0xB4233F)
    static let wash = LinearGradient(colors: [pale, Color(hex: 0xF5F9F8)], startPoint: .leading, endPoint: .trailing)
    static let action = LinearGradient(colors: [Color(hex: 0x00C7BE), Color(hex: 0x00A69F)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct ClubIcon: View {
    let name: String
    var size: CGFloat = 18
    var body: some View {
        Image("club-\(name)").renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct ClubLogo: View {
    var size: CGFloat = 72
    var body: some View {
        Image("club-logo").resizable().scaledToFit()
            .frame(width: size * 222 / 142, height: size * 234 / 142)
            .frame(width: size, height: size).accessibilityLabel("活动空间")
    }
}

struct ClubBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ClubTheme.wash.overlay(alignment: .topLeading) {
                Circle().fill(ClubTheme.pale.opacity(0.3))
                    .overlay(Circle().stroke(ClubTheme.teal.opacity(0.12), lineWidth: 1))
                    .frame(width: 342, height: 342).offset(x: -139, y: proxy.size.height * 0.14)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct ClubButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white).frame(maxWidth: .infinity).frame(minHeight: 52)
            .background { ClubTheme.action.opacity(isEnabled ? 1 : 0.42) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: ClubTheme.teal.opacity(isEnabled ? 0.14 : 0), radius: 14, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ClubCard<Content: View>: View {
    var padding: CGFloat = 16
    var highlighted = false
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background { if highlighted { ClubTheme.wash } else { ClubTheme.card } }
            .clipShape(RoundedRectangle(cornerRadius: highlighted ? 28 : 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: highlighted ? 28 : 22, style: .continuous)
                .stroke(highlighted ? ClubTheme.teal.opacity(0.2) : ClubTheme.border, lineWidth: 1))
    }
}

struct ClubBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(ClubTheme.darkTeal)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(hex: 0xEFF9F8)).clipShape(Capsule())
    }
}

struct ClubScroll<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            content.frame(maxWidth: 600).frame(maxWidth: .infinity).padding(.bottom, 28)
        }
        .introspect(.scrollView, on: .iOS(.v15, .v16, .v17, .v18, .v26, .v27)) {
            $0.keyboardDismissMode = .interactive
        }
        .background(ClubTheme.background.ignoresSafeArea())
    }
}

struct ScreenHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
            Text(title).font(.system(size: 27, weight: .bold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ClubKeyboardDismissal: ViewModifier {
    let isFocused: Bool
    let dismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .padding(.bottom, isFocused ? 44 : 0)
            .overlay(alignment: .bottom) {
                if isFocused {
                    HStack {
                        Spacer()
                        Button("完成", action: dismiss)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ClubTheme.darkTeal)
                            .accessibilityIdentifier("keyboardDone")
                            .frame(minWidth: 60, minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .background(ClubTheme.card)
                }
            }
            .onSubmit(dismiss)
    }
}

struct ClubField: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var focus: FocusState<Bool>.Binding? = nil
    @FocusState private var localFocus: Bool
    @State private var passwordVisible = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold))
            HStack(spacing: 12) {
                ClubIcon(name: icon).foregroundColor(ClubTheme.darkTeal)
                Group {
                    if secure && !passwordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                    .font(.system(size: 15))
                    .foregroundColor(ClubTheme.ink)
                    .keyboardType(keyboard).submitLabel(.done).autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused(focus ?? $localFocus)
                    .textContentType(secure ? .password : (keyboard == .numberPad ? .oneTimeCode : .username))
                    .accessibilityLabel(title).accessibilityIdentifier("field.\(icon)")
                    .frame(height: 36)
                if secure {
                    Button { passwordVisible.toggle() } label: {
                        ClubIcon(name: "eye").frame(width: 44, height: 44)
                            .background(ClubTheme.wash).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.accessibilityLabel(passwordVisible ? "隐藏密码" : "显示密码")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(ClubTheme.background).clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClubTheme.border, lineWidth: 1))
        }
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ClubIcon(name: icon, size: 21).foregroundColor(ClubTheme.teal)
                .frame(width: 44, height: 44).background(ClubTheme.wash)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }.accessibilityLabel(label)
    }
}

struct ClubDetailChrome: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}
