import AppKit

// MARK: - Balance menu item with inline refresh button

final class BalanceMenuItemView: NSView {

    var onRefresh: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let refreshButton = NSButton()

    var text: String = "" {
        didSet { label.stringValue = text }
    }

    var showSpinner: Bool = false {
        didSet {
            spinner.isHidden = !showSpinner
            refreshButton.isHidden = showSpinner
            if showSpinner { spinner.startAnimation(nil) }
            else          { spinner.stopAnimation(nil) }
        }
    }

    init(text: String) {
        super.init(frame: .zero)
        self.text = text

        label.stringValue = text
        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)

        // Small refresh icon button
        refreshButton.title = ""
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.bezelStyle = .regularSquare
        refreshButton.isBordered = false
        refreshButton.imagePosition = .imageOnly
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        addSubview(refreshButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            spinner.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 6),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),

            refreshButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 22),
            refreshButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Swallow mouse events so the menu does NOT auto‑dismiss on click.
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        // Only trigger if click is on the refresh button area
        let loc = convert(event.locationInWindow, from: nil)
        if refreshButton.frame.contains(loc) {
            refreshClicked()
        }
    }

    @objc private func refreshClicked() {
        onRefresh?()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 220, height: 22)
    }
}


// MARK: - Menu Bar Controller

final class MenuBarController: NSObject {

    var onOpenSettings: (() -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let service = DeepSeekService()

    // Custom‑view-backed menu items
    private let balanceView = BalanceMenuItemView(text: "Balance: --")

    private let balanceItem: NSMenuItem

    // Background refresh
    private var refreshTimer: Timer?
    private let lowBalanceThreshold: Double = 5.00

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem

        balanceItem = NSMenuItem()

        super.init()

        balanceView.frame = NSRect(x: 0, y: 0, width: 220, height: 22)

        balanceItem.view = balanceView

        buildMenu()
        menu.delegate = self
        statusItem.menu = menu

        balanceView.onRefresh = { [weak self] in
            self?.fetchUsage()
        }

        startTimer()
    }

    deinit { stopTimer() }

    // MARK: - Build menu

    private func buildMenu() {
        menu.removeAllItems()

        menu.addItem(balanceItem)
        menu.addItem(.separator())

        let openItem = NSMenuItem(
            title: "Open DeepSeek Usage…",
            action: #selector(openUsagePage),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(settingsTapped),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func openUsagePage() {
        if let url = URL(string: "https://platform.deepseek.com/usage") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func settingsTapped() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Background timer

    private func startTimer() {
        stopTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
        // Allow the timer to fire while the menu is open
        if let timer = refreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Reset the timer — called when the user opens the menu so the
    /// next background refresh is a full 30 min from now.
    private func resetTimer() {
        startTimer()
    }

    // MARK: - Fetch

    private func fetchUsage() {
        balanceView.showSpinner = true
        balanceView.text = "Balance: --"

        Task { [weak self] in
            guard let self else { return }
            do {
                let usage = try await self.service.fetchUsage()
                await MainActor.run {
                    self.balanceView.showSpinner = false
                    self.balanceView.text = "Balance: \(usage.formattedBalance)"
                    self.statusItem.button?.image = usage.balance < self.lowBalanceThreshold
                        ? IconGenerator.warningIcon()
                        : IconGenerator.menuBarIcon()
                }
            } catch {
                await MainActor.run {
                    self.balanceView.showSpinner = false
                    self.balanceView.text = "Balance: Error"
                }
            }
        }
    }
}

// MARK: - NSMenuDelegate — refresh on open

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        resetTimer()   // restart the 30‑min countdown
        fetchUsage()   // always fetch fresh data on open
    }
}
