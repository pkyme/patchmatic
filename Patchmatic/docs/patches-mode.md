# Patches Mode — Technical Notes

## Overview

Patches mode is where cable connections and control settings are created and edited for a given rack layout. The interface is split into a patch list on the left and a canvas on the right. The canvas shows the active rack with all modules, cables, and overlays for the selected patch.

---

## Patch List (Left Panel)

### Display

- Sidebar list of all patches in the document.
- Each entry shows the patch name.
- Single selection — the selected patch loads in the canvas.

### Actions

| Action | Access | Notes |
|--------|--------|-------|
| Select patch | Click | Loads patch in canvas |
| New Patch | Plus/dropdown button in header, Patches menu | Submenu lists all racks; click rack name to create patch for that rack; auto-generated unique name |
| Duplicate Patch | Right-click → Duplicate, Patches menu (Cmd+D) | Full copy including cables, knob values, screen images, module notes, groups, patch notes, and audio |
| Delete Patch | Right-click → Delete | Removes patch; associated screen images and audio files deleted |
| Rename patch | Double-click name | Inline text edit; uniqueness enforced |

---

## Patch Canvas (Right Panel)

### Display

- Shows the rack for the active patch with all modules, knob values, and cables.
- No case headers or grid background (differs from Racks mode).
- Module library strip is not visible in Patches mode.
- Patch point connection indicators (colored circles) show which patch points are connected.
- Shows "No Patch Selected" placeholder if no patch is active.

### Canvas Navigation

| Interaction | Behaviour |
|-------------|-----------|
| Scroll wheel | Zoom toward cursor |
| Pinch gesture | Zoom toward cursor |
| Drag on empty space | Pan canvas |

Zoom range: 0.25x–5.0x. Pan offset and zoom are persisted across sessions.

**Frame to Fit** (Cmd+0 or toolbar button): fits all cases to the viewport. Animated.

---

## Control Interaction

### Knobs

- Drag vertically to adjust value (up = increase, down = decrease).
- 150 pixels of vertical travel covers the full 0–1 range.
- Values are stored per patch.
- Entire drag operation records as a single undo entry.

### Sliders

- Drag along the slider axis to adjust value.
- Same undo grouping as knobs.

### Toggle Switches and Buttons

- Click to advance to the next state.
- Cycles through all named states (minimum 2).

### Screen Controls

A hover toolbar appears over screen controls:

| Button | Action |
|--------|--------|
| + (plus) | Add image; opens crop sheet |
| ← / → arrows | Cycle through multiple images (if >1) |
| Magnifier | Zoom/magnify the current image |
| ✕ | Delete the current image |

Images are cropped to match the control's aspect ratio before saving.

---

## Cable Patching

### Creating Cables

- Drag from any patch point to another patch point.
- A preview cable is shown during drag.
- Color is auto-assigned from the palette in round-robin order.
- Cable is created on release over a valid target patch point.

### Selecting Cables

| Action | Behaviour |
|--------|-----------|
| Right-click cable | Selects cable and shows context menu |
| Shift+right-click cable | Adds cable to selection |
| Right-click patch point | Selects all cables connected to that patch point |
| Shift+right-click patch point | Adds those cables to the selection |

### Deleting Cables

- Select cables, then right-click → **Delete Selected Cables (n)**.
- Or: Delete key while cables are selected.
- Or: Canvas context menu → **Delete Cable** submenu (lists all cables by short ID).

### Coloring Cables

- Right-click selected cable(s) → **Change Color** → color grid (24 colors).
- Color applies to all selected cables.
- Cables use separate color palettes for light and dark mode.

### Cable Appearance

- Line weight: ~2.5pt (slightly wider when hovered).
- Physics-based routing: cables hang naturally under simulated gravity.
- Selected cables show a 6pt accent-color outline behind the cable.
- Colored connection circles render at each patch point endpoint.

---

## Cable Pins

Cable pins are intermediate waypoints that redirect cable routing.

### Creating Pins

- Right-click a single selected cable → **Add Cable Pin**: inserts pin at the click location.
- Cmd+Click directly on a cable: inserts pin at the click location without requiring the context menu.

### Pin Properties

| Property | Description |
|----------|-------------|
| Position | World coordinates; if dropped on a case, stored as offset from case origin and moves with it |
| Sort index | Ordered position along the cable (0 = first pin after source) |

