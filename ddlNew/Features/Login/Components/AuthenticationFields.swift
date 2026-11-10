import SwiftUI

enum AuthenticationFocus: Hashable { case identity, password, confirmation, code, invite }

struct AuthenticationTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(minHeight: 44).contentShape(Rectangle())
            .foregroundStyle(LoginPalette.darkTeal)
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.65 : 1)
    }
}

struct AuthenticationMethodPicker: View {
    @Binding var selection: AccountIdentity.Kind
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 0) { choices }
            } else {
                HStack(spacing: 0) { choices }
            }
        }
        .background(LoginPalette.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("登录注册方式")
    }
    private var choices: some View {
        ForEach(AccountIdentity.Kind.displayOrder, id: \.self) { kind in
            Button { selection = kind } label: {
                HStack(spacing: 6) {
                    if selection == kind { Image(systemName: "checkmark").font(.caption.weight(.bold)).accessibilityHidden(true) }
                    Text(kind.title).font(.subheadline.weight(selection == kind ? .semibold : .regular))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
                .foregroundStyle(selection == kind ? LoginPalette.darkTeal : LoginPalette.secondary)
                .background(selection == kind ? LoginPalette.pale : .clear)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection == kind ? .isSelected : [])
            .accessibilityIdentifier("authMethod.\(kind.rawValue)")
        }
    }
}

struct AuthenticationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let field: AuthenticationFocus
    var focus: FocusState<AuthenticationFocus?>.Binding
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var prefix: String? = nil
    var selectPrefix: (() -> Void)? = nil
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium))
            HStack(spacing: 12) {
                if let prefix {
                    Button(action: { selectPrefix?() }) {
                        HStack(spacing: 5) {
                            Text("+\(prefix)").monospacedDigit()
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold)).accessibilityHidden(true)
                        }.frame(minWidth: 60, minHeight: 44)
                    }
                    .foregroundStyle(LoginPalette.darkTeal)
                    .accessibilityLabel("国家或地区区号，+\(prefix)")
                    .accessibilityIdentifier("chooseCallingCode")
                }
                Group {
                    if secure && !isPasswordVisible { SecureField(title, text: $text, prompt: Text(placeholder).foregroundColor(LoginPalette.secondary)) }
                    else { TextField(title, text: $text, prompt: Text(placeholder).foregroundColor(LoginPalette.secondary)) }
                }
                .font(.body).textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(keyboard).textContentType(contentType)
                .focused(focus, equals: field).submitLabel(.done)
                .accessibilityLabel(title).accessibilityIdentifier("authField.\(field)")
                .frame(minHeight: 44)
                if secure {
                    Button { isPasswordVisible.toggle() } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(LoginPalette.secondary)
                    .accessibilityLabel(isPasswordVisible ? "隐藏密码" : "显示密码")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(LoginPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(focus.wrappedValue == field ? LoginPalette.darkTeal : LoginPalette.border, lineWidth: focus.wrappedValue == field ? 2 : 1) }
        }
        .foregroundStyle(LoginPalette.ink)
    }
}

struct AccountIdentityField: View {
    let kind: AccountIdentity.Kind
    @Binding var value: String
    @Binding var areaCode: String
    var focus: FocusState<AuthenticationFocus?>.Binding
    @State private var choosingCode = false
    var body: some View {
        AuthenticationField(title: kind.title, placeholder: "请输入\(kind.title)", text: $value,
            field: .identity, focus: focus, keyboard: kind == .phone ? .phonePad : .asciiCapable,
            contentType: kind == .phone ? .telephoneNumber : .username,
            prefix: kind == .phone ? areaCode : nil, selectPrefix: { focus.wrappedValue = nil; choosingCode = true })
        .sheet(isPresented: $choosingCode) { CallingCodePicker(selection: $areaCode) }
    }
}

struct AccountCodeField: View {
    @Binding var code: String
    let identity: AccountIdentity
    let purpose: AccountCodePurpose
    let scope: String
    @ObservedObject var sender: AccountCodeViewModel
    var focus: FocusState<AuthenticationFocus?>.Binding
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AuthenticationField(title: "验证码", placeholder: "请输入6位验证码", text: $code, field: .code,
                focus: focus, keyboard: .numberPad, contentType: .oneTimeCode)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = sender.remaining(for: identity, purpose: purpose, scope: scope, at: context.date)
                Button {
                    focus.wrappedValue = nil
                    sender.send(to: identity, purpose: purpose, scope: scope)
                } label: {
                    Text(sender.isSending ? "正在发送…" : remaining > 0 ? "\(remaining)秒后重新获取" : "获取验证码")
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                        .frame(minHeight: 44)
                }
                .buttonStyle(AuthenticationTextButtonStyle())
                .disabled(sender.isSending || remaining > 0 || (try? identity.validate()) == nil)
                .accessibilityIdentifier("sendVerificationCode")
            }
        }
        .tint(LoginPalette.darkTeal)
    }
}

struct CallingCodePicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        NavigationStack {
            List(CallingCode.all.filter { $0.matches(search) }) { item in
                Button {
                    selection = item.code; dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).foregroundStyle(LoginPalette.ink)
                            Text(item.englishName).font(.caption).foregroundStyle(LoginPalette.secondary)
                        }
                        Spacer(minLength: 16)
                        Text("+\(item.code)").foregroundStyle(LoginPalette.darkTeal).monospacedDigit()
                    }.frame(minHeight: 44)
                }
            }
            .searchable(text: $search, prompt: "搜索国家、地区或区号")
            .navigationTitle("国家或地区").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }.tint(LoginPalette.darkTeal)
    }
}
