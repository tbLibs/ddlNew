import SwiftUI
import Translation

struct QuickTranslationView: View {
    let active: Bool
    let onClose: () -> Void
    var body: some View {
        if #available(iOS 18.0, *) {
            SystemTranslationView(active: active, onClose: onClose)
        } else {
            VStack(spacing: 24) {
                HStack {
                    Text(L10n.tr("翻译")).font(.largeTitle.bold())
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "chevron.up").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.tr("收起顶部页面"))
                    .accessibilityIdentifier("messagePullDown.close")
                }
                Spacer()
                Image(systemName: "character.bubble").font(.system(size: 48))
                    .accessibilityHidden(true)
                Text(L10n.tr("文字翻译需要 iOS 18 或更高版本，请升级系统后使用。"))
                    .font(.body).multilineTextAlignment(.center)
                    .foregroundStyle(MessagingTheme.secondaryText)
                Spacer()
                Button(action: onClose) {
                    Label(L10n.tr("上滑收起"), systemImage: "chevron.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("translation.collapse")
                .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded {
                    if $0.translation.height < -50 { onClose() }
                })
            }.padding(.horizontal, 24).padding(.top, 12)
                .background(MessagingTheme.surface)
                .tint(MessagingTheme.accent)
                .accessibilityAction(.escape, onClose)
        }
    }
}

