import SwiftUI

/// 诊断工作台：本轮结论、实时步骤与实际检测目标。
struct NetworkDiagnosticPageContent: View {
    let results: [NetworkDiagnosticResult]
    let running: Bool
    let completed: Bool
    let activeSection: String?
    let status: String
    let license: String
    var activeTargets: [String] = []
    var sources: [DNS1Source] = []
    let action: () -> Void
    @State private var expanded: Set<String> = []
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let sections = ["网络连接情况", "节点获取检测", "服务器连接检测"]
    private var hasServer: Bool { results.contains { $0.section == sections[2] && $0.passed } }
    private var failures: Int { results.filter { !$0.passed }.count }
    private var interrupted: Bool { !running && !completed && status != "准备检测" }
    private var heading: String {
        if running { return activeSection.flatMap { sections.firstIndex(of: $0) }.map { "正在" + stepTitle($0) } ?? "正在准备检测" }
        if completed { return hasServer ? "已找到可用连接" : "暂未找到可用连接" }
        return interrupted ? "检测未完成" : "检查你的连接"
    }
    private var summary: String {
        if running { return "逐项记录结果；当前来源不可用时，会继续尝试备用来源。" }
        if completed {
            if hasServer { return failures == 0 ? "本轮已执行的检查均通过。" : "已找到可用服务器，仍有 \(failures) 条未通过记录，详见下方。" }
            return "可先切换 Wi-Fi 或蜂窝网络再重测，并查看下方失败的地址。"
        }
        return interrupted ? status : "检查设备联网、外网地址与服务节点，帮助定位连接问题。"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !license.isEmpty {
                    Text("当前企业 · \(license)")
                        .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                overview
                VStack(alignment: .leading, spacing: 0) {
                    Text("检测详情").font(.headline).accessibilityAddTraits(.isHeader).padding(.bottom, 16)
                    ForEach(sections, id: \.self) { section in step(section) }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 28)
            .frame(maxWidth: HomeTheme.contentWidth).frame(maxWidth: .infinity)
        }
        .background(HomeTheme.background.ignoresSafeArea())
        .foregroundStyle(HomeTheme.text).tint(HomeTheme.forest)
        .onAppear { revealRelevantSections() }
        .onChange(of: activeSection) { section in
            if let section { expanded.insert(section) }
        }
        .task(id: completed) {
            if completed { expanded.formUnion(results.filter { !$0.passed }.map(\.section)) }
        }
    }

