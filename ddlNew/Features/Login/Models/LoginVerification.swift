import Foundation

/// 服务端要求的验证方式；阿里初次验证与交互验证使用不同场景。
nonisolated enum LoginVerificationKind: Equatable {
    case imageCaptcha
    case tencentCaptcha
    case aliyunCaptcha(interactive: Bool)
    case securityCode
}

/// 仅向页面传递展示信息与图片。安全码 scKey 留在服务内部，短期凭据不持久化。
/// 每次请求使用独立 ID，使已关闭页面的回调无法完成新一轮验证。
nonisolated struct LoginVerificationRequest: Identifiable, Equatable {
    let id: UUID
    let kind: LoginVerificationKind
    let message: String
    let imageData: Data?

    init(id: UUID = UUID(), kind: LoginVerificationKind, message: String = "", imageData: Data? = nil) {
        self.id = id
        self.kind = kind
        self.message = message
        self.imageData = imageData
    }
}

/// 图片码与安全码来自用户输入；腾讯和阿里字段必须来自各自 SDK 的真实回调。
/// 页面返回这些字段后，由服务端判定是否通过；客户端不以回调代替登录认证。
/// 仅在本轮请求内传递，不持久化验证码或第三方验证凭据。
nonisolated struct LoginVerificationAnswer: Equatable {
    var imageCode: String = ""
    var ticket: String = ""
    var randstr: String = ""
    var captchaVerifyParam: String = ""
    var securityCode: String = ""
}

@MainActor
/// 等待本轮页面提交或取消；返回的验证内容仍需交给登录接口校验。
protocol AccountLoginChallengePresenting {
    func present(_ request: LoginVerificationRequest) async throws -> LoginVerificationAnswer
}
