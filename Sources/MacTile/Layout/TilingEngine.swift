import AppKit

enum MoveDirection: String, Codable, CaseIterable {
    case left, right, up, down

    var displayName: String {
        switch self {
        case .left:  return "Move Left"
        case .right: return "Move Right"
        case .up:    return "Move Up"
        case .down:  return "Move Down"
        }
    }
}

/// Central tiling coordinator. Maintains per-space BSP trees and a registry of all
/// tracked windows. Handles window insert/remove, drag-drop rearrangement, split-ratio
/// adjustment, floating toggle, and directional neighbor lookup. Applies computed
/// layouts to on-screen windows via AccessibilityElement.
final class TilingEngine {
    private var trees: [Int: BSPTree] = [:]  // spaceID → tree
    private var trackedWindows: [WindowID: TrackedWindow] = [:]
    private var currentSpaceID: Int = 1
    private var lastLayoutMap: [WindowID: CGRect] = [:]
    private(set) var isApplyingLayout = false

    var currentSpaceIDValue: Int { currentSpaceID }

    func setCurrentSpace(_ spaceID: Int) {
        currentSpaceID = spaceID
    }

    private func currentTree() -> BSPTree {
        if let tree = trees[currentSpaceID] {
            return tree
        }
        let tree = BSPTree()
        trees[currentSpaceID] = tree
        return tree
    }

    func insertWindow(_ window: TrackedWindow) {
        trackedWindows[window.windowID] = window
        currentTree().insert(windowID: window.windowID)
        applyLayout()
    }

    func removeWindow(windowID: WindowID) {
        trackedWindows.removeValue(forKey: windowID)
        for (_, tree) in trees {
            if tree.contains(windowID: windowID) {
                tree.remove(windowID: windowID)
                break
            }
        }
        applyLayout()
    }

    /// Find a tracked window ID belonging to the given pid whose AX element is stale.
    func staleWindowID(forPID pid: pid_t) -> WindowID? {
        for (wid, tracked) in trackedWindows where tracked.pid == pid {
            if tracked.element.windowID == nil {
                return wid
            }
        }
        return nil
    }

    /// Remove any tracked windows that are no longer valid (element is dead).
    func reconcile() {
        let staleIDs = trackedWindows.filter { (_, tracked) in
            tracked.element.windowID == nil
        }.map { $0.key }

        for windowID in staleIDs {
            removeWindow(windowID: windowID)
        }
    }

    func removeWindows(forPID pid: pid_t) {
        let windowIDs = trackedWindows.filter { $0.value.pid == pid }.map { $0.key }
        for windowID in windowIDs {
            removeWindow(windowID: windowID)
        }
    }

    func setFocused(windowID: WindowID) {
        currentTree().setFocused(windowID)
    }

    func isTracked(windowID: WindowID) -> Bool {
        trackedWindows[windowID] != nil
    }

    func trackedWindow(windowID: WindowID) -> TrackedWindow? {
        trackedWindows[windowID]
    }

    func lastLayoutFrame(for windowID: WindowID) -> CGRect? {
        lastLayoutMap[windowID]
    }

    func adjustSplitRatio(windowID: WindowID, actualFrame: CGRect) {
        currentTree().adjustSplitRatio(forWindow: windowID, actualFrame: actualFrame)
        applyLayout()
    }

    func retile() {
        applyLayout()
    }

    /// Find which tiled window contains the given point based on the last layout.
    func windowAt(point: CGPoint) -> WindowID? {
        for (windowID, frame) in lastLayoutMap {
            if frame.contains(point) {
                return windowID
            }
        }
        return nil
    }

    /// Move a window next to a target window by removing it from its current position
    /// and splitting the target's tile.
    func moveWindow(windowID: WindowID, toTarget target: WindowID, direction: SplitDirection, placeFirst: Bool) {
        let tree = currentTree()
        tree.remove(windowID: windowID)
        tree.insertNextTo(windowID: windowID, target: target, direction: direction, placeFirst: placeFirst)
        applyLayout()
    }

    /// Toggle a window between floating and tiled. Returns `true` if the window is now floating.
    @discardableResult
    func toggleFloating(windowID: WindowID) -> Bool {
        guard var tracked = trackedWindows[windowID] else { return false }

        if tracked.isFloating {
            // Re-tile: insert back into BSP tree
            tracked.isFloating = false
            trackedWindows[windowID] = tracked
            currentTree().insert(windowID: windowID)
            applyLayout()
            return false
        } else {
            // Float: remove from BSP tree, keep in trackedWindows
            tracked.isFloating = true
            trackedWindows[windowID] = tracked
            for (_, tree) in trees {
                if tree.contains(windowID: windowID) {
                    tree.remove(windowID: windowID)
                    break
                }
            }
            applyLayout()
            return true
        }
    }

