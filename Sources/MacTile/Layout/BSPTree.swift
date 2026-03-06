import Foundation

/// Manages a binary space partitioning tree of windows for a single space.
/// Provides insert, remove, reorder, and layout calculation operations.
/// Splits are alternated by depth and gaps are applied between tiles.
final class BSPTree {
    private(set) var root: BSPNode?
    private(set) var focusedWindowID: WindowID?
    var gap: CGFloat {
        let value = UserDefaults.standard.double(forKey: "GapSize")
        return value == 0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains("GapSize") ? 8.0 : value
    }

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

        root.calculateFrames(container: screenFrame, gap: gap)
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

    /// Returns sibling info if windowID and target share the same parent.
    func areSiblings(windowID: WindowID, target: WindowID) -> (parent: BSPNode, windowIsLeft: Bool)? {
        guard let root = root else { return nil }
        guard let nodeA = root.find(windowID: windowID),
              let nodeB = root.find(windowID: target) else { return nil }
        guard let parentA = nodeA.parent, parentA === nodeB.parent else { return nil }
        let windowIsLeft = parentA.leftChild === nodeA
        return (parentA, windowIsLeft)
    }

    /// Walk up from the leaf to the root, adjusting each ancestor's split ratio
    /// whose boundary corresponds to an edge that actually moved.
    ///
    ///         Root (H split)
    ///        /          \
    ///     N1 (V split)   N2 (V split)
    ///    /     \        /     \
    /// Win A   Win B   Win C   Win D
    ///
    /// Each ancestor controls one edge of the descendant's region:
    /// - H split, left child  → controls **right** edge
    /// - H split, right child → controls **left** edge
    /// - V split, left child  → controls **bottom** edge
    /// - V split, right child → controls **top** edge
    func adjustSplitRatio(forWindow windowID: WindowID, actualFrame: CGRect, oldFrame: CGRect) {
        guard let root = root else { return }
        guard let leaf = root.find(windowID: windowID) else { return }

        let halfGap = gap / 2
        let threshold: CGFloat = 2.0
        var current: BSPNode = leaf

        while let parent = current.parent {
            guard let direction = parent.splitDirection else { break }
            let container = parent.frame
            let isLeft = parent.leftChild === current

            switch direction {
            case .horizontal:
                if isLeft {
                    if abs(actualFrame.maxX - oldFrame.maxX) > threshold {
                        let ratio = (actualFrame.maxX + halfGap - container.origin.x) / container.width
                        parent.splitRatio = min(0.9, max(0.1, ratio))
                    }
                } else {
                    if abs(actualFrame.minX - oldFrame.minX) > threshold {
                        let ratio = (actualFrame.minX - halfGap - container.origin.x) / container.width
                        parent.splitRatio = min(0.9, max(0.1, ratio))
                    }
                }
            case .vertical:
                if isLeft {
                    if abs(actualFrame.maxY - oldFrame.maxY) > threshold {
                        let ratio = (actualFrame.maxY + halfGap - container.origin.y) / container.height
                        parent.splitRatio = min(0.9, max(0.1, ratio))
                    }
                } else {
                    if abs(actualFrame.minY - oldFrame.minY) > threshold {
                        let ratio = (actualFrame.minY - halfGap - container.origin.y) / container.height
                        parent.splitRatio = min(0.9, max(0.1, ratio))
                    }
                }
            }

            current = parent
        }
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