### Pin Appearance

- Small circles (4pt radius) colored to match the cable.
- White semi-transparent ring border.
- Selected pin shows a larger accent-color circle (6pt radius).
- Pins visible on hovered cables.

### Moving Pins

- Drag pin to reposition.
- Entire drag is a single undo entry.
- Dropping over a case anchors the pin to that case.

### Deleting Pins

- Right-click pin → **Delete Cable Pin**.
- Or: Delete key while pin is selected.

---

## Patch Notes

Patch notes are a free-form text field (and optional audio file) associated with the entire patch.

### Access

| Method | Action |
|--------|--------|
| Canvas context menu → Patch Notes… | Opens the notes sheet |
| Patches menu → Patch Notes… | Opens the notes sheet |
| Click the patch notes overlay on canvas | Opens the notes sheet |

### Notes Sheet

| Control | Action |
|---------|--------|
| Text editor (100–200pt height) | Edit patch notes text |
| Attach Audio Preview | Opens file importer for any audio file |
| Play / Stop | Plays or stops the attached audio |
| Remove | Deletes the attached audio file |
| Clear All | Clears both text and audio |
| Cancel | Closes without saving |
| Save | Saves changes |

### Patch Notes Overlay

When the **Notes** toolbar toggle is on, a small overlay appears in the top-left corner of the canvas showing the first line of patch notes. If audio is attached, an audio icon is shown. Clicking the overlay opens the notes sheet.

---

## Module Notes

### Patch Point Notes

Short text notes attached to a specific patch point on a module.

| Action | Access |
|--------|--------|
| Add Patch Point Note | Right-click while hovering over a patch point with no existing note |
| Edit Patch Point Note | Right-click while hovering over a patch point that already has a note |

Patch point notes appear as small note indicators on the module panel. Hovering shows the note text in a tooltip.

### General Module Notes

Free-form text notes positioned anywhere on a module panel.

| Action | Access |
|--------|--------|
| Add Note | Right-click module body (not hovering a patch point) → Add Note |
| Edit existing note | Right-click the note indicator on the module |

Notes are stored per patch and positioned using normalized coordinates.

---

## Groups

Groups are named overlays that color-highlight sets of modules for organizational purposes.

### Viewing Groups

- Toggle **Groups** in the toolbar to show/hide group overlays and the floating group list.
- The group list floats in the top-right corner of the canvas.
- Each group card shows the group name and notes.

### Creating Groups

- Right-click a module (with Groups enabled) → **New Group with [name]**.
- To include multiple modules: select them first (click + Shift+click), then right-click → **New Group with N Modules**.
- Opens a sheet with Name and Notes fields; click Create.

### Modifying Group Membership

| Action | Access |
|--------|--------|
| Add module(s) to group | Right-click module → Add to Group → [group name] |
| Remove module(s) from group | Right-click module → Remove from Group → [group name] |

### Hover Highlighting

- Hover over a group card → all modules in that group are highlighted; others fade to 25% opacity.
- Hover over a module → that module's groups are highlighted in the group list.

### Group Card Actions

| Action | Access |
|--------|--------|
| Focus group | Click group card | Animates canvas to fit all modules in the group |
| Rename group | Right-click → Rename… | Alert with text field |
| Edit group notes | Right-click → Edit Notes… | Sheet editor |
| Delete group | Right-click → Delete Group | Removes group; modules are not deleted |

### Module Selection (Groups Mode)

| Action | Behaviour |
|--------|-----------|
| Click module body | Selects single module |
| Shift+Click module body | Adds/removes from selection |
| Shift+Drag on empty space | Marquee selection |

---

## Context Menus

### Empty Canvas (Patches mode)

- **Delete Cable** → submenu listing all cables (short ID); click to delete
- **Patch Notes…** → opens patch notes sheet

### Cable

- **Change Color** → color grid (24 swatches)
- **Add Cable Pin** → inserts pin at click location (only when exactly one cable selected)
- **Delete Selected Cables (n)** → deletes all selected cables

### Cable Pin

- **Delete Cable Pin** → removes the pin

### Module (Patches mode, right-click)

*When hovering a patch point:*
- **Add Patch Point Note** (if no existing note)
- **Edit Patch Point Note** (if note exists)

