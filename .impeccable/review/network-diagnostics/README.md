# 网络检测工作台验证 · 2026-11-09

节点脱敏追加：截图已更新为掩码地址。新增15种地址输入检查，专项合计19组通过，日志 `/tmp/ddlNew-address-checks.log`；最终无签名构建exit0、BUILD SUCCEEDED，日志 `/tmp/ddlNew-address-build.log`。当前目标和可复制详情均只渲染掩码值；截图仍为匿名夹具。

Operate模式，现有森林绿工作台的可读性优化。保留用户确认的结构；新增用户明确要求的实际节点展示。

截图来自iOS 26.5 iPhone SE模拟器（375pt），匿名宿主直接编译当前生产PageContent、StepState、Runner数据结构、InternetConnectivityCheck、DNS1模型和HomeTheme。宿主仅注入示例数据，不运行真实联网请求。`example.invalid`和`2001:db8::`为截图夹具。

- ready.png：准备态。
- running.png：主域失败、正在尝试备域。
- result.png / result-dark.png：最终有可用连接但保留局部失败，失败记录自动展开。
- dns-nodes.png：DNS来源及返回节点。
- bottom.png / bottom-dark.png：BIN未执行及服务器IPv6／域名端口。
- ax.png / ax-bottom.png：accessibility3字号、底部完整地址与耗时。

底部与中部截图由匿名宿主设置UIScrollView偏移，不是手势测试。Mobile MCP元素查询未返回可用结果，未完成实际触摸与VoiceOver验证。仅iPhone为主app支持设备，不将预览当成真实登录／网络验收。

离线专项：`bash Tests/Mine/run-diagnostic-checks.sh`，18组通过，日志 `/tmp/ddlNew-clarity-checks-final.log`。
最终构建：generic iOS Debug、CODE_SIGNING_ALLOWED=NO，PATH排除sentry-cli；日志 `/tmp/ddlNew-clarity-build-final-verified.log`。最终exit 0，`BUILD SUCCEEDED`；`git diff --check`通过。无提交／推送。

独立只读复核发现两项P2，均已修复并回归：首次任务开始前的取消校验；外网成功后立即展示后续地址未请求。额外渲染修复：完成时自动展开及装饰标记字号。
