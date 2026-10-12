import Foundation

@MainActor
protocol AccountRegistrationSDKDriving {
    func checkAccountExists(account: String) async throws -> Bool
    func fetchEncryptKey() async throws -> String
    func register(parameters: [String: Any]) async throws -> AccountLoginResponse
}
