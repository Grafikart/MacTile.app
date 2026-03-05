/// Application entry point. Creates the NSApplication instance, sets the AppDelegate,
/// and starts the main run loop.

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
