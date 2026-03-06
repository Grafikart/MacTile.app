import AppKit

/// Menu bar status item showing the current Space number. Provides a dropdown menu
/// to enable/disable tiling, re-tile the current space, open the shortcuts panel,
/// and quit the app.
final class StatusBarController {
    private let statusItem: NSStatusItem
    private var enabledMenuItem: NSMenuItem!
    private var isEnabled = true
    var onRetile: (() -> Void)?
    var onToggleEnabled: ((Bool) -> Void)?
    var onOpenShortcuts: (() -> Void)?
    var onOpenStyle: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateSpaceNumber(1)
        buildMenu()
    }

    func updateSpaceNumber(_ number: Int) {
        statusItem.button?.title = "[ \(number) ]"
    }

    private func buildMenu() {
        let menu = NSMenu()

        enabledMenuItem = NSMenuItem(title: "Disable", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.target = self
        menu.addItem(enabledMenuItem)

        let retileItem = NSMenuItem(title: "Re-tile", action: #selector(retile), keyEquivalent: "r")
        retileItem.target = self
        menu.addItem(retileItem)

        let shortcutsItem = NSMenuItem(title: "Shortcuts…", action: #selector(openShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        let styleItem = NSMenuItem(title: "Style…", action: #selector(openStyle), keyEquivalent: "")
        styleItem.target = self
        menu.addItem(styleItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enabledMenuItem.title = isEnabled ? "Disable" : "Enable"
        onToggleEnabled?(isEnabled)
    }

    @objc private func retile() {
        onRetile?()
    }

    @objc private func openShortcuts() {
        onOpenShortcuts?()
    }

    @objc private func openStyle() {
        onOpenStyle?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
