# 最近使用表情持久化回归

交互约定：从“全部表情”插入时更新最近使用；点击“最近使用”只插入，保持原顺序和持久化记录。

`sh Tests/Chat/RecentEmoji/run-checks.sh` 编译生产历史存储与表情目录，使用独立、随机的 UserDefaults suite 验证重新创建读取、最近使用排序／去重／7个上限、账号及租户隔离、无效身份拒绝和损坏／未知记录恢复；退出清理测试 suite。

原生UI宿主直接编译生产ChatEmojiPanel及目录／输入上限／游戏表情模型，仅替换ChatStore和贴纸发送依赖为匿名无网络对象。测试应用使用独立bundle ID，不连接真实账号；不打包图片资源，依靠生产表情按钮的无障碍标签操作。固定开关按钮位置，避免面板收起时测试入口跳动。

```bash
python3 Tests/Chat/RecentEmoji/generate.py /tmp/ddlNew-recent-emoji
xcodebuild -project /tmp/ddlNew-recent-emoji/RecentEmoji.xcodeproj -scheme RecentEmoji -destination 'platform=iOS Simulator,id=<UUID>' -parallel-testing-enabled NO test
```

测试选用默认最近7项以外的[脸红]，检查选中后同时出现在最近与全部列表；关闭并重新创建面板仍存在，终止测试App后不清数据重启仍存在。测试启动的reset参数只清匿名测试App的偏好。

2026-11-11：旧实现重启后只剩全部列表中的一项，最近使用丢失（/tmp/ddlNew-recent-emoji-baseline.xcresult）。最初开关宿主位置跳动还导致重新打开步骤失败，后固定入口后复验。最终iPhone17 Pro Max／iOS26.5模拟器测试通过（/tmp/ddlNew-recent-emoji-verified.xcresult）；完整项目无签名构建通过（/tmp/ddlNew-recent-emoji-build.log）。没有安装真实App或发送真实消息。
