import Foundation
import CGSPrivate

/// Detects the current macOS Space (virtual desktop) using private CGS APIs.
/// Returns both a 1-based Mission Control index (for display) and a raw space ID
/// (used as the per-space BSP tree key).
enum SpaceDetector {
    /// Returns the 1-based index of the currently active Space,
    /// matching Mission Control order (Bureau 1, Bureau 2, ...).
    static func currentSpaceIndex() -> Int {
        let conn = CGSMainConnectionID()
        let activeSpace = CGSGetActiveSpace(conn)

        let displays = CGSCopyManagedDisplaySpaces(conn).takeRetainedValue() as [AnyObject]

        // Walk each display's spaces in Mission Control order
        var desktopIndex = 0
        for display in displays {
            guard let displayDict = display as? [String: AnyObject],
                  let spaces = displayDict["Spaces"] as? [[String: AnyObject]] else { continue }

            for space in spaces {
                let spaceType = space["type"] as? Int ?? -1
                // type 0 = regular desktop, skip fullscreen (type 4)
                guard spaceType == 0 else { continue }
                desktopIndex += 1

                if let spaceID = space["id64"] as? UInt64, spaceID == activeSpace {
                    return desktopIndex
                }
                // Fallback: "ManagedSpaceID" is sometimes used
                if let spaceID = space["ManagedSpaceID"] as? UInt64, spaceID == activeSpace {
                    return desktopIndex
                }
            }
        }

        return 1
    }

    /// Returns the raw space ID for use as a tree key.
    static func currentSpaceID() -> Int {
        let conn = CGSMainConnectionID()
        return Int(CGSGetActiveSpace(conn))
    }

    /// Returns the raw space ID for the desktop at the given 1-based index.
    static func spaceID(forIndex targetIndex: Int) -> Int? {
        let conn = CGSMainConnectionID()
        let displays = CGSCopyManagedDisplaySpaces(conn).takeRetainedValue() as [AnyObject]

        var desktopIndex = 0
        for display in displays {
            guard let displayDict = display as? [String: AnyObject],
                  let spaces = displayDict["Spaces"] as? [[String: AnyObject]] else { continue }

            for space in spaces {
                let spaceType = space["type"] as? Int ?? -1
                guard spaceType == 0 else { continue }
                desktopIndex += 1

                if desktopIndex == targetIndex {
                    if let sid = space["id64"] as? UInt64 {
                        return Int(sid)
                    }
                    if let sid = space["ManagedSpaceID"] as? UInt64 {
                        return Int(sid)
                    }
                }
            }
        }

        return nil
    }
}
