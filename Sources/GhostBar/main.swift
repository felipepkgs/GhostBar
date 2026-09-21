import AppKit

SingleInstanceLock.acquireOrExit()

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar-only, no Dock icon
app.run()
