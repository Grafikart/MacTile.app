import AppKit

/// Provides the usable screen area (excluding the menu bar and Dock) converted
/// to Accessibility API coordinates (top-left origin).
struct ScreenInfo {
    /// Returns the usable screen area in AX coordinates (top-left origin).
    static func usableFrame(for screen: NSScreen? = nil) -> CGRect {
        guard let screen = screen ?? NSScreen.main else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }

        let full = screen.frame
        let visible = screen.visibleFrame

        // Convert from Cocoa (bottom-left origin) to AX (top-left origin)
        let axY = full.height - visible.origin.y - visible.height
        return CGRect(
            x: visible.origin.x,
            y: axY,
            width: visible.width,
            height: visible.height
        )
    }

    /// Returns the screen containing the given AX-coordinate point.
    static func screen(containing axPoint: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            let full = screen.frame
            let cocoaY = full.height - axPoint.y
            if full.contains(CGPoint(x: axPoint.x, y: cocoaY)) {
                return screen
            }
        }
        return NSScreen.main
    }
}
