import AppKit
import CGSPrivate

/// Wrapper around AXUIElement providing convenient access to window properties
/// (position, size, role, minimized state) and actions (setFrame, raise).
/// Used to read and manipulate on-screen windows via the Accessibility API.
struct AccessibilityElement {
    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    static func appElement(pid: pid_t) -> AccessibilityElement {
        AccessibilityElement(AXUIElementCreateApplication(pid))
    }

    // MARK: - Properties

    var windowID: CGWindowID? {
        var wid: UInt32 = 0
        let result = _AXUIElementGetWindow(element, &wid)
        return result == .success ? CGWindowID(wid) : nil
    }

    var title: String? {
        getAttribute(kAXTitleAttribute as CFString)
    }

    var role: String? {
        getAttribute(kAXRoleAttribute as CFString)
    }

    var subrole: String? {
        getAttribute(kAXSubroleAttribute as CFString)
    }

    var isMinimized: Bool {
        let val: Bool? = getAttribute(kAXMinimizedAttribute as CFString)
        return val ?? false
    }

    var isResizable: Bool {
        var resizable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &resizable)
        return result == .success && resizable.boolValue
    }

    var position: CGPoint? {
        get {
            guard let value: AXValue = getAttribute(kAXPositionAttribute as CFString) else { return nil }
            var point = CGPoint.zero
            AXValueGetValue(value, .cgPoint, &point)
            return point
        }
        set {
            guard var point = newValue else { return }
            guard let value = AXValueCreate(.cgPoint, &point) else { return }
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        }
    }

    var size: CGSize? {
        get {
            guard let value: AXValue = getAttribute(kAXSizeAttribute as CFString) else { return nil }
            var size = CGSize.zero
            AXValueGetValue(value, .cgSize, &size)
            return size
        }
        set {
            guard var size = newValue else { return }
            guard let value = AXValueCreate(.cgSize, &size) else { return }
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        }
    }

    var windowsError: AXError {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
    }

    var windows: [AccessibilityElement] {
        guard let elements: CFArray = getAttribute(kAXWindowsAttribute as CFString) else { return [] }
        let count = CFArrayGetCount(elements)
        return (0..<count).map { i in
            let ptr = CFArrayGetValueAtIndex(elements, i)!
            let el = Unmanaged<AXUIElement>.fromOpaque(ptr).takeUnretainedValue()
            return AccessibilityElement(el)
        }
    }

    var focusedWindow: AccessibilityElement? {
        guard let el: AXUIElement = getAttribute(kAXFocusedWindowAttribute as CFString) else { return nil }
        return AccessibilityElement(el)
    }

    // MARK: - Frame

    func setFrame(_ rect: CGRect) {
        // size→position→size pattern for reliable placement
        setSize(rect.size)
        setPosition(rect.origin)
        setSize(rect.size)
    }

    private func setPosition(_ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setSize(_ size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    // MARK: - Window Layer

    var windowLayer: Int? {
        guard let wid = windowID else { return nil }
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], wid) as? [[String: Any]]
        return info?.first?[kCGWindowLayer as String] as? Int
    }

    var isOnScreen: Bool {
        guard let wid = windowID else { return false }
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], wid) as? [[String: Any]]
        return info?.first?[kCGWindowIsOnscreen as String] as? Bool ?? false
    }

    // MARK: - Tileability

    var isTileable: Bool {
        guard let role = role else { return false }
        guard role == (kAXWindowRole as String) else { return false }

        let sub = subrole
        if sub == (kAXDialogSubrole as String) { return false }
        if sub == "AXSystemDialog" { return false }
        if sub == "AXFloatingWindow" { return false }
        if sub == "AXPanel" { return false }
        if sub == "AXSheet" { return false }
        if sub == "AXPopover" { return false }

        guard isResizable else { return false }
        guard !isMinimized else { return false }

        if let layer = windowLayer, layer > 0 { return false }

        return true
    }

    // MARK: - Actions

    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    // MARK: - Helpers

    private func getAttribute<T>(_ attribute: CFString) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value as? T
    }
}
