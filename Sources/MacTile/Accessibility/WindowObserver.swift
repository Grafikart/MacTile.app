import AppKit

protocol WindowObserverDelegate: AnyObject {
    func windowCreated(element: AXUIElement, pid: pid_t)
    func windowDestroyed(element: AXUIElement, pid: pid_t)
    func focusedWindowChanged(element: AXUIElement, pid: pid_t)
    func windowMinimized(element: AXUIElement, pid: pid_t)
    func windowDeminimized(element: AXUIElement, pid: pid_t)
    func windowMoved(element: AXUIElement, pid: pid_t)
    func windowResized(element: AXUIElement, pid: pid_t)
}

/// Registers AXObserver callbacks for each running application to detect window
/// creation, destruction, focus changes, minimize/deminimize, move, and resize events.
/// Forwards all events to a WindowObserverDelegate (the WindowManager).
final class WindowObserver {
    private var observers: [pid_t: AXObserver] = [:]
    weak var delegate: WindowObserverDelegate?

    private static let notifications: [String] = [
        kAXWindowCreatedNotification,
        kAXUIElementDestroyedNotification,
        kAXFocusedWindowChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
    ]

    func observe(app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, axCallback, &observer)
        guard result == .success, let observer = observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        for notification in Self.notifications {
            AXObserverAddNotification(observer, appElement, notification as CFString, refcon)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        observers[pid] = observer
    }

    func stopObserving(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )
    }

    func stopAll() {
        for pid in observers.keys {
            stopObserving(pid: pid)
        }
    }
}

private func axCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let windowObserver = Unmanaged<WindowObserver>.fromOpaque(refcon).takeUnretainedValue()
    guard let delegate = windowObserver.delegate else { return }

    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)

    let name = notification as String

    DispatchQueue.main.async {
        switch name {
        case kAXWindowCreatedNotification:
            delegate.windowCreated(element: element, pid: pid)
        case kAXUIElementDestroyedNotification:
            delegate.windowDestroyed(element: element, pid: pid)
        case kAXFocusedWindowChangedNotification:
            delegate.focusedWindowChanged(element: element, pid: pid)
        case kAXWindowMiniaturizedNotification:
            delegate.windowMinimized(element: element, pid: pid)
        case kAXWindowDeminiaturizedNotification:
            delegate.windowDeminimized(element: element, pid: pid)
        case kAXWindowMovedNotification:
            delegate.windowMoved(element: element, pid: pid)
        case kAXWindowResizedNotification:
            delegate.windowResized(element: element, pid: pid)
        default:
            break
        }
    }
}