@available(iOS 18.0, *)
private struct SystemTranslationView: View {
    let active: Bool
    let onClose: () -> Void
    @Environment(\.locale) private var locale
    @FocusState private var editing: Bool
    @State private var input = ""
    @State private var output = ""
    @State private var source = "auto"
    @State private var target = "en"
    @State private var languages: [Locale.Language] = []
    @State private var request: TranslationRequest?
    @State private var busy = false
    @State private var generation = UUID()
    @State private var error: String?
    @State private var feedback: String?
    @State private var feedbackRevision = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.tr("翻译")).font(.largeTitle.bold())
                Spacer()
                Button(action: close) { Image(systemName: "chevron.up").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.tr("收起顶部页面"))
                    .accessibilityIdentifier("messagePullDown.close")
            }.padding(.horizontal, 24).padding(.vertical, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    languageBar
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(L10n.tr("原文")).font(.headline)
                            Spacer()
                            PasteButton(payloadType: String.self) { values in
                                input = values.joined(separator: "\n")
                            }.labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel(L10n.tr("粘贴"))
                            Button { input = "" } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }
                                .accessibilityLabel(L10n.tr("清空原文")).disabled(input.isEmpty)
                        }
                        TextEditor(text: $input)
                            .focused($editing).frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel(L10n.tr("输入需要翻译的文字"))
                            .accessibilityIdentifier("translation.input")
                            .overlay(alignment: .topLeading) {
                                if input.isEmpty {
                                    Text(L10n.tr("输入或粘贴文字"))
                                        .foregroundStyle(MessagingTheme.secondaryText)
                                        .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                                        .accessibilityHidden(true)
                                }
                            }
                        Text("\(input.count) / 1000").font(.caption.monospacedDigit())
                            .foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, alignment: .trailing)
                    }.disabled(busy)
                    Button(action: translate) {
                        HStack(spacing: 12) {
                            if busy { ProgressView().tint(MessagingTheme.onPrimaryAction) }
                            Text(L10n.tr(busy ? "正在翻译" : "翻译文字")).font(.headline)
                        }.frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.plain)
                        .foregroundStyle(MessagingTheme.onPrimaryAction)
                        .background(MessagingTheme.primaryAction, in: RoundedRectangle(cornerRadius: 14))
                        .opacity(canTranslate || busy ? 1 : 0.5).disabled(!canTranslate)
                        .accessibilityIdentifier("translation.submit")
                    if busy { Button(L10n.tr("取消")) { cancel() }.frame(minHeight: 44) }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(MessagingTheme.error).font(.callout)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(L10n.tr("译文")).font(.headline)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = output
                                feedback = L10n.tr("已复制"); feedbackRevision += 1
                            } label: { Label(L10n.tr("复制"), systemImage: "doc.on.doc").frame(minHeight: 44) }
                                .disabled(output.isEmpty || busy)
                        }
                        Text(output.isEmpty ? L10n.tr("翻译结果将显示在这里") : output)
                            .font(.title3).textSelection(.enabled)
                            .foregroundStyle(output.isEmpty ? MessagingTheme.secondaryText : MessagingTheme.text)
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                            .accessibilityIdentifier("translation.result")

                    }
                    Text(L10n.tr("由苹果系统提供翻译，首次使用可能需要下载语言包。"))
                        .font(.footnote).foregroundStyle(MessagingTheme.secondaryText)

                }.frame(maxWidth: 640).padding(.horizontal, 24).padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
            Button(action: close) {
                Label(L10n.tr("上滑收起"), systemImage: "chevron.up")
                    .font(.footnote).frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }.accessibilityIdentifier("translation.collapse")
            .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded {
                if $0.translation.height < -50 { close() }
            })
        }
        .background(MessagingTheme.surface)
        .tint(MessagingTheme.accent)
        .messagingFeedbackToast(feedback, trigger: feedbackRevision)
        .accessibilityAction(.escape, close)
        .task(id: active) {
            guard active, languages.isEmpty else { return }
            languages = await LanguageAvailability().supportedLanguages
            if !languages.contains(where: { $0.minimalIdentifier == target }), let first = languages.first {
                target = first.minimalIdentifier
            }
        }
        .onChange(of: input) { value in
            if value.count > 1000 {
                input = String(value.prefix(1000))
                feedback = L10n.tr("最多输入1000个字符"); feedbackRevision += 1
            }
            output = ""; error = nil
        }
        .onChange(of: source) { _ in output = ""; error = nil }
        .onChange(of: target) { _ in output = ""; error = nil }
        .onChange(of: active) { if !$0 { cancel() } }
        .onDisappear { cancel() }
        .background {
            if let request {
                TranslationWorker(request: request, completion: { result in
                    guard generation == request.id, active else { return }
                    busy = false
                    switch result {
                    case .success(let text): output = text
                    case .failure:
                        error = L10n.tr("翻译未完成，请检查语言包和网络后重试，或更换语言。")
                    }
                    self.request = nil
                }).id(request.id)
            }
        }
    }

    private var canTranslate: Bool { !busy && !languages.isEmpty && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var languageBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { languagePicker(source: true); swap; languagePicker(source: false) }
            VStack(alignment: .leading, spacing: 8) { languagePicker(source: true); swap; languagePicker(source: false) }
        }.padding(12).background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 14)).disabled(busy)
    }
    private var swap: some View {
        Button {
            let old = source; source = target; target = old
        } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 44, height: 44) }
            .accessibilityLabel(L10n.tr("交换语言")).disabled(source == "auto")
    }
    private func languagePicker(source isSource: Bool) -> some View {
        Picker(L10n.tr(isSource ? "源语言" : "目标语言"), selection: isSource ? $source : $target) {
            if isSource { Text(L10n.tr("自动检测")).tag("auto") }
            ForEach(languages.sorted { name($0) < name($1) }, id: \.minimalIdentifier) {
                Text(name($0)).tag($0.minimalIdentifier)
            }
        }.pickerStyle(.menu).frame(minHeight: 44).frame(maxWidth: .infinity)
    }
    private func name(_ language: Locale.Language) -> String {
        locale.localizedString(forIdentifier: language.minimalIdentifier) ?? language.minimalIdentifier
    }
    private func translate() {
        editing = false; error = nil; output = ""
        guard source != target else { error = L10n.tr("请选择不同的源语言和目标语言"); return }
        generation = UUID(); busy = true
        request = TranslationRequest(id: generation, text: input.trimmingCharacters(in: .whitespacesAndNewlines), source: source, target: target)
    }
    private func cancel() { editing = false; generation = UUID(); request = nil; busy = false }

    private func close() { cancel(); onClose() }
}
