import Foundation
import NoaChatCore

@MainActor final class SDKAccountCodeClient: AccountCodeSDKDriving {
    private var sdk: NoaIMSDKManager { .sharedTool() }
    func restoreChannel(_ channel: Int) { sdk.configSDKCaptchaChannel(channel) }
    func image(account: String, type: Int) async throws -> Data {
        try await SDKAccountLoginClient().fetchImageCaptcha(account: account, type: type)
    }
    func isRegistered(_ identity: AccountIdentity) async throws -> Bool {
        let waiter = SDKLoginRequestWaiter<Bool>()
        return try await waiter.run {
            sdk.authUserExist(with: NSMutableDictionary(dictionary: identity.parameters), onSuccess: { data, _ in
                let value = (data as? NSNumber)?.boolValue
                Task { @MainActor in
                    if let value { waiter.finish(.success(value)) }
                    else { waiter.finish(.failure(.invalidResponse)) }
                }
            }, onFailure: { code, message, _ in
                Task { @MainActor in waiter.finish(.failure(.businessFailure(code: code, message: message ?? ""))) }
            })
        }
    }
    func send(parameters: [String: Any], channel: Int) async throws {
        let waiter = SDKLoginRequestWaiter<Bool>()
        _ = try await waiter.run {
            sdk.configSDKCaptchaChannel(channel)
            sdk.authGetPhoneEmailVerCode(with: NSMutableDictionary(dictionary: parameters), onSuccess: { _, _ in
                Task { @MainActor in waiter.finish(.success(true)) }
            }, onFailure: { code, message, _ in
                Task { @MainActor in waiter.finish(.failure(.businessFailure(code: code, message: message ?? ""))) }
            })
        }
    }
}
