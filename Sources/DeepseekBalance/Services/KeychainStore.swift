import Foundation
import Security
import LocalAuthentication

/// Stores the DeepSeek API key in the macOS Keychain (encrypted, app‑scoped).
///
/// - **Reading for API calls**:  silent – no authentication required.
/// - **Viewing the raw key**:   requires Touch ID / device password.
/// - **Saving / deleting**:     also authentication‑gated.
final class KeychainStore: ObservableObject {
    static let shared = KeychainStore()

    private let service = "com.deepseek.balance"
    private let account = "api_key"

    // MARK: - Public state

    /// Whether any API key exists in the keychain (inexpensive check).
    @Published var keyExists: Bool = false

    var hasApiKey: Bool { keyExists }

    private init() {
        keyExists = (try? loadSilently()) != nil
    }

    // MARK: - Silent read (for API calls)

    /// Reads the key without any authentication prompt.
    func loadSilently() throws -> String? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            if status == errSecItemNotFound { return nil }
            throw KeychainError.unexpected(status)
        }
        return key
    }

    // MARK: - Authenticated read (for viewing in Settings)

    /// Reads the key only after the user authenticates with Touch ID / password.
    func loadWithAuthentication(reason: String = "unlock your API key") async throws -> String {
        let context = LAContext()
        context.localizedReason = reason

        // 1. Check biometrics / password availability
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw KeychainError.authUnavailable(error?.localizedDescription ?? "Authentication not available")
        }

        // 2. Prompt user
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
        guard success else {
            throw KeychainError.authCancelled
        }

        // 3. Now read from keychain
        guard let key = try loadSilently() else {
            throw KeychainError.itemNotFound
        }
        return key
    }

    // MARK: - Save

    func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try delete()
            return
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete any existing item first
        try? delete()

        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData   as String: data,
            // Restrict to this app only
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpected(status)
        }

        Task { @MainActor in
            keyExists = true
        }
    }

    // MARK: - Delete

    func delete() throws {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpected(status)
        }

        Task { @MainActor in
            keyExists = false
        }
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case unexpected(OSStatus)
    case itemNotFound
    case encodingFailed
    case authUnavailable(String)
    case authCancelled

    var errorDescription: String? {
        switch self {
        case .unexpected(let s):  return "Keychain error \(s)"
        case .itemNotFound:       return "No API key found"
        case .encodingFailed:     return "Failed to encode key"
        case .authUnavailable(let m): return "Authentication unavailable: \(m)"
        case .authCancelled:      return "Authentication cancelled"
        }
    }
}
