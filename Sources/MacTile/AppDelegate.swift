import AppKit

/// App lifecycle delegate. Initializes the status bar and window manager on launch,
/// and gates startup on accessibility permissions being granted.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var windowManager: WindowManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[MacTile] App launched")
        statusBarController = StatusBarController()
        windowManager = WindowManager(statusBarController: statusBarController)

        NSLog("[MacTile] AXIsProcessTrusted = \(AXIsProcessTrusted())")
        AccessibilityHelper.ensureAccessibilityPermissions {
            NSLog("[MacTile] Accessibility granted, starting window manager")
            self.windowManager.start()
        }
    }
}
