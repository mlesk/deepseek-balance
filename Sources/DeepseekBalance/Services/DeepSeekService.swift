import Foundation

/// Fetches DeepSeek balance via the API.
final class DeepSeekService {

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Public

    func fetchUsage() async throws -> UsageInfo {
        let keychain = KeychainStore.shared

        guard keychain.hasApiKey else {
            throw DeepSeekError.apiKeyMissing
        }

        guard let key = try keychain.loadSilently() else {
            throw DeepSeekError.apiKeyMissing
        }

        return try await fetchViaAPI(key: key)
    }

    // MARK: - API

    private func fetchViaAPI(key: String) async throws -> UsageInfo {
        let url = URL(string: "https://api.deepseek.com/user/balance")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key.trimmingCharacters(in: .whitespacesAndNewlines))",
                         forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw DeepSeekError.networkError("Invalid response")
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw DeepSeekError.unauthorized
            }
            throw DeepSeekError.networkError("HTTP \(http.statusCode)")
        }

        if let rawJSON = String(data: data, encoding: .utf8) {
            print("[Deepseek-Balance] API response: \(rawJSON)")
        }

        let decoder = JSONDecoder()
        let apiResp = try decoder.decode(UsageInfo.ApiResponse.self, from: data)
        let usage = try UsageInfo(apiResponse: apiResp)
        print("[Deepseek-Balance] Balance: $\(usage.balance)")
        return usage
    }
}
