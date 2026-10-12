import Foundation
import NoaChatCore
import ObjectMapper

/// 复用已有账号检查和密钥请求；注册只调用 SDK 已有的真实接口。
@MainActor
final class SDKAccountRegistrationClient: AccountRegistrationSDKDriving {
    private let loginClient = SDKAccountLoginClient()

    func checkAccountExists(account: String) async throws -> Bool {
        try await loginClient.checkAccountExists(account: account)
    }

    func fetchEncryptKey() async throws -> String {
        try await loginClient.fetchEncryptKey()
    }

    func register(parameters: [String: Any]) async throws -> AccountLoginResponse {
        let waiter = SDKLoginRequestWaiter<AccountLoginResponse>()
        return try await waiter.run {
            // 新账号不能携带上次登录账号的设备凭据。
            let sdk = NoaIMSDKManager.sharedTool()
            sdk.configSDKDeviceSecret(nil)
            sdk.authRegister(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result: Result<AccountLoginResponse, AccountLoginError>
                if let json = data as? [String: Any],
                   let response = Mapper<AccountLoginResponse>().map(JSON: json), response.isValid {
                    result = .success(response)
                } else {
                    result = .failure(.invalidResponse)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, _ in
                Task { @MainActor in
                    waiter.finish(.failure(.businessFailure(code: code, message: message ?? "")))
                }
            })
        }
    }
}
