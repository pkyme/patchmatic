# Sets Mode — Technical Notes

## Overview

Sets mode is for organizing patches into an ordered sequence — a "set list" for live performance or presentation. The canvas shows patches read-only; all editing of cables and controls is done in Patches mode.

---

## Left Panel

The left panel is split into two sections: the set list (top) and the patches-in-set list (bottom, visible when a set is selected).

### Set List

| Action | Access | Notes |
|--------|--------|-------|
| Select set | Click | Activates set and jumps to its first patch |
| New Set | Plus button in header, Sets menu (Cmd+N) | Auto-generated unique name; becomes active |
| Delete Set | Right-click → Delete | Removes the set only; patches are not deleted |
| Rename set | Double-click name | Inline text edit; uniqueness enforced |

### Patches in Set

Displayed below the set list when a set is selected. Shows the ordered patches belonging to the active set.

| Action | Access | Notes |
|--------|--------|-------|
| Navigate to patch | Click patch row | Loads that patch in the canvas |
| Reorder patches | Drag row | Drag to new position within the list |
| Remove from set | Right-click → Remove from Set | Removes from this set only; patch is not deleted |
| Add patch | "Add Patch" menu at bottom | Lists all patches not already in the set |

Each row shows a sequence number, the patch name, and an accent-colored speaker icon on the currently active patch.

---

## Canvas (Right Panel)

The canvas is a **read-only** view of the active patch. It uses the same rendering as Patches mode (see [Patches Mode](patches-mode.md)) with the following differences:

- All drag interactions are pan-only. Cables cannot be created or deleted. Controls cannot be adjusted. Pins cannot be moved.
- No editing context menus appear on right-click (canvas, cable, or module).
- No EditConfirmationToolbar.

The patch notes overlay is still visible (when Notes toggle is on) and can be clicked to open the notes sheet in read-only mode (shows a single Close button instead of Save/Cancel).

A navigation bar is fixed at the bottom of the canvas:

| Control | Keyboard shortcut | Action |
|---------|------------------|--------|
| ← (Previous) | Left Arrow / Cmd+← | Go to previous patch in set; disabled at start |
| N / Total — Patch Name | — | Current position and patch name |
| → (Next) | Right Arrow / Cmd+→ | Go to next patch in set; disabled at end |

Shows "No Set Selected" placeholder if no set is active. Shows "Empty Set" placeholder if the active set has no patches.

---

## Toolbar Buttons

The toolbar is the same as Patches mode (Labels, Groups, Numbers, Notes, Zoom In, Zoom Out, Frame Rack, Image Opacity). See [Patches Mode — Toolbar Buttons](patches-mode.md#toolbar-buttons). All toggles are functional in read-only mode.

---

## Menu Items (Sets Menu)

All items disabled when not in Sets mode.

| Item | Shortcut | Condition |
|------|----------|-----------|
| New Set | Cmd+N | — |
| Rename Set | Cmd+R | Active set exists |
| Delete Set | — | Active set exists |
| Next Patch | Cmd+→ | — |
| Previous Patch | Cmd+← | — |

---

## View Menu Items (Sets Mode)

All view toggle items (Show Labels, Show Groups, Show Patch Numbers, Show Patch Notes) and zoom items (Zoom In, Zoom Out, Frame) are **disabled** in Sets mode from the View menu. Use the toolbar buttons instead.

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| Cmd+4 | Switch to Sets mode |
| Cmd+N | New Set |
| Cmd+R | Rename Set |
| Left Arrow / Cmd+← | Previous patch in set |
| Right Arrow / Cmd+→ | Next patch in set |

---

## Set Properties

| Property | Description |
|----------|-------------|
| Name | Free text; auto-uniquified |
| Patch IDs | Ordered list of patch references; patches deleted from the document are silently skipped |
