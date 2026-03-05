# MacTile

An app that apply tiling on windows automaticaly with a Dwindle layout similar to Hyprland.

## Features

### Topbar indicator

An icon in the topbar display the number of the current space visible on the screen. Clicking on this number allow access to different actions

- Retile (to recalculate the layout for the current space)
- Shortcuts (access to a panel to configure shortcuts)
- Quit the app

### Shortcuts

A panel allow the user to set keyboard shortcuts for different actions.

- Shortcuts to move the current focused window to a specific space (one shortcuts for space from 1 to 8). If the space does not exist it will be created, and the monitor will display the target space with the moved window focused
- Shortcuts to move the current focused window to the left / right / top / bottom. If the window is already on the side then it does nothing. Otherwise it split the window it intersect and it's resized accordingly

### Window moving

When a video is moved and dropped somewhere the window it intersect should be split in two and the space it left should be reallocated. Use the cursor position to detect which window it intersect instead of the window frame.

### Window resizing

When resizing a window (when the resize is ended) the surrounding windows should be shrinked to avoid overlap or grow to take up the free space.

## Layout

The layout rules are inspired by Hyprland but here is the main rules

- When a new window is open, it **should split the current focused window in 2**
- The direction of the split depend of the aspect ratio of the current focused window. **Always** split using the largest dimension.
- When a space is freed the smallest window around take the freed space.

### Floating window

Floating window (preview, tooltips, popup, file picker...) should not be tiled and retain their original position.
