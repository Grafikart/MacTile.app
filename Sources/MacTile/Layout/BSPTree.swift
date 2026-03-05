import Foundation

/// Manages a binary space partitioning tree of windows for a single space.
/// Provides insert, remove, reorder, and layout calculation operations.
/// Splits are alternated by depth and gaps are applied between tiles.
final class BSPTree {
    private(set) var root: BSPNode?
    private(set) var focusedWindowID: WindowID?
    let gap: CGFloat = 8.0

    var isEmpty: Bool { root == nil }

    func setFocused(_ windowID: WindowID) {
        guard root?.find(windowID: windowID) != nil else { return }
        focusedWindowID = windowID
    }

    func insert(windowID: WindowID) {
        guard let root = root else {
            self.root = BSPNode(windowID: windowID)
            return
        }

        // Find the focused leaf to split, or use the last leaf
        let targetNode: BSPNode
        if let fid = focusedWindowID, let focused = root.find(windowID: fid) {
            targetNode = focused
        } else {
            targetNode = lastLeaf(of: root) ?? root
        }

        targetNode.split(newWindowID: windowID, depth: targetNode.depth)
        focusedWindowID = windowID
    }

    func remove(windowID: WindowID) {
        guard let root = root else { return }

        guard let node = root.find(windowID: windowID) else { return }

        if node === root {
            self.root = nil
            focusedWindowID = nil
            return
        }

        node.remove()

        if focusedWindowID == windowID {
            focusedWindowID = nil
        }
    }

    func contains(windowID: WindowID) -> Bool {
        root?.find(windowID: windowID) != nil
    }

    func calculateLayout(screenFrame: CGRect) -> [(WindowID, CGRect)] {
        guard let root = root else { return [] }

        // Single window gets the full screen, no gaps
        if root.isLeaf {
            root.calculateFrames(container: screenFrame, gap: 0)
            return root.collectLeafFrames()
        }

        let insetFrame = CGRect(
            x: screenFrame.origin.x + gap,
            y: screenFrame.origin.y + gap,
            width: screenFrame.width - gap * 2,
            height: screenFrame.height - gap * 2
        )

        root.calculateFrames(container: insetFrame, gap: gap)
        return root.collectLeafFrames()
    }

    /// Insert a window next to a target window by splitting the target's leaf.
    func insertNextTo(windowID: WindowID, target: WindowID, direction: SplitDirection, placeFirst: Bool) {
        guard let root = root else { return }
        guard let targetNode = root.find(windowID: target) else { return }
        guard targetNode.isLeaf, let existingID = targetNode.windowID else { return }

        let existingNode = BSPNode(windowID: existingID)
        let newNode = BSPNode(windowID: windowID)

        let left = placeFirst ? newNode : existingNode
        let right = placeFirst ? existingNode : newNode

        // Replace the target leaf with an internal node
        targetNode.windowID = nil
        targetNode.splitDirection = direction
        targetNode.splitRatio = 0.5
        targetNode.leftChild = left
        targetNode.rightChild = right
        left.parent = targetNode
        right.parent = targetNode

        focusedWindowID = windowID
    }

    func adjustSplitRatio(forWindow windowID: WindowID, actualFrame: CGRect) {
        guard let root = root else { return }
        guard let leaf = root.find(windowID: windowID) else { return }
        guard let parent = leaf.parent else { return }
        guard let direction = parent.splitDirection else { return }

        let container = parent.frame
        let halfGap = gap / 2
        let isLeft = parent.leftChild === leaf

        let ratio: CGFloat
        switch direction {
        case .horizontal:
            if isLeft {
                ratio = (actualFrame.maxX + halfGap - container.origin.x) / container.width
            } else {
                ratio = (actualFrame.minX - halfGap - container.origin.x) / container.width
            }
        case .vertical:
            if isLeft {
                ratio = (actualFrame.maxY + halfGap - container.origin.y) / container.height
            } else {
                ratio = (actualFrame.minY - halfGap - container.origin.y) / container.height
            }
        }

        parent.splitRatio = min(0.9, max(0.1, ratio))
    }

    private func lastLeaf(of node: BSPNode) -> BSPNode? {
        if node.isLeaf { return node }
        if let right = node.rightChild {
            return lastLeaf(of: right)
        }
        if let left = node.leftChild {
            return lastLeaf(of: left)
        }
        return nil
    }
}
