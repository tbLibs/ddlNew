# 消息长按与输入焦点

匿名原生宿主编译真实 ChatComposerTextInput，从 ChatRoomView 提取完整 contextMenu 修饰器及 keyboardWillHide 处理。宿主使用可选择文字的消息容器，只替代消息内容和业务菜单动作，不访问 SDK、账号或网络。宿主额外读取生产输入框的 isFirstResponder，区分“键盘暂时隐藏”和“原生输入框真正失焦”。

先生成工程，再用本机 iPhone 模拟器运行：

```bash
python3 Tests/Chat/ContextMenuFocus/generate.py /tmp/ddlNew-context-focus
xcodebuild -project /tmp/ddlNew-context-focus/ContextMenuFocus.xcodeproj -scheme ContextMenuFocus -destination 'platform=iOS Simulator,id=<模拟器UUID>' -parallel-testing-enabled NO test
```

三个用例覆盖短时长按、复制／引用回复，以及连续四轮“点击输入框 → 长按 → 不选择操作而取消菜单”。循环中的每一轮都在菜单仍显示时断言焦点绑定为 false 且原生输入框不再是 first responder；取消后检查键盘不恢复、草稿保留，下一轮点击仍能编辑。单次复制通过不能替代菜单显示期间及连续取消验证。

这只是匿名组件交互测试，不是完整聊天页面或真机验收。滚动列表探索夹具曾在第二次点击输入框阶段失败，未复现用户描述的第二次菜单期间失焦问题，不能把那个失败作为本次修复的因果证据。