*When hovering module body:*
- **Add Note**

*When Groups are enabled (appended to the above):*
- **New Group with [name / N Modules]**
- **Add to Group** → submenu of all groups (if groups exist)
- **Remove from Group** → submenu of groups containing the module (if applicable)

### Group Card

- **Rename…**
- **Edit Notes…**
- **Delete Group** (destructive)

---

## Toolbar Buttons

| Icon | Tooltip | Notes |
|------|---------|-------|
| tag | Labels (toggle) | Toggles control label visibility globally |
| rectangle.3.group | Groups (toggle) | Toggles group overlays; Patches mode only |
| 1.circle | Numbers (toggle) | Toggles patch point sequence numbers; Patches mode only |
| note.text | Notes (toggle) | Toggles patch notes overlay; Patches mode only |
| plus.magnifyingglass | Zoom In | 1.25x zoom |
| minus.magnifyingglass | Zoom Out | 1/1.25x zoom |
| 1.magnifyingglass | Frame Rack | Fit all cases to viewport |
| Slider (0–1) | Image Opacity | Controls background image transparency for all modules |

---

## Menu Items (Patches Menu)

All items disabled when not in Patches mode.

| Item | Shortcut | Condition |
|------|----------|-----------|
| New Patch | — | Submenu lists all racks; disabled if no racks exist |
| Rename Patch | Cmd+R | Active patch exists |
| Duplicate Patch | Cmd+D | Active patch exists |
| Delete Patch | — | Active patch exists |
| Patch Notes… | — | Active patch exists |

---

## View Menu Items (Patches Mode)

| Item | Shortcut | Behaviour |
|------|----------|-----------|
| Zoom In | Cmd+= | Zoom canvas in |
| Zoom Out | Cmd+- | Zoom canvas out |
| Frame | Cmd+0 | Fit all cases to viewport |
| Show Labels | Cmd+Shift+L | Enabled: toggles control label visibility |
| Show Groups | — | Enabled: toggles group overlays |
| Show Patch Numbers | — | Enabled: toggles patch point sequence numbers |
| Show Patch Notes | — | Enabled: toggles patch notes overlay |
| Show Grid | — | Disabled |
| Show Detections | — | Disabled |
| Hide Controls | — | Disabled |

---

## Printing

**Access:** File menu → Print Patch… (Cmd+P). Only functional in Patches mode (and Sets mode where the active patch is displayed).

The print output is rendered as a PDF and sent to the standard macOS print dialog. Page orientation is set automatically (landscape if the rack content is wider than it is tall, portrait otherwise). Content is scaled to fit the page with 18pt margins on all sides.

### Print Layout

| Element | Notes |
|---------|-------|
| Patch name | Shown as a bold title |
| Rack name | Shown below the patch name in secondary style |
| Patch notes | Shown below the rack name if the patch has notes |
| Rack canvas | All cases at 1× zoom, positioned as on the canvas |
| Modules | Rendered with current knob values; control labels always shown |
| Cables | Drawn at print resolution with no drop shadows |
| Patch point numbers | Included if the Numbers toggle is on |

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| Cmd+3 | Switch to Patches mode |
| Cmd+R | Rename Patch |
| Cmd+D | Duplicate Patch |
| Delete | Delete selected cables or selected pin |
| Cmd+Click cable | Insert cable pin at click location |
| Cmd+= | Zoom In |
| Cmd+- | Zoom Out |
| Cmd+0 | Frame to fit |
| Cmd+Shift+L | Toggle Labels |
| Cmd+P | Print Patch |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |

---

## Patch Properties

| Property | Description |
|----------|-------------|
| Name | Free text; auto-uniquified on creation |
| Rack ID | Reference to the rack this patch belongs to |
| Cables | List of cable connections (patch point to patch point) |
| Knob values | Per-control values (0–1 range) |
| Screen images | Image files displayed in screen controls |
| Module notes | Free-form text notes positioned on module panels |
| Patch point notes | Short notes attached to specific patch points |
| Module groups | Named groups of modules with color overlays |
| Patch notes | Free-form text for the whole patch |
| Audio preview | Optional audio file attached to the patch |
| Patch point order | Ordered list of connected patch points (for sequence numbering) |
