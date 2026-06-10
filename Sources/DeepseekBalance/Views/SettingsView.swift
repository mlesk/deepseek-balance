import SwiftUI
import LocalAuthentication
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var keychain = KeychainStore.shared
    @State private var keyInput: String = ""
    @State private var isRevealed: Bool = false
    @State private var authError: String?
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DeepSeek API Key")
                .font(.headline)

            Text("Your key is stored securely in the macOS Keychain.\nGet your key at platform.deepseek.com → API Keys")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Key input area — only shown after authentication
            if isRevealed {
                HStack(spacing: 6) {
                    TextField("sk-...", text: $keyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button("Paste") {
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            keyInput = pasted
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Paste from clipboard (Cmd+V)")
                }

                HStack {
                    Button("Save to Keychain") {
                        try? keychain.save(keyInput)
                        keyInput = ""
                        isRevealed = false
                        if let window = NSApp.keyWindow,
                           window.title.contains("Settings") {
                            window.close()
                        }
                    }
                    .keyboardShortcut(.return)
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") {
                        keyInput = ""
                        isRevealed = false
                    }
                    .keyboardShortcut(.escape)

                    Spacer()
                }
            } else if keychain.keyExists {
                // Key exists — masked, requires auth to view
                HStack {
                    Text("••••••••••••••••")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))

                    Button("Reveal") {
                        authenticateAndReveal()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Change…") {
                        authenticateAndReveal()
                    }

                    Button("Delete") {
                        try? keychain.delete()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }

                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else {
                // No key stored yet
                HStack {
                    Text("No API key configured")
                        .foregroundColor(.secondary)

                    Button("Add Key…") {
                        isRevealed = true
                        keyInput = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if keychain.keyExists && !isRevealed {
                Text("✓ API key stored in Keychain")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Divider()

            // Launch at Login toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Launch at Login")
                        .font(.body)
                    Text("Automatically open Deepseek-Balance when you log in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: - Launch at Login

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert toggle on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
            authError = "Launch at Login: \(error.localizedDescription)"
        }
    }

    // MARK: - Authentication

    private func authenticateAndReveal() {
        authError = nil
        Task {
            do {
                let key = try await keychain.loadWithAuthentication(
                    reason: "authenticate to view your DeepSeek API key"
                )
                await MainActor.run {
                    keyInput = key
                    isRevealed = true
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
