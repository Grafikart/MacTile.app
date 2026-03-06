import AppKit

/// Presents a preferences window with ShortcutRecorderView rows for configuring
/// window movement, focus, and float toggle keyboard shortcuts. Pauses global
/// shortcut monitoring while open to avoid conflicts during recording.
final class ShortcutsPanel: NSObject {
    private var window: NSWindow?
    private var moveRecorders: [MoveDirection: ShortcutRecorderView] = [:]
    private var focusRecorders: [MoveDirection: ShortcutRecorderView] = [:]
    private var floatRecorder: ShortcutRecorderView?
    private let shortcutManager: ShortcutManager

    init(shortcutManager: ShortcutManager) {
        self.shortcutManager = shortcutManager
        super.init()
    }

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        shortcutManager.stopMonitoring()

        let rowHeight: CGFloat = 36
        let padding: CGFloat = 16
        let headerHeight: CGFloat = 24
        let labelWidth: CGFloat = 120
        let recorderWidth: CGFloat = 180
        let windowWidth = padding + labelWidth + 8 + recorderWidth + padding

        let moveRows = MoveDirection.allCases.count  // 4
        let sectionSpacing: CGFloat = 24
        let windowHeight = padding
            + headerHeight + (rowHeight * CGFloat(moveRows))
            + sectionSpacing
            + headerHeight + (rowHeight * CGFloat(moveRows))
            + sectionSpacing
            + headerHeight + rowHeight
            + padding

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Shortcuts"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        var y = windowHeight - padding

        // — Window Movement section —
        y -= headerHeight
        let moveHeader = NSTextField(labelWithString: "Window Movement")
        moveHeader.frame = NSRect(x: padding, y: y, width: windowWidth - padding * 2, height: 18)
        moveHeader.font = .boldSystemFont(ofSize: 13)
        contentView.addSubview(moveHeader)

        for direction in MoveDirection.allCases {
            y -= rowHeight

            let label = NSTextField(labelWithString: "\(direction.displayName):")
            label.frame = NSRect(x: padding, y: y + 6, width: labelWidth, height: 20)
            label.alignment = .right
            label.font = .systemFont(ofSize: 13)
            contentView.addSubview(label)

            let recorder = ShortcutRecorderView(frame: NSRect(
                x: padding + labelWidth + 8,
                y: y + 2,
                width: recorderWidth,
                height: 28
            ))
            recorder.setShortcut(shortcutManager.moveShortcuts[direction])
            recorder.onShortcutChanged = { [weak self] shortcut in
                self?.shortcutManager.setShortcut(shortcut, forDirection: direction)
                self?.refreshRecorders()
            }
            contentView.addSubview(recorder)
            moveRecorders[direction] = recorder
        }

        // — Focus Window section —
        y -= sectionSpacing + headerHeight
        let focusHeader = NSTextField(labelWithString: "Focus Window")
        focusHeader.frame = NSRect(x: padding, y: y, width: windowWidth - padding * 2, height: 18)
        focusHeader.font = .boldSystemFont(ofSize: 13)
        contentView.addSubview(focusHeader)

        for direction in MoveDirection.allCases {
            y -= rowHeight

            let label = NSTextField(labelWithString: "\(direction.displayName):")
            label.frame = NSRect(x: padding, y: y + 6, width: labelWidth, height: 20)
            label.alignment = .right
            label.font = .systemFont(ofSize: 13)
            contentView.addSubview(label)

            let recorder = ShortcutRecorderView(frame: NSRect(
                x: padding + labelWidth + 8,
                y: y + 2,
                width: recorderWidth,
                height: 28
            ))
            recorder.setShortcut(shortcutManager.focusShortcuts[direction])
            recorder.onShortcutChanged = { [weak self] shortcut in
                self?.shortcutManager.setFocusShortcut(shortcut, forDirection: direction)
                self?.refreshRecorders()
            }
            contentView.addSubview(recorder)
            focusRecorders[direction] = recorder
        }

        // — Floating section —
        y -= sectionSpacing + headerHeight
        let floatHeader = NSTextField(labelWithString: "Floating")
        floatHeader.frame = NSRect(x: padding, y: y, width: windowWidth - padding * 2, height: 18)
        floatHeader.font = .boldSystemFont(ofSize: 13)
        contentView.addSubview(floatHeader)

        y -= rowHeight

        let floatLabel = NSTextField(labelWithString: "Toggle Float:")
        floatLabel.frame = NSRect(x: padding, y: y + 6, width: labelWidth, height: 20)
        floatLabel.alignment = .right
        floatLabel.font = .systemFont(ofSize: 13)
        contentView.addSubview(floatLabel)

        let floatRec = ShortcutRecorderView(frame: NSRect(
            x: padding + labelWidth + 8,
            y: y + 2,
            width: recorderWidth,
            height: 28
        ))
        floatRec.setShortcut(shortcutManager.floatShortcut)
        floatRec.onShortcutChanged = { [weak self] shortcut in
            self?.shortcutManager.setFloatShortcut(shortcut)
            self?.refreshRecorders()
        }
        contentView.addSubview(floatRec)
        floatRecorder = floatRec

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func refreshRecorders() {
        for (direction, recorder) in moveRecorders {
            recorder.setShortcut(shortcutManager.moveShortcuts[direction])
        }
        for (direction, recorder) in focusRecorders {
            recorder.setShortcut(shortcutManager.focusShortcuts[direction])
        }
        floatRecorder?.setShortcut(shortcutManager.floatShortcut)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        shortcutManager.startMonitoring()
        moveRecorders.removeAll()
        focusRecorders.removeAll()
        floatRecorder = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
    }
}
