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
