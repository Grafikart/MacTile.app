import AppKit

final class StylePanel: NSObject {
    private var window: NSWindow?
    private var valueLabel: NSTextField?
    var onGapChanged: (() -> Void)?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let padding: CGFloat = 16
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 80

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Style"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        let currentGap = Self.currentGap()

        let label = NSTextField(labelWithString: "Gap:")
        label.frame = NSRect(x: padding, y: 30, width: 32, height: 20)
        label.font = .systemFont(ofSize: 13)
        contentView.addSubview(label)

        let valueLabel = NSTextField(labelWithString: "\(Int(currentGap))")
        valueLabel.frame = NSRect(x: windowWidth - padding - 28, y: 30, width: 28, height: 20)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        valueLabel.alignment = .right
        contentView.addSubview(valueLabel)
        self.valueLabel = valueLabel

        let sliderX = padding + 36
        let sliderWidth = windowWidth - sliderX - padding - 32
        let slider = NSSlider(value: Double(currentGap), minValue: 0, maxValue: 20, target: self, action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: sliderX, y: 30, width: sliderWidth, height: 20)
        slider.isContinuous = true
        slider.numberOfTickMarks = 21
        slider.allowsTickMarkValuesOnly = true
        contentView.addSubview(slider)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = Int(sender.doubleValue)
        valueLabel?.stringValue = "\(value)"
        UserDefaults.standard.set(Double(value), forKey: "GapSize")
        onGapChanged?()
    }

    private static func currentGap() -> CGFloat {
        let value = UserDefaults.standard.double(forKey: "GapSize")
        return value == 0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains("GapSize") ? 8.0 : value
    }
}
