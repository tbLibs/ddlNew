//
//  Const.swift
//  ddlNew
//
//  Created by taobo on 2026/9/22.
//

import Foundation

// MARK: - App 打包类型

/// 默认 appType：.common = 0（公共打包），.independent = 1（独立打包）。
let DefaultAppType: IMServerListRequest.DataType = .common

// MARK: - 本地状态存储

/// 保存最新一份 OSS 导航状态的固定 AppStorage key，不拼接邀请码。
let ossNavigationAppStorageKey = "ddlNew.ossNavigation.v1"

/// 保存最新已选 HTTP API Host 的固定 AppStorage key，不拼接邀请码。
let ossSelectedHTTPHostAppStorageKey = "ddlNew.selectedHTTPHost.v1"

/// 业务请求的设备 UUID 存储 key。
let businessDeviceUUIDAppStorageKey = "ddlNew.businessDeviceUUID.v1"

/// 最新用户资料的固定 key；不保存 token、deviceSecret 或密码。
let userInfoAppStorageKey = "ddlNew.userInfo.v1"

/// 当前会话凭据的 Keychain 标识，不拼接邀请码。
let userCredentialKeychainService = "ddlNew.userSession"
let userCredentialKeychainAccount = "currentSession.v1"

/// 登录页记住密码的偏好，首次使用默认开启；此 key 不存放密码。
let loginRememberPasswordAppStorageKey = "ddlNew.login.rememberPassword.v1"

/// 登录表单的独立 Keychain 标识，不与 token、设备凭据混用。
let rememberedLoginKeychainService = "ddlNew.rememberedLogin"
let rememberedLoginKeychainAccount = "loginForm.v1"

// MARK: - 登录页外部链接

/// 登录页 Safari 浏览器打开的隐私政策和使用支持地址。
let privacyPolicyURLString = "https://gitlab.yunliaoliao.com/c/privacy.html"
let usageSupportURLString = "https://gitlab.yunliaoliao.com/c/support.html"

// MARK: - 业务接口
let businessOrgName = "1595975575091130369"

// MARK: - DNS1 服务器地址发现
nonisolated let dns1MainDomain = "facaifacai99.xyz"
nonisolated let dns1BackupDomain = ""
nonisolated let dns1AccountId = "899981"
nonisolated let dns1AccessKey = "899981_32929921960122368"
nonisolated let dns1AccessKeySecret = "d298cd440c204fc28f9170a01f7d45e6"
nonisolated let dns1BinURLTemplate = "https://nav-sg.oss-cn-hongkong.aliyuncs.com/nav_%s/npoint.bin"
nonisolated let dns1NavigationCacheKey = "ddlNew.dns1Navigation.v2"
