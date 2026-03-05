import AppKit

/// A custom NSView that captures a keyboard shortcut from the user. Click to start
/// recording, press a modifier+key combination to set, Escape to cancel, or clear
/// with the ✕ button. Used in the ShortcutsPanel for configuring hotkeys.
final class ShortcutRecorderView: NSView {
    private enum State {
        case empty
        case recording
        case set(KeyboardShortcut)
    }

    private var state: State = .empty
    private var stateBeforeRecording: State = .empty
    private var eventMonitor: Any?
    private let label = NSTextField(labelWithString: "Click to record")
    private let clearButton = NSButton(title: "✕", target: nil, action: nil)
    var onShortcutChanged: ((KeyboardShortcut?) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        addSubview(label)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isBordered = false
        clearButton.font = .systemFont(ofSize: 11)
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        clearButton.isHidden = true
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 16),
        ])

        updateDisplay()
    }

    func setShortcut(_ shortcut: KeyboardShortcut?) {
        if let shortcut = shortcut {
            state = .set(shortcut)
        } else {
            state = .empty
        }
        updateDisplay()
    }

    private func updateDisplay() {
        switch state {
        case .empty:
            label.stringValue = "Click to record"
            label.textColor = .placeholderTextColor
            clearButton.isHidden = true
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        case .recording:
            label.stringValue = "Press shortcut..."
            label.textColor = .systemRed
            clearButton.isHidden = true
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        case .set(let shortcut):
            label.stringValue = shortcut.displayString
            label.textColor = .labelColor
            clearButton.isHidden = false
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    // MARK: - Mouse / Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        stateBeforeRecording = state
        state = .recording
        updateDisplay()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.recordEvent(event) ? nil : event
        }
    }

    private func recordEvent(_ event: NSEvent) -> Bool {
        // Escape cancels recording
        if event.keyCode == 0x35 {
            state = stateBeforeRecording
            stopRecording()
            return true
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require at least one modifier
        let hasModifier = flags.contains(.control) || flags.contains(.option)
            || flags.contains(.shift) || flags.contains(.command)
        guard hasModifier else { return false }

        let shortcut = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: flags.rawValue)
        state = .set(shortcut)
        stopRecording()
        onShortcutChanged?(shortcut)
        return true
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        window?.makeFirstResponder(nil)
        updateDisplay()
    }

    override func resignFirstResponder() -> Bool {
        if case .recording = state {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            state = stateBeforeRecording
            updateDisplay()
        }
        return super.resignFirstResponder()
    }

    @objc private func clearShortcut() {
        state = .empty
        updateDisplay()
        onShortcutChanged?(nil)
    }
}
