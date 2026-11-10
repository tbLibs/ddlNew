# 应用多语言

支持系统语言、简体中文（zh-Hans）、繁體中文（zh-Hant）、English（en）。默认跟随系统；不支持的系统语言回退英文。选择保存在安装级 UserDefaults，不随退出账号清除。邀请码页、登录页与设置页均可打开语言选择，按确定应用，取消不保存。

## 开发入口

- `Common/Localization/L10n.swift`：语言解析、资源查询、参数格式化。静态文案用 `L10n.tr("文案")`，插值用 `L10n.tr("共\(count)人")`，资源键为 `共%@人`。可以用 `%1$@` 调整译文参数顺序。字面百分号与插值同时出现时写入格式键为 `%%`。
- `AppLanguageStore.swift`：主线程发布语言及 locale；切换不修改认证、路由、SDK或页面身份。
- `LanguageSettingsView.swift`：共享选择页。依赖运行时文案的SwiftUI页面显式读取 `@Environment(\.locale)`，避免只切换偏好而页面未刷新。
- `Resources/Localization/Localizable.xcstrings`：统一管理三语文案，源语言为简体中文。已有适用翻译取自xgd，新项目文案补齐。
- `Resources/Localization/InfoPlist.xcstrings`：相机、麦克风、相册读取及写入用途的三语说明。
- `Resources/AppLaunchScreen.storyboard`：单一、非本地化的系统启动页，按用户要求固定简体中文，不随系统或App语言切换。`Tests/Localization/check_launch_resources.py` 校验中文文案及无多语言启动资源残留。

稳定的枚举rawValue、数据库标识、文件名、协议参数不得翻译；仅在显示时 `L10n.lookup(rawValue)`。不要对聊天正文、昵称、备注、群名、服务端原始文本直接调用lookup。活动仅在 `isBuiltInSample` 为true时翻译内置示例；外部数据即使ID相同也保留原文。

新增文案在 Xcode String Catalog 编辑器中维护 `Localizable.xcstrings`，补齐 zh-Hans、zh-Hant、en；无需新增 `.lproj/*.strings` 源文件。`L10n` 使用动态查询，目录条目设为 `extractionState: manual`，不能依赖 Xcode 自动提取这些调用或按“未提取”删除条目。设置 `generatesSymbol: false`，避免“聊天记录”与“[聊天记录]”等不同键生成同名 Swift 符号。编译时 Xcode 将目录生成各语言 `.lproj/*.strings`，现有 Bundle 查询、插值和应用内切换继续复用。

审计兼容目录格式1.0和Xcode保存后的1.1。Xcode自动提取的纯数字／格式模板、示例域名和固定Bundle名称标记 `shouldTranslate: false`，不计入三语文案完整性统计；用户可见的自然语言文案不能用该标记绕过翻译。

消息页语言变化时只重读已有SDK本地快照，更新文件助手和类型摘要；不发起远端同步。已经生成的临时错误／通知权限描述和历史系统消息展示快照，在下一次正常生成／读取时采用新语言；不通过重新登录或重建会话强制刷新。

系统启动画面固定简体中文；系统权限弹窗由iOS选取语言，和运行中的App手动选择不是同一生命周期。验证码网页使用原生注入的应用语言配置：阿里云cn/tw/en、腾讯zh-cn/zh-tw/en。真实挑战的语言支持仍取决于服务商验证类型，参数依据[腾讯文档](https://cloud.tencent.com.cn/document/product/1110/36841)、[阿里云文档](https://help.aliyun.com/en/captcha/captcha2-0/user-guide/custom-copy-and-multi-language-settings)。没有联网调用真实验证码做验收。

## 检查

```sh
bash Tests/Localization/run-checks.sh
python3 Tests/Localization/audit_resources.py
python3 Tests/Localization/check_compiled_resources.py /path/to/ddlNew.app
python3 Tests/Localization/check_launch_resources.py # 可另传已构建的 .app 路径，检查最终资源
bash Tests/Localization/run-captcha-checks.sh
bash Tests/Activities/run-checks.sh
```

资源审计检查目录重复键、三语完整性、翻译状态、参数类型／位置、英文残留中文，以及允许检查的源码调用缺失。遵循用户要求跳过 Home／Activities／Club 源码，因此不根据部分源码扫描判定过期键，不自动删除目录文案。它不能独自证明所有源码已完成本地化；新增页面仍需检查未接入的用户文案。`run-checks.sh` 使用 Apple xcstringstool 编译两个真实目录、逐条核对产物译文，再编译生产 L10n 验证三语切换、英文回退与插值；没有用测试桩替换本地化实现。

原生UI用例与临时工程生成入口见 `Tests/LoginUI/README.md`。使用XCTest，不使用Mobile MCP。语言切换测试会验证简体→英文→繁体、输入保留和重启偏好恢复；英文注册页检查小屏滚动。

## String Catalog迁移验证（2026-11-10）

Localizable三语各1662键、InfoPlist三语各4键，迁移前后全部键值一致。目录编译、符号检查、完整性／占位符审计与生产L10n运行时切换检查通过。完整App无签名generic iOS Debug构建成功（`/tmp/ddlNew-xcstrings-verified-build.log`），最终App中的4998条译文逐条匹配目录。未重新安装或验收真机页面。

## 首次多语言接入验证记录（2026-11-10，历史）

三语各1624键，资源审计无缺失／过期／重复／格式错误。离线首轮122个入口中7个测试夹具过期，修复后逐项复跑并加入活动、验证码两个入口，最终124/124通过；汇总 `/tmp/ddlNew-localization-checks/final-summary.json`。活动23项使用隔离翻译边界验证只转换内置数据；语言运行时由独立检查和真实UI宿主验证。

主App无签名generic iOS Debug构建exit0／BUILD SUCCEEDED，日志 `/tmp/ddlNew-localization-verified-build.log`。9项UI测试通过，报告 `/tmp/ddlNew-localization-ui-final/DerivedData/Logs/Test/Test-AuthAudit-2026.11.10_11-14-54-+0800.xcresult`，原始截图 `.impeccable/review/localization/`。原有注册键盘布局警告仍在。真实服务商挑战、线上认证、真机所有页面和VoiceOver未验收；未提交推送。
