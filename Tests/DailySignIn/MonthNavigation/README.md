# 每日签到原生导航回归

`generate.py`生成独立匿名iOS宿主，不使用生产账号或SDK网络。默认从生产文件原样提取月份选择器，并编译真实Store／模型，在List内复现两个明细页的按钮交互；`--pages`直接编译完整DailySignInView，替换外部认证／网络／主题边界，验证日期、规则、push及子页返回。Toast展示不在该宿主验收范围。

```sh
python3 Tests/DailySignIn/MonthNavigation/generate.py /tmp/ddlNew-month-navigation
xcodebuild -project /tmp/ddlNew-month-navigation/MonthNavigation.xcodeproj -scheme MonthNavigation -destination 'platform=iOS Simulator,id=<模拟器UUID>' -parallel-testing-enabled NO -collect-test-diagnostics never test

python3 Tests/DailySignIn/MonthNavigation/generate.py /tmp/ddlNew-signin-pages --pages
xcodebuild -project /tmp/ddlNew-signin-pages/MonthNavigation.xcodeproj -scheme MonthNavigation -destination 'platform=iOS Simulator,id=<模拟器UUID>' -parallel-testing-enabled NO -collect-test-diagnostics never test
```

月份测试：先左再右必须回到当前月，当前月右按钮不可用。旧automatic按钮样式下两个用例均失败；borderless修复后两项通过。页面测试覆盖当前本地日期、非弹窗导航、记录／积分页返回仍保留Store、重新进入、随机规则、助手内push及连签奖励表。

日历标识测试：`testTodayWithoutSignIn`与`testTodayAndSignedCalendarMarkers`覆盖今日未签／已签的组合状态、首周日期可见、历史月份同日号仅保留签到标识。签到日期来自匿名网络夹具，实际日历视图使用生产实现；截图保留在xcresult附件中。
