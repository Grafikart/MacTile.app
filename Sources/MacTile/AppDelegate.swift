import AppKit

/// App lifecycle delegate. Initializes the status bar and window manager on launch,
/// and gates startup on accessibility permissions being granted.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var windowManager: WindowManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        windowManager = WindowManager(statusBarController: statusBarController)

        AccessibilityHelper.ensureAccessibilityPermissions {
            self.windowManager.start()
        }
    }
}
