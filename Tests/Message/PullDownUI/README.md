# 消息页顶部下拉交互

匿名原生宿主直接编译生产的 `MessagePullDownGesture` 和 `MessagePullDownPresentation`，不连接 SDK 或真实账号。

```sh
python3 Tests/Message/PullDownUI/generate.py /tmp/ddlNew-message-pulldown
xcodebuild test \
  -project /tmp/ddlNew-message-pulldown/MessagePullDown.xcodeproj \
  -scheme MessagePullDown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  CODE_SIGNING_ALLOWED=NO
```

覆盖不足阈值回收、连续展开／上滑收回、关闭按钮、底栏遮挡、列表中段下拉不误触发和会话左滑菜单。展开截图保存在 xcresult 中。宿主不包含真实消息页的搜索、登录和小应用，不替代这些流程的真机验收。

翻译版同时编译生产 QuickTranslationView 与主题；语言包和真实译文不做模拟，宿主替换 Toast 呈现与 L10n 查找；同时编译生产 TranslationWorker 和 TranslationRequest。增加小屏文字输入／关闭键盘检查，底部收回手势按实际按钮坐标定位；iPad 使用通用按钮查询以兼容顶部 Tab。真实翻译、语言下载、复制与重试仍需支持的真机验证。