    private func revealRelevantSections() {
        if let activeSection, running { expanded.insert(activeSection) }
        if completed { expanded.formUnion(results.filter { !$0.passed }.map(\.section)) }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(heading).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(summary).font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if running, let target = activeTargets.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeTargets.count > 1 ? "正在检测 \(activeTargets.count) 个节点" : "当前目标")
                        .font(.caption).foregroundStyle(HomeTheme.secondaryText)
                    Text(verbatim: NetworkDiagnosticAddress.masked(target)).font(.subheadline.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                }.accessibilityElement(children: .combine)
            }
            Button {
                expanded = []
                action()
            } label: {
                Label(running ? "取消检测" : (completed || interrupted ? "重新检测" : "开始检测"),
                      systemImage: running ? "stop" : (completed || interrupted ? "arrow.clockwise" : "arrow.right"))
                    .font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }
            .buttonStyle(HomePressStyle())
            .foregroundStyle(running ? HomeTheme.forest : HomeTheme.background)
            .background(running ? HomeTheme.mintSurface : HomeTheme.forest, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHint(running ? "停止本轮检测并清空结果" : "开始新一轮检测")
            .accessibilityIdentifier("mine.network.retry")
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func step(_ section: String) -> some View {
        let rows = results.filter { $0.section == section }
        let active = running && activeSection == section
        let index = sections.firstIndex(of: section) ?? 0
        let state = NetworkDiagnosticStepState.resolve(passes: rows.map(\.passed), active: active,
            running: running, completed: completed, interrupted: interrupted)
        let tone = state.needsAttention ? HomeTheme.warmAccent : (state == .passed || active ? HomeTheme.forest : HomeTheme.secondaryText)
        let canExpand = !rows.isEmpty || active || (index == 1 && !sources.isEmpty)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(active ? HomeTheme.forest : HomeTheme.mintSurface)
                    if active { ProgressView().tint(HomeTheme.background).accessibilityHidden(true) }
                    else if state == .passed { Image(systemName: "checkmark").foregroundStyle(tone) }
                    else if state.needsAttention { Image(systemName: "exclamationmark").foregroundStyle(tone) }
                    else { Text(String(index + 1)).foregroundStyle(HomeTheme.secondaryText) }
                }.font(.subheadline.weight(.semibold)).dynamicTypeSize(.large)
                    .frame(width: 32, height: 32).accessibilityHidden(true)
                if index < 2 {
                    Rectangle().fill(HomeTheme.border).frame(width: 1).frame(maxHeight: .infinity).accessibilityHidden(true)
                }
            }.frame(width: 32).padding(.top, 6)
            VStack(alignment: .leading, spacing: 8) {
                if canExpand {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            if expanded.contains(section) { expanded.remove(section) } else { expanded.insert(section) }
                        }
                    } label: {
                        stepHeading(index, state: state, tone: tone, disclosure: true, expanded: expanded.contains(section))
                    }.buttonStyle(HomePressStyle())
                        .accessibilityLabel("\(stepTitle(index))，\(state.title)")
                        .accessibilityValue(expanded.contains(section) ? "已展开" : "已收起")
                        .accessibilityHint("轻点\(expanded.contains(section) ? "收起" : "查看")地址与检测结果")
                        .accessibilityIdentifier("mine.network.step.\(index)")
                } else { stepHeading(index, state: state, tone: tone, disclosure: false, expanded: false) }
                Text(stepSummary(index, rows: rows)).font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if expanded.contains(section) {
                    details(rows, index: index, active: active)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, index == 2 ? 0 : 24)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func stepHeading(_ index: Int, state: NetworkDiagnosticStepState, tone: Color, disclosure: Bool, expanded: Bool) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(stepTitle(index)).font(.headline).foregroundStyle(HomeTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Text(state.title).font(.caption.weight(.semibold)).foregroundStyle(tone)
                if disclosure {
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(expanded ? 180 : 0)).foregroundStyle(HomeTheme.secondaryText)
                }
            }
        }.fixedSize(horizontal: false, vertical: true).frame(minHeight: 44).contentShape(Rectangle())
    }

    private func details(_ rows: [NetworkDiagnosticResult], index: Int, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Label(row.title, systemImage: row.passed ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.subheadline.weight(.medium)).foregroundStyle(row.passed ? HomeTheme.text : HomeTheme.warmAccent)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(row.targets.enumerated()), id: \.offset) { offset, target in
                        address(target, label: index == 1 ? (offset == 0 ? "来源地址" : "返回节点 \(offset)") : (index == 2 ? "检测节点" : "请求地址"))
                    }
                    if index == 0 && row.targets.isEmpty {
                        Text("设备网络接口检查，无远端节点").font(.caption).foregroundStyle(HomeTheme.secondaryText)
                    }
                    Text("\(row.passed ? "通过" : "未通过") · \(row.milliseconds) 毫秒")
                        .font(.caption.monospacedDigit()).foregroundStyle(row.passed ? HomeTheme.secondaryText : HomeTheme.warmAccent)
                    Divider().overlay(HomeTheme.border)
                }
            }
            if active {
                if activeTargets.isEmpty {
                    Text(index == 0 && rows.isEmpty ? "正在检查设备网络接口…" : "正在等待检测结果…")
                        .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
                } else {
                    ForEach(activeTargets, id: \.self) { target in address(target, label: "检测中") }
                }
            }
            if index == 0 {
                ForEach(InternetConnectivityCheck.addresses.filter { target in
                    !rows.contains(where: { $0.targets.contains(target) }) && !activeTargets.contains(target)
                }, id: \.self) { target in
                    address(target, label: NetworkDiagnosticStepState.pendingInternetTitle(
                        hasReachableAddress: rows.contains { $0.passed && !$0.targets.isEmpty },
                        completed: completed, interrupted: interrupted))
                }
                if rows.contains(where: { $0.passed && !$0.targets.isEmpty }) {
                    Text("外网地址检测通过后，不再请求后续地址。").font(.caption).foregroundStyle(HomeTheme.secondaryText)
                }
            }
            if index == 1 {
                ForEach(sources.filter { source in
                    !rows.contains(where: { $0.targets.first == source.address }) && !activeTargets.contains(source.address)
                }, id: \.address) { source in
                    address(source.address, label: "\(sourceName(source.kind)) · \(completed ? "未执行" : (interrupted ? "未完成" : "待检测"))")
                }
                if completed && hasServer {
                    Text("已找到可用服务器，后续来源不再检测。").font(.caption).foregroundStyle(HomeTheme.secondaryText)
                }
            }
        }
        .padding(.top, 8)
    }

    private func address(_ target: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(HomeTheme.secondaryText)
            Text(verbatim: NetworkDiagnosticAddress.masked(target)).font(.footnote.monospaced()).foregroundStyle(HomeTheme.text)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }.accessibilityElement(children: .combine)
    }

    private func stepTitle(_ index: Int) -> String { ["检查设备与外网", "获取服务节点", "连接服务器"][index] }
    private func stepSummary(_ index: Int, rows: [NetworkDiagnosticResult]) -> String {
        if !rows.isEmpty {
            let passed = rows.filter(\.passed).count
            return "\(passed) 条通过 · \(rows.count - passed) 条未通过"
        }
        if completed && index == 2 { return "没有取得可探测的服务节点。" }
        return ["设备联网状态与 4 个外网检测地址", "依次尝试主域、备域和 BIN", "检查具体节点的连接与密钥交换"][index]
    }
    private func sourceName(_ kind: DNS1Source.Kind) -> String {
        switch kind { case .main: return "主域"; case .backup: return "备域"; case .bin: return "BIN"; case .cache: return "缓存" }
    }
}
