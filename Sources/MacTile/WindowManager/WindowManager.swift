import AppKit

/// Top-level window management controller. Observes app launches/terminations and
/// space changes, scans for tileable windows, and reacts to accessibility events
/// (create, destroy, move, resize, focus, minimize). Coordinates the TilingEngine,
/// ShortcutManager, and StatusBarController to provide automatic BSP tiling with
/// keyboard-driven focus, move, and float-toggle support.
final class WindowManager: WindowObserverDelegate {
    private let statusBarController: StatusBarController
    private let windowObserver = WindowObserver()
    private let tilingEngine = TilingEngine()
    private let shortcutManager = ShortcutManager()
    private lazy var shortcutsPanel = ShortcutsPanel(shortcutManager: shortcutManager)
    private var isEnabled = true
    private var observedPIDs: Set<pid_t> = []
    private var suppressMovesUntil: Date = .distantPast
    private var draggingWindowID: WindowID?
    private var resizingWindowID: WindowID?
    private var mouseUpMonitor: Any?

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    init(statusBarController: StatusBarController) {
        self.statusBarController = statusBarController

        statusBarController.onToggleEnabled = { [weak self] enabled in
            self?.isEnabled = enabled
            if enabled { self?.retileCurrentSpace() }
        }
        statusBarController.onRetile = { [weak self] in
            self?.retileCurrentSpace()
        }
        statusBarController.onOpenShortcuts = { [weak self] in
            self?.shortcutsPanel.show()
        }
        shortcutManager.onMoveWindowInDirection = { [weak self] direction in
            self?.moveWindowInDirection(direction)
        }
        shortcutManager.onFocusWindowInDirection = { [weak self] direction in
            self?.focusWindowInDirection(direction)
        }
        shortcutManager.onToggleFloat = { [weak self] in
            self?.toggleFocusedWindowFloat()
        }
    }

    func start() {
        windowObserver.delegate = self

        // Observe space changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // Observe app launches and terminations
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // Update space display and set initial space
        updateSpaceDisplay()
        tilingEngine.setCurrentSpace(SpaceDetector.currentSpaceID())

        // Scan existing apps and windows
        scanExistingWindows()

        // Start listening for workspace shortcuts
        shortcutManager.startMonitoring()
    }

    // MARK: - Space changes

    @objc private func spaceChanged() {
        updateSpaceDisplay()
        let spaceID = SpaceDetector.currentSpaceID()
        tilingEngine.setCurrentSpace(spaceID)
        scanExistingWindows()
    }

    private func updateSpaceDisplay() {
        let index = SpaceDetector.currentSpaceIndex()
        statusBarController.updateSpaceNumber(index)
    }

    // MARK: - App lifecycle

