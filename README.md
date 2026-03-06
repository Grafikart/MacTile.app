# MacTile

> [!IMPORTANT]
> This app was vibe coded using my specific needs and to explore how far I can go without prior knowledge.

An automatic tiling window manager for macOS. MacTile arranges your windows using a binary space partitioning (BSP) layout — every time a window is opened, the focused tile splits to make room, and closing a window causes the remaining tiles to expand to fill the gap.

MacTile runs as a menu bar app with no Dock icon. It requires macOS 13+ and Accessibility permissions.

## Features

- **Automatic BSP tiling** — windows are arranged in a binary tree of horizontal and vertical splits, with configurable gaps between tiles.
- **Per-space layouts** — each macOS Space (virtual desktop) has its own independent BSP tree, so switching spaces restores that space's layout.
- **Drag-and-drop rearrangement** — drag a window and drop it onto another tile to swap positions or change the split direction.
- **Split ratio adjustment** — resize a tiled window's edge to adjust the split ratio between it and its neighbor.
- **Keyboard shortcuts** — move or focus windows in any direction (left/right/up/down) using configurable hotkeys.
- **Floating windows** — toggle any window out of the tiling layout so it can move and resize freely, then toggle it back in.
- **Menu bar controls** — shows the current Space number; provides quick access to enable/disable tiling, re-tile, configure shortcuts, and quit.

## How it works

### Architecture

```
main.swift
  └─ AppDelegate
       ├─ StatusBarController    (menu bar icon + dropdown menu)
       └─ WindowManager          (central coordinator)
            ├─ WindowObserver    (AX event listener)
            ├─ TilingEngine      (BSP trees + layout math)
            └─ ShortcutManager   (global hotkey dispatch)
```

### Window observation

MacTile uses the macOS Accessibility API (`AXObserver`) to watch every running application for window events: creation, destruction, focus changes, minimize/deminimize, move, and resize. The `WindowObserver` registers per-app observers and forwards events to the `WindowManager`.

### BSP layout

Each Space has a `BSPTree` made of `BSPNode`s. Leaf nodes hold a window ID; internal nodes define a split direction (horizontal or vertical) and a ratio. When the layout is applied, the tree recursively divides the usable screen area into non-overlapping rectangles with gaps between them.

- **Insert**: new windows split the currently focused tile, alternating direction by depth.
- **Remove**: when a window closes, its leaf is removed and the sibling promotes up to fill the space.
- **Rearrange**: dragging a window onto another tile removes it from its old position and splits the target tile.
- **Resize**: dragging a window edge adjusts the parent node's split ratio.

### Floating

Pressing the float toggle shortcut (default: `Ctrl+F`) removes the focused window from the BSP tree without untracking it. The remaining windows retile to fill the gap. The floating window can be moved and resized freely — move/resize events are ignored for it. Pressing the shortcut again re-inserts it into the tree.

### Transient window filtering

MacTile automatically excludes transient and non-standard windows from tiling. In addition to filtering by subrole (dialogs, floating windows, panels, sheets, and popovers), it checks each window's **layer** via `CGWindowListCopyWindowInfo`. Normal application windows live on layer 0; transient overlays like Quick Look previews, color pickers, and system panels appear on higher layers. Any window with a layer above 0 is excluded from tiling.

### Space detection

MacTile uses private CoreGraphics APIs (`CGSGetActiveSpace`, `CGSCopyManagedDisplaySpaces`) to detect the current Space ID and its Mission Control index. Each Space gets its own BSP tree so layouts are independent.

### Keyboard shortcuts

The `ShortcutManager` listens for global and local key events. It matches pressed key+modifier combinations against stored shortcuts for three categories:

| Category         | Default                | Action                                   |
|------------------|------------------------|------------------------------------------|
| Move window      | `Ctrl+Shift+Arrows`   | Swap the focused window with its neighbor |
| Focus window     | `Ctrl+Arrows`         | Move focus to the neighboring tile        |
| Toggle float     | `Ctrl+F`              | Float/unfloat the focused window          |

All shortcuts are configurable via the Shortcuts panel (menu bar > Shortcuts...) and persisted in UserDefaults.

## Building

```bash
swift build
```

## Running

```bash
swift run MacTile
```

On first launch, macOS will prompt for Accessibility permissions. Grant access in System Settings > Privacy & Security > Accessibility, then the app will start tiling automatically.

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permissions
- Swift 5.9+
