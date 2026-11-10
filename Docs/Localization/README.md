# 应用多语言

支持系统语言、简体中文（zh-Hans）、繁體中文（zh-Hant）、English（en）。默认跟随系统；不支持的系统语言回退英文。选择保存在安装级 UserDefaults，不随退出账号清除。邀请码页、登录页与设置页均可打开语言选择，按确定应用，取消不保存。

## 开发入口

- `Common/Localization/L10n.swift`：语言解析、资源查询、参数格式化。静态文案用 `L10n.tr("文案")`，插值用 `L10n.tr("共\(count)人")`，资源键为 `共%@人`。可以用 `%1$@` 调整译文参数顺序。字面百分号与插值同时出现时写入格式键为 `%%`。
- `AppLanguageStore.swift`：主线程发布语言及 locale；切换不修改认证、路由、SDK或页面身份。
- `LanguageSettingsView.swift`：共享选择页。依赖运行时文案的SwiftUI页面显式读取 `@Environment(\.locale)`，避免只切换偏好而页面未刷新。
- `Resources/Localization/<language>.lproj/Localizable.strings`：三语文案。已有适用翻译取自xgd，新项目文案补齐。
- `Resources/Localization/<language>.lproj/InfoPlist.strings`：相机、麦克风、相册读取及写入用途。
- `Resources/{zh-Hans,zh-Hant,en}.lproj/AppLaunchScreen.storyboard`：各语言独立编译的系统启动页；文字嵌入 storyboard，不依赖启动时查找 `.strings`。修改布局需同步三份文件，`Tests/Localization/check_launch_resources.py` 校验文案与布局一致性。

稳定的枚举rawValue、数据库标识、文件名、协议参数不得翻译；仅在显示时 `L10n.lookup(rawValue)`。不要对聊天正文、昵称、备注、群名、服务端原始文本直接调用lookup。活动仅在 `isBuiltInSample` 为true时翻译内置示例；外部数据即使ID相同也保留原文。

消息页语言变化时只重读已有SDK本地快照，更新文件助手和类型摘要；不发起远端同步。已经生成的临时错误／通知权限描述和历史系统消息展示快照，在下一次正常生成／读取时采用新语言；不通过重新登录或重建会话强制刷新。

系统启动画面和系统权限弹窗由iOS选取语言，和运行中的App手动选择不是同一生命周期。验证码网页使用原生注入的应用语言配置：阿里云cn/tw/en、腾讯zh-cn/zh-tw/en。真实挑战的语言支持仍取决于服务商验证类型，参数依据[腾讯文档](https://cloud.tencent.com.cn/document/product/1110/36841)、[阿里云文档](https://help.aliyun.com/en/captcha/captcha2-0/user-guide/custom-copy-and-multi-language-settings)。没有联网调用真实验证码做验收。

## 检查

```sh
bash Tests/Localization/run-checks.sh
python3 Tests/Localization/audit_resources.py
python3 Tests/Localization/check_launch_resources.py # 可另传已构建的 .app 路径，检查最终资源
bash Tests/Localization/run-captcha-checks.sh
bash Tests/Activities/run-checks.sh
```

资源审计对已接入调用、稳定枚举显示名及内置活动字段检查缺失、过期、重复、参数类型／位置，以及英文残留中文。它不能独自证明所有源码已完成本地化；新增页面仍需检查未接入的用户文案。现有独立Swift脚本通过显式L10n依赖继续测试真实生产模型；没有用测试桩替换本地化实现。

原生UI用例与临时工程生成入口见 `Tests/LoginUI/README.md`。使用XCTest，不使用Mobile MCP。语言切换测试会验证简体→英文→繁体、输入保留和重启偏好恢复；英文注册页检查小屏滚动。

## 本轮验证记录（2026-11-10）

三语各1624键，资源审计无缺失／过期／重复／格式错误。离线首轮122个入口中7个测试夹具过期，修复后逐项复跑并加入活动、验证码两个入口，最终124/124通过；汇总 `/tmp/ddlNew-localization-checks/final-summary.json`。活动23项使用隔离翻译边界验证只转换内置数据；语言运行时由独立检查和真实UI宿主验证。

主App无签名generic iOS Debug构建exit0／BUILD SUCCEEDED，日志 `/tmp/ddlNew-localization-verified-build.log`。9项UI测试通过，报告 `/tmp/ddlNew-localization-ui-final/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_11-14-54-+0800.xcresult`，原始截图 `.impeccable/review/localization/`。原有注册键盘布局警告仍在。真实服务商挑战、线上认证、真机所有页面和VoiceOver未验收；未提交推送。