    @objc private func appLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        observeApp(app)
    }

    @objc private func appTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        windowObserver.stopObserving(pid: pid)
        observedPIDs.remove(pid)

        // Remove all windows belonging to this app
        suppressMovesUntil = Date() + 0.3
        tilingEngine.removeWindows(forPID: pid)
    }

    // MARK: - Window scanning

    private func scanExistingWindows() {
        var allWindows: [TrackedWindow] = []

        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            observeApp(app)

            let appEl = AccessibilityElement.appElement(pid: app.processIdentifier)
            let appWindows = appEl.windows

            for windowEl in appWindows {
                guard windowEl.isTileable else { continue }
                guard let windowID = windowEl.windowID else { continue }

                let tracked = TrackedWindow(
                    windowID: windowID,
                    element: windowEl,
                    pid: app.processIdentifier
                )
                allWindows.append(tracked)
            }
        }

        suppressMovesUntil = Date() + 0.3
        tilingEngine.rebuildCurrentSpace(windows: allWindows)
    }

    private func observeApp(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        let pid = app.processIdentifier
        guard !observedPIDs.contains(pid) else { return }
        observedPIDs.insert(pid)
        windowObserver.observe(app: app)
    }

    private func retileCurrentSpace() {
        tilingEngine.setCurrentSpace(SpaceDetector.currentSpaceID())
        scanExistingWindows()
    }

    // MARK: - WindowObserverDelegate

    func windowCreated(element: AXUIElement, pid: pid_t) {
        guard isEnabled else { return }

        // Delay slightly to let the window finish initializing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let el = AccessibilityElement(element)
            guard el.isTileable else { return }
            guard let windowID = el.windowID else { return }
            guard !self.tilingEngine.isTracked(windowID: windowID) else { return }

            let tracked = TrackedWindow(windowID: windowID, element: el, pid: pid)
            self.suppressMovesUntil = Date() + 0.3
            self.tilingEngine.insertWindow(tracked)
        }
    }

    func windowDestroyed(element: AXUIElement, pid: pid_t) {
        guard isEnabled else { return }
        suppressMovesUntil = Date() + 0.3

        // Try direct lookup first (element may still be valid)
        let el = AccessibilityElement(element)
        if let windowID = el.windowID {
            tilingEngine.removeWindow(windowID: windowID)
            return
        }

        // Element is dead — find a stale window belonging to this pid
        if let windowID = tilingEngine.staleWindowID(forPID: pid) {
            tilingEngine.removeWindow(windowID: windowID)
            return
        }

        // Fallback: reconcile to find and remove any stale windows
        tilingEngine.reconcile()
    }

    func focusedWindowChanged(element: AXUIElement, pid: pid_t) {
        let el = AccessibilityElement(element)
        if let windowID = el.windowID {
            tilingEngine.setFocused(windowID: windowID)
        }
    }

    func windowMinimized(element: AXUIElement, pid: pid_t) {
        guard isEnabled else { return }
        suppressMovesUntil = Date() + 0.3
        let el = AccessibilityElement(element)
        if let windowID = el.windowID {
            tilingEngine.removeWindow(windowID: windowID)
        }
    }

    func windowDeminimized(element: AXUIElement, pid: pid_t) {
        guard isEnabled else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let el = AccessibilityElement(element)
            guard el.isTileable else { return }
            guard let windowID = el.windowID else { return }
            guard !self.tilingEngine.isTracked(windowID: windowID) else { return }

            let tracked = TrackedWindow(windowID: windowID, element: el, pid: pid)
            self.suppressMovesUntil = Date() + 0.3
            self.tilingEngine.insertWindow(tracked)
        }
    }

    func windowMoved(element: AXUIElement, pid: pid_t) {
        guard isEnabled else { return }

        // Ignore moves caused by our own layout
        if Date() < suppressMovesUntil { return }
        if tilingEngine.isApplyingLayout { return }

        let el = AccessibilityElement(element)
        guard let windowID = el.windowID else { return }
        guard tilingEngine.isTracked(windowID: windowID) else { return }
        if tilingEngine.trackedWindow(windowID: windowID)?.isFloating == true { return }

        // Mark this window as being dragged
        draggingWindowID = windowID

        // Install a global mouse-up monitor if not already active
        if mouseUpMonitor == nil {
            mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
                self?.handleMouseUp()
            }
        }
    }

    func windowResized(element: AXUIElement, pid: pid_t) {
        guard isEnabled else { return }

        if Date() < suppressMovesUntil { return }
        if tilingEngine.isApplyingLayout { return }

        let el = AccessibilityElement(element)
        guard let windowID = el.windowID else { return }
        guard tilingEngine.isTracked(windowID: windowID) else { return }
        if tilingEngine.trackedWindow(windowID: windowID)?.isFloating == true { return }

        resizingWindowID = windowID

        if mouseUpMonitor == nil {
            mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
                self?.handleMouseUp()
            }
        }
    }

    // MARK: - Drag-and-drop rearrangement

    private func handleMouseUp() {
        // Remove the monitor immediately
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            mouseUpMonitor = nil
        }

        // Resize takes priority over drag
        if let windowID = resizingWindowID {
            resizingWindowID = nil
            draggingWindowID = nil
            handleWindowResize(windowID: windowID)
            return
        }

        guard let windowID = draggingWindowID else { return }
        draggingWindowID = nil

        handleWindowDrop(windowID: windowID)
    }

    private static let minDragDistance: CGFloat = 50

    private func handleWindowDrop(windowID: WindowID) {
        guard tilingEngine.isTracked(windowID: windowID) else { return }

        // Read the dropped window's current position and size
        guard let tracked = tilingEngine.trackedWindow(windowID: windowID) else { return }
        guard let pos = tracked.element.position, let size = tracked.element.size else {
            retileWithSuppress()
            return
        }

        // Check if the window moved far enough from its layout position
        guard let layoutFrame = tilingEngine.lastLayoutFrame(for: windowID) else {
            retileWithSuppress()
            return
        }
        let dx = pos.x - layoutFrame.origin.x
        let dy = pos.y - layoutFrame.origin.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < Self.minDragDistance {
            // Didn't move enough — snap back
            retileWithSuppress()
            return
        }

        // Compute center point of the dropped window
        let center = CGPoint(x: pos.x + size.width / 2, y: pos.y + size.height / 2)

        // Find which tiled window the center falls within
        guard let targetID = tilingEngine.windowAt(point: center),
              targetID != windowID else {
            // No valid target — snap back to layout
            retileWithSuppress()
            return
        }

        // Determine split direction based on where in the target the drop landed
        guard let targetFrame = tilingEngine.lastLayoutFrame(for: targetID) else {
            retileWithSuppress()
            return
        }

        let relX = (center.x - targetFrame.origin.x) / targetFrame.width
        let relY = (center.y - targetFrame.origin.y) / targetFrame.height

        let direction: SplitDirection
        let placeFirst: Bool

        if abs(relX - 0.5) > abs(relY - 0.5) {
            direction = .horizontal
            placeFirst = relX < 0.5
        } else {
            direction = .vertical
            placeFirst = relY < 0.5
        }

        suppressMovesUntil = Date() + 0.3
        tilingEngine.moveWindow(windowID: windowID, toTarget: targetID, direction: direction, placeFirst: placeFirst)
    }

    private func handleWindowResize(windowID: WindowID) {
        guard tilingEngine.isTracked(windowID: windowID) else { return }
        guard let tracked = tilingEngine.trackedWindow(windowID: windowID) else { return }
        guard let pos = tracked.element.position, let size = tracked.element.size else {
            retileWithSuppress()
            return
        }

        // Require meaningful size change (>5px) to filter noise
        guard let layoutFrame = tilingEngine.lastLayoutFrame(for: windowID) else {
            retileWithSuppress()
            return
        }
        let dw = abs(size.width - layoutFrame.width)
        let dh = abs(size.height - layoutFrame.height)
        guard dw > 5 || dh > 5 else {
            retileWithSuppress()
            return
        }

        let actualFrame = CGRect(origin: pos, size: size)
        suppressMovesUntil = Date() + 0.3
        tilingEngine.adjustSplitRatio(windowID: windowID, actualFrame: actualFrame)
    }

    private func retileWithSuppress() {
        suppressMovesUntil = Date() + 0.3
        tilingEngine.retile()
    }

    // MARK: - Toggle floating

    private func toggleFocusedWindowFloat() {
        guard isEnabled else { return }
        guard let windowID = tilingEngine.focusedWindowID else { return }

        suppressMovesUntil = Date() + 0.3
        tilingEngine.toggleFloating(windowID: windowID)
    }

    // MARK: - Focus window in direction

    private func focusWindowInDirection(_ direction: MoveDirection) {
        guard isEnabled else { return }
        guard let windowID = tilingEngine.focusedWindowID else { return }
        guard let targetID = tilingEngine.neighborOf(windowID: windowID, direction: direction) else { return }
        guard let tracked = tilingEngine.trackedWindow(windowID: targetID) else { return }

        // Activate the app owning the target window and raise it
        if let app = NSRunningApplication(processIdentifier: tracked.pid) {
            app.activate()
        }
        tracked.element.raise()
        tilingEngine.setFocused(windowID: targetID)
    }

    // MARK: - Move window in direction

    private func moveWindowInDirection(_ direction: MoveDirection) {
        guard isEnabled else { return }
        guard let windowID = tilingEngine.focusedWindowID else { return }
        guard let targetID = tilingEngine.neighborOf(windowID: windowID, direction: direction) else { return }

        let splitDirection: SplitDirection
        let placeFirst: Bool

        switch direction {
        case .left:  splitDirection = .horizontal; placeFirst = true
        case .right: splitDirection = .horizontal; placeFirst = false
        case .up:    splitDirection = .vertical;   placeFirst = true
        case .down:  splitDirection = .vertical;   placeFirst = false
        }

        suppressMovesUntil = Date() + 0.3
        tilingEngine.moveWindow(windowID: windowID, toTarget: targetID, direction: splitDirection, placeFirst: placeFirst)
    }

}
