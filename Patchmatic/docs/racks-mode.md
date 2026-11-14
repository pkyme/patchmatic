# Racks Mode — Technical Notes

## Overview

Racks mode is where module definitions are assembled into physical rack cases. The interface is split into a rack list on the left and a free-form canvas on the right. The canvas shows all cases belonging to the selected rack.

---

## Rack List (Left Panel)

### Display

- Sidebar list of all racks in the document.
- Single selection — the selected rack loads in the canvas.

### Actions

| Action | Access | Notes |
|--------|--------|-------|
| Select rack | Click | Triggers confirmation if current rack has unsaved edits |
| New Rack | Plus button in header, Racks menu (Cmd+N) | Auto-generated unique name |
| Duplicate Rack | Right-click → Duplicate, Racks menu (Cmd+D) | Full copy, new ID, becomes active |
| Delete Rack | Right-click → Delete | Removes rack and all its patches |
| Rename rack | Double-click name | Inline text edit; uniqueness enforced (appends numbers on conflict) |

---

## Rack Canvas (Right Panel)

### Display

- Infinite canvas with a dashed grid background (80pt spacing).
- Cases are free-form positioned anywhere on the canvas.
- Each case contains one or more rows; each row contains placed modules.
- Zoom range: 0.25x–5.0x. Pan offset and zoom are persisted across sessions.

### Canvas Navigation

| Interaction | Behaviour |
|-------------|-----------|
| Scroll wheel | Zoom toward cursor |
| Pinch gesture | Zoom toward cursor |
| Option+Drag | Pan canvas |
| Drag on empty space | Pan canvas |
| Shift+Drag on empty space | Marquee selection |

**Frame to Fit** (Cmd+0 or toolbar button): calculates bounding box of all cases and fits them to the viewport with 40pt padding. Max zoom 2x. Animated.

---

## Case Management

### Case Display

Each case has a header (visible in Racks mode only) showing the case name, HP width, and a gear icon for row management.

### Case Actions

| Action | Access | Notes |
|--------|--------|-------|
| Add Case | Empty canvas context menu → New Case, toolbar button, Racks menu (Cmd+Shift+C) | Positioned below existing cases |
| Rename Case | Click case name in header | Opens popover with text field |
| Set HP Width | Click HP value in header | Opens popover; numeric input; applies to all rows in the case |
| Add 3U Row | Case gear menu or context menu → Add 3U Row | Appended to the case's row list |
| Add 1U Row | Case gear menu or context menu → Add 1U Row | Appended to the case's row list |
| Remove Row | Case gear menu or context menu → Remove Row → Row N | Removes row and all modules in it |
| Move Case | Drag case header or selected case body | Free-form positioning; snaps to 8HP guides |
| Multi-case drag | Select multiple cases, drag one | All selected cases move together |
| Delete Case | Select case, Delete key | Removes case, all its modules, and related cables/knob values |

### Case Properties

| Property | Description |
|----------|-------------|
| Name | Free text; no uniqueness enforcement |
| HP Width | Applies to all rows; determines maximum module capacity |
| Rows | Ordered list of 3U and 1U rows (can mix formats) |
| Position | Free-form X/Y on canvas |

---

## Row Management

- Rows are stacked vertically within a case.
- Each row has a format: **3U** (standard Eurorack) or **1U**.
- 3U modules can only be placed in 3U rows; 1U modules only in 1U rows.
- Default new cases start with two rows.
- Rows are shown with a dashed border outline in Racks mode.

---

## Module Placement and Manipulation

### Module Library Strip

- A horizontal strip at the bottom of the canvas shows all modules from the library.
- Height is adjustable by dragging the divider above the strip (80–300pt, persisted).
- Drag a module thumbnail from the strip onto a row to place it.

### Placement Rules

- Module format must match row format (3U → 3U row, 1U → 1U row).
- Module must fit within the available HP space in the row.
- A drop indicator (dashed accent outline) shows the target position while dragging.

