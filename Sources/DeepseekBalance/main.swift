import AppKit

// Prevent this from appearing in the Dock — menu bar only
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
