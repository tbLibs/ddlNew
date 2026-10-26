import Foundation

/// 此版本的登录、注册规则固定随 App 发布，不读取系统配置接口或历史配置缓存。
nonisolated enum LocalAccountPolicy {
    static let loginMethod = "1"
    static let registerMethod = "1"
    static let captchaChannel = 2
    static let requiresInviteCode = false
    static let requiresPasswordSymbol = false
}
