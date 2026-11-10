# 表情正文栈溢出回归

生产 `ChatEmojiText` 曾逐片段执行 `Text + Text`，形成线性嵌套。真机在
`___chkstk_darwin` / `ConcatenatedTextStorage.resolve` 崩溃，栈深2154层。
现改为相邻片段逐层合并，不截断消息或减少表情数量。

快速检查会编译提取出的生产渲染方法，用记录拼接树的Text替身验证
0／1／2／3／7／1000／5000／10000个片段的顺序、缺图回退和对数深度：

```bash
bash Tests/Chat/run-emoji-depth-checks.sh
bash Tests/Chat/run-emoji-checks.sh
```

原生检查使用真实生产SwiftUI视图、词典和两个真实表情资源，运行在匿名iOS宿主，
不包含SDK、登录或发送消息。通过UIHostingController实际解析并排版Text，覆盖
1000／5000／10000个图片表情、混合中文／Unicode／换行／未知标记和辅助大字号。
同时验证长内容高度继续增加，防止靠截断内容让测试通过。

```bash
python3 Tests/Chat/EmojiRendering/generate.py /tmp/ddlNew-emoji-rendering
xcrun simctl list devices available
# 将SIMULATOR_ID设为可用的iOS模拟器UDID。
xcodebuild test \
  -project /tmp/ddlNew-emoji-rendering/EmojiRendering.xcodeproj \
  -scheme EmojiRendering \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 60
```

测试不代表真实群发送／网络收发已验收；它覆盖收发消息共用的正文渲染崩溃路径。
