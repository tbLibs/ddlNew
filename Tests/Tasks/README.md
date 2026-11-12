# 事项验证

`sh Tests/Tasks/run-checks.sh` 直接编译生产模型、仓库、Store，以 Debug／Release 优化及项目相同 MainActor 默认隔离验证：文件持久化、账号／租户隔离、旧群来源兼容、单聊来源恢复与单／群同ID隔离、截止时间、状态记录、旧版本编辑拒绝、写入失败、损坏归档保留、退出后迟到结果丢弃。所有文件写入临时目录，测试结束删除。

原生 UI 夹具：

```sh
python3 Tests/Tasks/UI/generate.py /tmp/ddlNew-personal-tasks-ui
xcodebuild -project /tmp/ddlNew-personal-tasks-ui/PersonalTasks.xcodeproj \
  -scheme PersonalTasks -destination 'platform=iOS Simulator,id=<模拟器 UUID>' \
  -derivedDataPath /tmp/ddlNew-personal-tasks-ui/DerivedData test
```

需要已有 XcodeGen 和主工程缓存的 AlertToast package，不自动安装工具。宿主直接编译生产事项页面、存储、主题、Toast 和 xcstrings，覆盖创建、完成／重新打开、编辑、删除及进程重启后的恢复。独立测试 Bundle ID，重置参数仅删除该宿主自己的沙盒记录；不登录真实账号、不接 SDK、不操作真实聊天。

此 UI 测试不覆盖完整 App 的群消息长按、Tab 切换或真机表现，不能替代这些入口的最终设备验收。
