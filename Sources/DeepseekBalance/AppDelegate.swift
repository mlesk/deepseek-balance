import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var menuBarController: MenuBarController!
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrate any legacy UserDefaults-stored key to the Keychain
        migrateLegacyApiKey()

        // LSUIElement apps don't get the standard menu bar, so we create a
        // minimal one that provides Edit > Paste (Cmd+V) support.
        setupApplicationMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = IconGenerator.menuBarIcon()
            button.image?.isTemplate = true
        }

        menuBarController = MenuBarController(statusItem: statusItem)
        menuBarController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
    }

    /// Creates a minimal application menu so that Edit actions
    /// (Cmd+C / Cmd+V / Cmd+X / Cmd+A) are wired into the responder chain.
    private func setupApplicationMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appSubmenu = NSMenu(title: "Deepseek-Balance")
        appSubmenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appSubmenu

        // Edit menu — this is what makes Cmd+V work
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editSubmenu = NSMenu(title: "Edit")
        editSubmenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editSubmenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editSubmenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editSubmenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editSubmenu

        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.stopTimer()
    }

    /// One‑time migration: moves an API key stored by an older version
    /// from UserDefaults into the macOS Keychain, then removes the plain‑text copy.
    private func migrateLegacyApiKey() {
        let legacyKey = "DeepseekBalance.apiKey"
        guard let oldKey = UserDefaults.standard.string(forKey: legacyKey),
              !oldKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        // Only migrate if the keychain doesn't already have a key
        if (try? KeychainStore.shared.loadSilently()) != nil { return }

        try? KeychainStore.shared.save(oldKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        print("[Deepseek-Balance] Migrated API key from UserDefaults to Keychain")
    }

    private func openSettings() {
        if settingsWindowController == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Deepseek-Balance Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 420, height: 260))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
