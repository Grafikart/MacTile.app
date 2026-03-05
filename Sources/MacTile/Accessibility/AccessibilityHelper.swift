import AppKit

/// Ensures the app has macOS accessibility (AX) permissions.
/// Prompts the user if not yet trusted and polls until granted.
enum AccessibilityHelper {
    static func ensureAccessibilityPermissions(completion: @escaping () -> Void) {
        if AXIsProcessTrusted() {
            completion()
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        pollForPermission(completion: completion)
    }

    private static func pollForPermission(completion: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                completion()
            }
        }
    }
}
