# Deepseek-Balance

A lightweight macOS menu bar app that shows your [DeepSeek](https://platform.deepseek.com) API account balance at a glance — no need to open a browser.

<img src="docs/menubar-screenshot.png" width="400" alt="Menu bar screenshot" />

## Features

- **Menu bar balance** — your remaining DeepSeek credits displayed right in the macOS menu bar
- **Auto-refresh** — balance updates every 30 minutes and whenever you open the menu
- **Manual refresh** — click the ↻ button in the menu to fetch immediately
- **Low-balance warning** — the menu bar icon turns red when your balance drops below $5.00
- **Spend calculation** — derived spend shown alongside your remaining balance
- **Keychain storage** — API key stored encrypted in the macOS Keychain, never in plain text
- **Touch ID / password gate** — viewing or changing the key requires biometric auth or your device password
- **Quick link** — "Open DeepSeek Usage…" launches the usage dashboard in your browser
- **No Dock icon** — runs as a pure menu bar app (LSUIElement), stays out of your Dock and ⌘Tab switcher
- **Start on Login** - configurable whether the is automatically started on login

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (arm64)
- A [DeepSeek API key](https://platform.deepseek.com/api_keys)

## Quick Start

### Download

Grab the latest `.dmg` from [Releases](https://github.com/mlesk/deepseek-balance/releases), open it, and drag **Deepseek-Balance** into your `/Applications` folder.

### Build from source

```bash
git clone https://github.com/your-org/deepseek-balance.git
cd deepseek-balance

# Build the .app bundle
make build

# Run it
make run

# Or install to /Applications
make install
```

### Setup

1. Launch **Deepseek-Balance** — you'll see a whale icon in your menu bar
2. Click the icon → **Settings…**
3. Click **Add Key…**, paste your DeepSeek API key (`sk-...`), and hit **Save to Keychain**
4. Close Settings — your balance appears in the menu bar

## Usage

| Menu item                | What it does                                      |
| ------------------------ | ------------------------------------------------- |
| **Balance display**      | Shows current remaining credits (e.g. `$12.47`)   |
| ↻ **Refresh button**     | Fetches the latest balance on demand              |
| **Open DeepSeek Usage…** | Opens platform.deepseek.com/usage in your browser |
| **Settings…**            | Manage your API key (view, change, delete)        |
| **Quit**                 | Exit the app                                      |

### Icon colors

| Icon                      | Meaning                              |
| ------------------------- | ------------------------------------ |
| 🐋 Black/white (template) | Balance above $5.00 — all good       |
| 🔴 Red                    | Balance below $5.00 — time to top up |

## Architecture

```
Sources/
├── DeepseekBalance/
│   ├── main.swift              # App entry point (NSApplication, accessory mode)
│   ├── AppDelegate.swift       # App lifecycle, menu setup, settings window
│   ├── MenuBarController.swift # Menu bar item, balance view, timer, fetch logic
│   ├── Models/
│   │   └── UsageInfo.swift     # API response parsing & balance calculations
│   ├── Services/
│   │   ├── DeepSeekService.swift # API client for /user/balance
│   │   └── KeychainStore.swift   # Secure Keychain read/write with biometric auth
│   ├── Views/
│   │   └── SettingsView.swift    # SwiftUI settings window
│   └── Utils/
│       └── IconGenerator.swift   # Menu bar icon generation & PNG loading
└── CCrypto/                    # C crypto helpers (linked statically)
```

- **Swift 5.9** + **SwiftUI** for settings
- **AppKit** for the menu bar integration (`NSStatusItem`, custom `NSView` in `NSMenuItem`)
- **Keychain Services** (`Security.framework`) for encrypted API key storage
- **LocalAuthentication** for Touch ID / device password gating
- **ServiceManagement** for optional launch-at-login support
- Built with `swift build` and packaged into a `.app` bundle via `scripts/build-app.sh`

## Makefile commands

| Command        | Description                                   |
| -------------- | --------------------------------------------- |
| `make build`   | Compile release binary + create `.app` bundle |
| `make run`     | Build & launch the app                        |
| `make debug`   | Build & run in debug mode (terminal output)   |
| `make clean`   | Remove all build artifacts                    |
| `make install` | Build & copy `.app` to `/Applications`        |
| `make dmg`     | Build & ensure `.dmg` exists                  |

## Security

- Your API key is stored exclusively in the **macOS Keychain** (encrypted at rest)
- Reading the key for API calls is silent (no prompt)
- Viewing, changing, or deleting the key in Settings requires **Touch ID** or your device password
- The key is never logged, written to disk, or included in any bundle

## License

Unlicense — see [LICENSE](LICENSE).
