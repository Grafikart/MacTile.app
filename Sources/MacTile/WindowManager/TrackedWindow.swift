import AppKit

typealias WindowID = CGWindowID

/// Represents a window being managed by MacTile. Stores the CGWindowID, its
/// accessibility element reference, owning process, and per-window state such as
/// whether it is currently floating (excluded from tiling layout).
struct TrackedWindow {
    let windowID: WindowID
    let element: AccessibilityElement
    let pid: pid_t
    var title: String?
    var isFloating: Bool = false

    init(windowID: WindowID, element: AccessibilityElement, pid: pid_t) {
        self.windowID = windowID
        self.element = element
        self.pid = pid
        self.title = element.title
    }
}
