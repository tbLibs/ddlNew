# Login Methods Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. Execute in this checkout; no commit or push.

**Goal:** 按xgd支持账号、手机号的登录注册（用户随后明确移除邮箱）；UI使用Impeccable及ui-ux-pro-max。
**Architecture:** 原服务扩展强类型身份与密码/验证码输入，继续复用SDK、验证码弹窗、会话AUTH。发送短信独立服务和页面状态管理，连接/页面轮次隔离。
**Tech Stack:** SwiftUI、Combine、ObjectMapper、NoaChatCore。
**Spec:** 本文的行为合同，用户已明确“逻辑按照xgd的逻辑改”，实现细节由当前会话完成。

## 行为合同与UI方向

- API loginType：账号1、手机3；删除邮箱枚举2，手机号不重新编号。手机接口区号带+、默认+86，账号登录/注册/预检的areaCode为空。短信发码携带当前带+区号；本地凭据键不带+。
- 两类密码登录均检查userExit，领取新encryptKey，再加密提交type2；缺失分别2036/50001。pwdExit在xgd当前未消费。
- 手机验证码登录直接提交code、空encryptKey/userPw、type2，继续安全码与AUTH链路。
- 注册账号先authUserExist；手机获取验证码时检查注册存在性，验证码6位，注册提交encryptKey+密码、registerType1/type1。
- 手机发码按本地captchaChannel2先图文校验，支持既有腾讯/阿里回退。图文type注册1/登录2，手机密码登录type2，账号密码登录type0。仅成功发码后开始60秒倒计时，按身份/用途隔离；失败可重试，旧回包不改新表单。
- 登录/注册入口本地固定账号＋手机（loginMethod/registerMethod=5），不恢复getSystemConfig和已删userSettings字段。协议默认不勾选，打开文档不代表同意。
- UI沿用现有森林绿HomeTheme；系统动态字号、两方式可见切换、手机号国家区号搜索、密码/验证码次级切换，主操作明确。短屏可滚动、暗色跟随系统，验证码不持久化。
- Keychain记住密码包含身份类型/区号；设备凭据按类型和区号隔离。保留旧账号记录兼容；旧邮箱记忆记录不回填，OTP不得写入密码记忆。
- xgd只读；范围不含找回密码或真实账号注册发送，不提交推送。

## Review Focus

旧记忆账号格式兼容；验证码不能存成密码；换方式/换区号/关闭页面后的迟到结果；验证码弹窗嵌套注册页；注册成功而AUTH失败不得重复注册。

### Task 1: 类型与协议
- [x] 新增AccountIdentity/AccountLoginInput；扩展登录注册服务及SDK参数，保持旧账号调用兼容。
- [x] 新增验证码服务，连接守卫、图片type、错误回退；测试两方式参数与失败分流。
### Task 2: 页面状态与UI
- [x] 扩展ViewModel与记忆身份；新增发码状态、倒计时和区号目录。
- [x] 两方式登录/注册UI，保留协议、验证码弹窗、AUTH成功导航与表单取消。
- [x] 检查UI匿名预览浅深色、小屏、大字及协议回归。
### Task 3: 验证
- [x] 登录、注册、验证、记忆、协议、会话恢复相关脚本通过；generic iOS无签名编译，PATH排除sentry-cli。
- [x] 按requesting-code-review执行独立复核，修复发现，更新PROJECT_HANDOFF。
