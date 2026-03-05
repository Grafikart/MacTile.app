import AppKit

/// Manages global keyboard shortcuts for window movement, focus, and float toggle.
/// Persists shortcut bindings to UserDefaults, prevents duplicates across categories,
/// and dispatches matched key events to registered callbacks.
final class ShortcutManager {
    private(set) var moveShortcuts: [MoveDirection: KeyboardShortcut] = [:]
    private(set) var focusShortcuts: [MoveDirection: KeyboardShortcut] = [:]
    private(set) var floatShortcut: KeyboardShortcut?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onMoveWindowInDirection: ((MoveDirection) -> Void)?
    var onFocusWindowInDirection: ((MoveDirection) -> Void)?
    var onToggleFloat: (() -> Void)?

    private static let moveDefaultsKey = "MoveShortcuts"
    private static let focusDefaultsKey = "FocusShortcuts"
    private static let floatDefaultsKey = "FloatShortcut"

    private static let defaultMoveShortcuts: [MoveDirection: KeyboardShortcut] = {
        let ctrlShift = NSEvent.ModifierFlags.control.union(.shift).rawValue
        return [
            .left:  KeyboardShortcut(keyCode: 0x7B, modifierFlags: ctrlShift),
            .right: KeyboardShortcut(keyCode: 0x7C, modifierFlags: ctrlShift),
            .up:    KeyboardShortcut(keyCode: 0x7E, modifierFlags: ctrlShift),
            .down:  KeyboardShortcut(keyCode: 0x7D, modifierFlags: ctrlShift),
        ]
    }()

    private static let defaultFocusShortcuts: [MoveDirection: KeyboardShortcut] = {
        let ctrl = NSEvent.ModifierFlags.control.rawValue
        return [
            .left:  KeyboardShortcut(keyCode: 0x7B, modifierFlags: ctrl),
            .right: KeyboardShortcut(keyCode: 0x7C, modifierFlags: ctrl),
            .up:    KeyboardShortcut(keyCode: 0x7E, modifierFlags: ctrl),
            .down:  KeyboardShortcut(keyCode: 0x7D, modifierFlags: ctrl),
        ]
    }()

    init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.moveDefaultsKey),
           let decoded = try? JSONDecoder().decode([MoveDirection: KeyboardShortcut].self, from: data) {
            moveShortcuts = decoded
        } else {
            moveShortcuts = Self.defaultMoveShortcuts
        }
        if let data = UserDefaults.standard.data(forKey: Self.focusDefaultsKey),
           let decoded = try? JSONDecoder().decode([MoveDirection: KeyboardShortcut].self, from: data) {
            focusShortcuts = decoded
        } else {
            focusShortcuts = Self.defaultFocusShortcuts
        }
        if let data = UserDefaults.standard.data(forKey: Self.floatDefaultsKey),
           let decoded = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            floatShortcut = decoded
        } else {
            // Default: Ctrl+F (keyCode 0x03)
            floatShortcut = KeyboardShortcut(keyCode: 0x03, modifierFlags: NSEvent.ModifierFlags.control.rawValue)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(moveShortcuts) {
            UserDefaults.standard.set(data, forKey: Self.moveDefaultsKey)
        }
        if let data = try? JSONEncoder().encode(focusShortcuts) {
            UserDefaults.standard.set(data, forKey: Self.focusDefaultsKey)
        }
        if let shortcut = floatShortcut, let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.floatDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.floatDefaultsKey)
        }
    }

    // MARK: - Configuration

    func setShortcut(_ shortcut: KeyboardShortcut?, forDirection direction: MoveDirection) {
        if let shortcut = shortcut {
            for (dir, existing) in moveShortcuts where existing == shortcut && dir != direction {
                moveShortcuts.removeValue(forKey: dir)
            }
            for (dir, existing) in focusShortcuts where existing == shortcut {
                focusShortcuts.removeValue(forKey: dir)
            }
            if floatShortcut == shortcut { floatShortcut = nil }
        }
        if let shortcut = shortcut {
            moveShortcuts[direction] = shortcut
        } else {
            moveShortcuts.removeValue(forKey: direction)
        }
        save()
    }

    func setFocusShortcut(_ shortcut: KeyboardShortcut?, forDirection direction: MoveDirection) {
        if let shortcut = shortcut {
            for (dir, existing) in focusShortcuts where existing == shortcut && dir != direction {
                focusShortcuts.removeValue(forKey: dir)
            }
            for (dir, existing) in moveShortcuts where existing == shortcut {
                moveShortcuts.removeValue(forKey: dir)
            }
            if floatShortcut == shortcut { floatShortcut = nil }
        }
        if let shortcut = shortcut {
            focusShortcuts[direction] = shortcut
        } else {
            focusShortcuts.removeValue(forKey: direction)
        }
        save()
    }

    func setFloatShortcut(_ shortcut: KeyboardShortcut?) {
        if let shortcut = shortcut {
            // Clear duplicates from move/focus shortcuts
            for (dir, existing) in moveShortcuts where existing == shortcut {
                moveShortcuts.removeValue(forKey: dir)
            }
            for (dir, existing) in focusShortcuts where existing == shortcut {
                focusShortcuts.removeValue(forKey: dir)
            }
        }
        floatShortcut = shortcut
        save()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        stopMonitoring()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let pressed = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue)

        for (direction, shortcut) in moveShortcuts {
            if shortcut == pressed {
                onMoveWindowInDirection?(direction)
                return
            }
        }

        for (direction, shortcut) in focusShortcuts {
            if shortcut == pressed {
                onFocusWindowInDirection?(direction)
                return
            }
        }

        if let shortcut = floatShortcut, shortcut == pressed {
            onToggleFloat?()
            return
        }
    }
}