    func rebuildCurrentSpace(windows: [TrackedWindow]) {
        // Collect previously floating window IDs
        let previouslyFloating = Set(trackedWindows.values.filter { $0.isFloating }.map { $0.windowID })

        let tiledWindows = windows.filter { !previouslyFloating.contains($0.windowID) }
        let newTiledIDs = Set(tiledWindows.map { $0.windowID })

        // If an existing tree has exactly the same tiled windows, reuse it to preserve split ratios
        if let existingTree = trees[currentSpaceID] {
            let existingIDs = Set(existingTree.calculateLayout(screenFrame: ScreenInfo.usableFrame()).map { $0.0 })
            if existingIDs == newTiledIDs && !newTiledIDs.isEmpty {
                // Just refresh element references
                for window in windows {
                    var w = window
                    w.isFloating = previouslyFloating.contains(window.windowID)
                    trackedWindows[window.windowID] = w
                }
                applyLayout()
                return
            }
        }

        let tree = BSPTree()
        trees[currentSpaceID] = tree

        trackedWindows = trackedWindows.filter { (wid, _) in
            !windows.contains { $0.windowID == wid }
        }
        for window in windows {
            var w = window
            w.isFloating = previouslyFloating.contains(window.windowID)
            trackedWindows[window.windowID] = w
            if !w.isFloating {
                tree.insert(windowID: window.windowID)
            }
        }
        applyLayout()
    }

    var focusedWindowID: WindowID? {
        currentTree().focusedWindowID
    }

    /// Find the nearest neighbor of a window in the given direction using last layout frames.
    func neighborOf(windowID: WindowID, direction: MoveDirection) -> WindowID? {
        guard let sourceFrame = lastLayoutMap[windowID] else { return nil }

        let sourceCenterX = sourceFrame.midX
        let sourceCenterY = sourceFrame.midY

        var bestID: WindowID?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for (candidateID, candidateFrame) in lastLayoutMap {
            guard candidateID != windowID else { continue }

            let candCenterX = candidateFrame.midX
            let candCenterY = candidateFrame.midY

            switch direction {
            case .left:
                guard candCenterX < sourceCenterX else { continue }
                // Must overlap vertically
                guard candidateFrame.maxY > sourceFrame.minY && candidateFrame.minY < sourceFrame.maxY else { continue }
                let dist = sourceCenterX - candCenterX
                if dist < bestDistance { bestDistance = dist; bestID = candidateID }

            case .right:
                guard candCenterX > sourceCenterX else { continue }
                guard candidateFrame.maxY > sourceFrame.minY && candidateFrame.minY < sourceFrame.maxY else { continue }
                let dist = candCenterX - sourceCenterX
                if dist < bestDistance { bestDistance = dist; bestID = candidateID }

            case .up:
                guard candCenterY < sourceCenterY else { continue }
                guard candidateFrame.maxX > sourceFrame.minX && candidateFrame.minX < sourceFrame.maxX else { continue }
                let dist = sourceCenterY - candCenterY
                if dist < bestDistance { bestDistance = dist; bestID = candidateID }

            case .down:
                guard candCenterY > sourceCenterY else { continue }
                guard candidateFrame.maxX > sourceFrame.minX && candidateFrame.minX < sourceFrame.maxX else { continue }
                let dist = candCenterY - sourceCenterY
                if dist < bestDistance { bestDistance = dist; bestID = candidateID }
            }
        }

        return bestID
    }

    /// Must only be called on the main thread. The isApplyingLayout flag suppresses
    /// AX callback re-entry during setFrame calls; suppressMovesUntil handles the
    /// asynchronous case where callbacks arrive after this method returns.
    private func applyLayout() {
        isApplyingLayout = true
        defer { isApplyingLayout = false }

        let tree = currentTree()
        let screenFrame = ScreenInfo.usableFrame()
        let layout = tree.calculateLayout(screenFrame: screenFrame)

        lastLayoutMap = Dictionary(layout, uniquingKeysWith: { _, last in last })

        for (windowID, frame) in layout {
            guard let window = trackedWindows[windowID] else { continue }
            window.element.setFrame(frame)
        }
    }
}