### Module Selection

| Action | Behaviour |
|--------|-----------|
| Click module | Select single module |
| Shift+Click | Toggle in/out of selection |
| Shift+Drag on empty space | Marquee selection |
| Cmd+A | Select all modules in rack |

### Module Manipulation

| Action | Access | Notes |
|--------|--------|-------|
| Move module | Drag | Snaps to HP grid; within the same case only |
| Multi-module move | Select multiple, drag one | All selected move together; same case only |
| Nudge left/right | Arrow keys | 1 HP per keypress |
| Remove module | Delete key or right-click → Delete | Also removes all cables connected to it and its knob values |
| Duplicate | Cmd+D | Duplicates selected module(s) if space allows |

---

## Edit Mode

Any modification (placing/removing modules, moving cases, adding/removing rows) enters edit mode.

- A floating **EditConfirmationToolbar** appears at the bottom of the canvas with:
  - **Save Changes**: Commits edits. If the rack has patches, shows "Rack In Use" confirmation first.
  - **Discard Edits**: Reverts all changes to the state before editing began.
- Switching to a different rack while editing triggers an alert: Save Changes, Discard Edits, or Cancel.
- All edits support Undo/Redo.

---

## Context Menus

### Empty Canvas
- **New Case** (Racks mode)

### Case Header (gear icon or right-click)
- Add 3U Row
- Add 1U Row
- Remove Row > Row N (3U/1U) — one entry per row

### Module (right-click, Racks mode)
- Delete

---

## Toolbar Buttons

| Icon | Tooltip | Action |
|------|---------|--------|
| shippingbox | New Case | Adds a new case to the active rack |
| tag | Show Labels (toggle) | Toggles control label visibility globally |
| plus.magnifyingglass | Zoom In | 1.25x zoom |
| minus.magnifyingglass | Zoom Out | 1/1.25x zoom |
| 1.magnifyingglass | Frame Rack | Fit all cases to viewport |

---

## Menu Items (Racks Menu)

All items disabled when not in Racks mode.

| Item | Shortcut | Condition |
|------|----------|-----------|
| New Rack | Cmd+N | — |
| Rename Rack | Cmd+R | Rack exists |
| Duplicate Rack | Cmd+D | Rack exists |
| Delete Rack | — | Rack exists |
| New Case | Cmd+Shift+C | — |

## View Menu Items (Racks Mode)

| Item | Shortcut | Behaviour |
|------|----------|-----------|
| Zoom In | Cmd+= | Zoom canvas in |
| Zoom Out | Cmd+- | Zoom canvas out |
| Frame | Cmd+0 | Fit all cases to viewport |
| Show Labels | Cmd+Shift+L | Enabled: toggles control label visibility |
| Show Groups | — | Disabled |
| Show Patch Numbers | — | Disabled |
| Show Patch Notes | — | Disabled |
| Show Grid | — | Disabled |
| Show Detections | — | Disabled |
| Hide Controls | — | Disabled |

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| Cmd+2 | Switch to Racks mode |
| Cmd+N | New Rack |
| Cmd+R | Rename Rack |
| Cmd+D | Duplicate Rack (or selected modules) |
| Cmd+Shift+C | New Case |
| Cmd+A | Select all modules |
| Delete | Remove selected modules/cases |
| Left/Right Arrow | Nudge selected module(s) ±1 HP |
| Cmd+= | Zoom In |
| Cmd+- | Zoom Out |
| Cmd+0 | Frame to fit |
| Cmd+Shift+L | Toggle Labels |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |

---

## Row Size Reference

| Format | Physical Height | Use |
|--------|----------------|-----|
| 3U | 128.5mm | Standard Eurorack |
| 1U | 39.65mm | 1U utility format |

Modules can only be placed in rows matching their format. HP width determines how many modules fit side-by-side.
