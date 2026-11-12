# 聊天末尾定位原生回归

提取当前 ChatRoomView 的滚动容器、放行条件与首次定位方法，使用匿名 100 条不同高度记录，保留转事项菜单和两条事项导航。连续三次进入要求末条实际可见，避免只用假 ScrollViewProxy 验证方法被调用。

```sh
python3 Tests/Chat/InitialLayout/generate.py /tmp/chat-entry-ui
xcodebuild test -project /tmp/chat-entry-ui/ChatEntry.xcodeproj -scheme ChatEntry \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

该夹具不包含真实 SDK 数据库、消息气泡及网络，不用于证明真机首帧耗时或复现所有短暂空白。真实 Store 的缓存先展示、后台刷新、取消和会话隔离由 `../run-initial-history-presentation-checks.sh` 覆盖。
