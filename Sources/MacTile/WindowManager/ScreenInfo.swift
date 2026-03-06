import AppKit

/// Provides the usable screen area (excluding the menu bar and Dock) converted
/// to Accessibility API coordinates (top-left origin).
struct ScreenInfo {
    /// Returns the usable screen area in AX coordinates (top-left origin).
    static func usableFrame(for screen: NSScreen? = nil) -> CGRect {
        guard let screen = screen ?? NSScreen.main else {
            return .zero
        }

        let visible = screen.visibleFrame

        // AX coordinates use a global top-left origin system.
        // The primary screen's height defines the global coordinate space.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let axY = primaryHeight - visible.origin.y - visible.height
        return CGRect(
            x: visible.origin.x,
            y: axY,
            width: visible.width,
            height: visible.height
        )
    }

    /// Returns the screen containing the given AX-coordinate point.
    static func screen(containing axPoint: CGPoint) -> NSScreen? {
        // Cocoa coordinates are relative to the primary screen's bottom-left origin.
        // The primary screen (screens[0]) defines the global coordinate space.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoaY = primaryHeight - axPoint.y

        for screen in NSScreen.screens {
            if screen.frame.contains(CGPoint(x: axPoint.x, y: cocoaY)) {
                return screen
            }
        }
        return NSScreen.main
    }
}
