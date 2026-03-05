import Foundation

enum SplitDirection {
    case horizontal  // split left/right
    case vertical    // split top/bottom
}

/// A single node in the binary space partitioning (BSP) tree.
/// Leaf nodes hold a window ID; internal nodes define a horizontal or vertical split
/// with an adjustable ratio and two children. Handles frame calculation and tree mutation.
final class BSPNode {
    weak var parent: BSPNode?
    var frame: CGRect = .zero

    // Leaf properties
    var windowID: WindowID?

    // Internal node properties
    var splitDirection: SplitDirection?
    var splitRatio: CGFloat = 0.5
    var leftChild: BSPNode?
    var rightChild: BSPNode?

    var isLeaf: Bool { windowID != nil }

    init(windowID: WindowID) {
        self.windowID = windowID
    }

    init(direction: SplitDirection, left: BSPNode, right: BSPNode) {
        self.splitDirection = direction
        self.leftChild = left
        self.rightChild = right
        left.parent = self
        right.parent = self
    }

    /// Split this leaf into two: existing window goes left, new window goes right.
    func split(newWindowID: WindowID, depth: Int) {
        guard isLeaf, let existingID = windowID else { return }

        let direction: SplitDirection = (depth % 2 == 0) ? .horizontal : .vertical

        let leftNode = BSPNode(windowID: existingID)
        let rightNode = BSPNode(windowID: newWindowID)

        self.windowID = nil
        self.splitDirection = direction
        self.splitRatio = 0.5
        self.leftChild = leftNode
        self.rightChild = rightNode
        leftNode.parent = self
        rightNode.parent = self
    }

    /// Remove this leaf and promote its sibling to take the parent's place.
    func remove() {
        guard let parent = parent else { return }

        let sibling: BSPNode?
        if parent.leftChild === self {
            sibling = parent.rightChild
        } else {
            sibling = parent.leftChild
        }

        guard let sibling = sibling else { return }

        // Copy sibling's data into parent
        parent.windowID = sibling.windowID
        parent.splitDirection = sibling.splitDirection
        parent.splitRatio = sibling.splitRatio
        parent.leftChild = sibling.leftChild
        parent.rightChild = sibling.rightChild

        parent.leftChild?.parent = parent
        parent.rightChild?.parent = parent
    }

    /// Calculate frames for all nodes given the container rect and gap size.
    func calculateFrames(container: CGRect, gap: CGFloat, depth: Int = 0) {
        frame = container

        guard !isLeaf else { return }
        guard let direction = splitDirection,
              let left = leftChild,
              let right = rightChild else { return }

        let halfGap = gap / 2

        switch direction {
        case .horizontal:
            let splitX = container.origin.x + container.width * splitRatio
            left.calculateFrames(
                container: CGRect(
                    x: container.origin.x,
                    y: container.origin.y,
                    width: splitX - container.origin.x - halfGap,
                    height: container.height
                ),
                gap: gap,
                depth: depth + 1
            )
            right.calculateFrames(
                container: CGRect(
                    x: splitX + halfGap,
                    y: container.origin.y,
                    width: container.maxX - splitX - halfGap,
                    height: container.height
                ),
                gap: gap,
                depth: depth + 1
            )

        case .vertical:
            let splitY = container.origin.y + container.height * splitRatio
            left.calculateFrames(
                container: CGRect(
                    x: container.origin.x,
                    y: container.origin.y,
                    width: container.width,
                    height: splitY - container.origin.y - halfGap
                ),
                gap: gap,
                depth: depth + 1
            )
            right.calculateFrames(
                container: CGRect(
                    x: container.origin.x,
                    y: splitY + halfGap,
                    width: container.width,
                    height: container.maxY - splitY - halfGap
                ),
                gap: gap,
                depth: depth + 1
            )
        }
    }

    /// Collect all leaf window frames.
    func collectLeafFrames() -> [(WindowID, CGRect)] {
        if isLeaf, let wid = windowID {
            return [(wid, frame)]
        }
        var result: [(WindowID, CGRect)] = []
        if let left = leftChild {
            result.append(contentsOf: left.collectLeafFrames())
        }
        if let right = rightChild {
            result.append(contentsOf: right.collectLeafFrames())
        }
        return result
    }

    /// Find the leaf node containing a given window ID.
    func find(windowID: WindowID) -> BSPNode? {
        if isLeaf && self.windowID == windowID {
            return self
        }
        return leftChild?.find(windowID: windowID) ?? rightChild?.find(windowID: windowID)
    }

    /// Depth of this node in the tree (distance from root).
    var depth: Int {
        var d = 0
        var node = parent
        while node != nil {
            d += 1
            node = node?.parent
        }
        return d
    }
}
