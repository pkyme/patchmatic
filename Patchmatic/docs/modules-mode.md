# Modules Mode — Technical Notes

## Overview

Modules mode is where module definitions are created and edited. The interface is split into two panels: a module library grid on the left and a module editor on the right.

---

## Module Library (Left Panel)

### Display

- Modules are shown in a responsive grid (adaptive columns, ~100pt each).
- Each cell shows a thumbnail (background image if set, otherwise a rendered preview of the panel with controls) at 120pt height.
- Module name appears below the thumbnail, single line, truncated with ellipsis.
- Thumbnails scale up slightly on hover.
- Selected modules have accent-colored background and border.

### Selection

| Action | Behaviour |
|--------|-----------|
| Click | Select single module |
| Cmd+Click | Toggle module in/out of selection |
| Shift+Click | Range select from last-clicked |
| Cmd+Shift+Click | Add range to existing selection |

When one module is selected it loads in the editor. Multi-select shows "N modules selected". No selection shows a placeholder.

### Context Menu

| Item | Condition | Action |
|------|-----------|--------|
| Add to [Case] > Row N | Rack exists with matching row format | Places the module in the selected row |
| Duplicate | Always | Creates a copy with " Copy" suffix |
| Delete | Always | Deletes the module; confirms if placed in a rack |

### Toolbar Buttons

| Icon | Tooltip | Action |
|------|---------|--------|
| camera | New Module from Image | Opens file picker (PNG/JPEG/TIFF/HEIC); creates module from image; prompts to auto-detect controls |
| plus | New Blank Module | Creates a blank module (3U, 8HP, no controls) |

### Other Actions

- **Drag-and-drop** an image file onto the library: same as "New Module from Image".
- **Delete key**: deletes all selected modules (with in-use confirmation if placed in racks).

---

## Module Editor (Right Panel)

The editor has a canvas toolbar strip, a zoomable canvas, and a property inspector form.

### Canvas Toolbar

#### Control Placement Toggles

Mutually exclusive; clicking an active toggle deactivates it. When active, clicking on the canvas places a new control of that type.

| Icon | Control Type |
|------|-------------|
| dial.medium | Knob |
| cable.connector | Patch Point |
| switch.2 | Toggle Switch |
| hand.tap | Button |
| slider.horizontal.3 | Slider |
| rectangle | Screen |

#### Image and Detection Tools

| Icon | Tooltip | Condition | Action |
|------|---------|-----------|--------|
| photo | Set Background Image | Always | Opens file picker to set or replace the background image |
| cpu | Analyse Background Image | Background image set | Runs ML detection to auto-detect controls and auto-size module |
| viewfinder (toggle) | Show Detections | Background image set | Shows/hides detection bounding boxes |
| eye.slash (toggle) | Hide Controls | Always | Hides control renderings on the canvas |

#### Editing Tools

| Icon | Tooltip | Condition | Action |
|------|---------|-----------|--------|
| trash | Delete Selected | Controls selected | Deletes all selected controls |
| square.dashed | Snap to Grid | Controls selected | Snaps selected controls to nearest grid intersection |

#### Layout Tools

| Icon | Tooltip | Condition | Action |
|------|---------|-----------|--------|
| align.horizontal.center | Centre Horizontally | 2+ controls | Aligns to average X position |
| align.vertical.center | Centre Vertically | 2+ controls | Aligns to average Y position |
| distribute.horizontal.center | Distribute Horizontally | 3+ controls | Even X spacing between outermost controls |
| distribute.vertical.center | Distribute Vertically | 3+ controls | Even Y spacing between outermost controls |

#### Grid Controls

| Control | Action |
|---------|--------|
| grid (toggle) | Show/hide grid overlay |
| Grid Divisions (stepper, 2–128) | Sets grid subdivision count; cell size = min(panel width, height) / divisions |

### Window Toolbar

| Control | Action |
|---------|--------|
| Zoom In (plus.magnifyingglass) | Zoom canvas by 1.25x (max 8x) |
| Zoom Out (minus.magnifyingglass) | Zoom canvas by 1/1.25x (min 1x) |
| Frame Module (1.magnifyingglass) | Reset zoom to 1x and centre the view |
| Image Opacity slider | Background image transparency (0–1) |

### Canvas Interactions

#### Zoom

- **Scroll wheel**: zoom toward cursor (1x–8x range).
- **Pinch gesture**: zoom toward cursor.
- **Toolbar/menu/shortcuts**: see relevant sections.

#### Pan

- **Option+Drag**: pan the canvas.
- **Click+drag on empty space** (no placement mode, beyond 4px threshold): pan.

#### Control Selection

| Action | Behaviour |
|--------|-----------|
| Click control | Select single control |
| Shift+Click control | Toggle in/out of selection |
| Repeated click on overlapping controls | Cycles through the stack |
| Shift+Drag on empty space | Marquee selection (adds to selection with Shift) |
| Click on empty space | Clears selection |
| Cmd+A | Select all controls |

#### Control Resizing

Screen and slider controls show a resize handle indicator on their selection highlight (bottom-right corner for screens, right edge for horizontal sliders, bottom edge for vertical sliders). Dragging this handle resizes the control live, keeping the opposite corner fixed. Resize is recorded as a single undo step.

| Control | Handle location | Axis |
|---------|----------------|------|
| Screen | Bottom-right corner | Width and height |
| Horizontal slider | Right edge center | Length |
| Vertical slider | Bottom edge center | Length |

Minimum sizes: screen 5pt per dimension, slider 10pt.

#### Control Dragging

- Drag a selected control to move all selected controls together.
- Drag an unselected control to select and move it.
- Shift+drag an unselected control to add it to the selection and drag all.
- Snap-to-grid is applied during drag if enabled.
- Drag is recorded as a single undo step.

#### Nudging

| Keys | Step Size |
|------|-----------|
| Arrow keys | 0.5 pt |
| Shift+Arrow keys | 5 pt |

#### Control Placement

When a placement mode is active, clicking empty canvas space places a new control at that position. Default label matches the control type. Grid snapping applies if enabled.

#### Detection Interaction

When detections are visible, clicking a detection bounding box highlights it. Detections are colour-coded by type: knob (blue), jack (green), toggle switch (orange), button (purple), slider (teal), other (grey). Each shows label and confidence percentage.

#### Other

- **Delete key**: deletes all selected controls.
- **Cmd+D**: duplicates selected controls, offset slightly to bottom-right.

### Property Inspector

#### Module Properties (always visible)

| Property | Control | Range/Values |
|----------|---------|-------------|
| Name | Text field | Free text, auto-uniquified |
| Format | Segmented picker | 3U, 1U. Changing rescales width HP proportionally |
| Width | Stepper | 2–999 HP |

#### Single Control Inspector (1 control selected)

| Property | Control | Condition |
|----------|---------|-----------|
| Label | Text field | Always |
| Kind | Dropdown | Always. Changing kind updates the label if it was still the default |
| Size | Segmented picker (S/M/L/XL) | Hidden for Patch Point |
| Width | Stepper (5–200 pt) | Screen only |
| Height | Stepper (5–200 pt) | Screen only |
| Length | Stepper (10–200 pt) | Slider only |
| Orientation | Segmented picker (V/H) | Toggle Switch and Slider |

**Control Label** sub-section:

| Property | Control | Condition |
|----------|---------|-----------|
| Position | Picker | Above, Below, Left, Right, Off |
| Size | Stepper (3–14 pt, step 0.5) | Position is not Off |
| Offset | Stepper (-20–20 pt, step 0.5) | Position is not Off |

**State Label** sub-section (Button and Toggle Switch only): same options as Control Label.

**States** sub-section (Button and Toggle Switch only):
- Editable list of named states (default: "Off", "On").
- Delete button per state (disabled at 2 states minimum).
- "+ Add State" button adds "State N+1".

#### Batch Inspector (2+ controls selected)

| Property | Control | Notes |
|----------|---------|-------|
| Label Prefix | Text field + Apply | Sets labels to "Prefix1", "Prefix2", etc. |
| Kind | Picker | Shows common kind or dash if mixed |
| Size | Segmented picker | Non-patch-point controls; hidden if all are patch points |
| Width | Stepper (5–200) | Screen controls; shows "Mixed" if values differ |
| Height | Stepper (5–200) | Screen controls; shows "Mixed" if values differ |
| Length | Stepper (10–200) | Slider controls; shows "Mixed" if values differ |
| Orientation | Segmented picker | Toggle switches and sliders |
| Control Label (Position/Size/Offset) | Mixed controls | Shows dash/Mixed for differing values |
| State Label (Position/Size/Offset) | Button/toggle switch only | Shows dash/Mixed for differing values |

### Edit Mode

- Any change enters edit mode.
- A floating toolbar appears at the bottom of the canvas:
  - **Discard Edits**: reverts to state before editing.
  - **Save Changes**: saves immediately, or shows confirmation if the module is placed in racks ("Module In Use: changes will affect all existing placements").
- While editing, selecting a different module is blocked until changes are saved or discarded.
- All edits support Undo/Redo (Cmd+Z / Cmd+Shift+Z).

---

## Image Analysis

When "Analyse Image" is invoked, the ML detector determines:

- **Format**: compares median detected jack bounding box size to the known 9mm jack diameter to estimate panel height, then classifies as 1U (39.65mm) or 3U (128.5mm).
- **Width HP**: from image aspect ratio and determined format height, calculated as width in mm / 5.08.
- **Control types and positions**: mapped from detection labels to control kinds.
- **Control sizes**: bounding box radius compared to base radius for each type. Scale <0.8 = S, <1.25 = M, <1.8 = L, else XL.
- **Orientation** (slider/toggle switch): from bounding box aspect ratio (taller = vertical, wider = horizontal).

---

## Control Types Reference

| Kind | Default Label | Sizeable | Special Properties |
|------|-------------|----------|-------------------|
| Knob | "Knob" | Yes (S/M/L/XL) | — |
| Patch Point | "Patch" | No (always M) | Fixed 5pt radius |
| Toggle Switch | "Switch" | Yes | Orientation (V/H), named states (min 2), state label |
| Button | "Button" | Yes | Named states (min 2), state label |
| Slider | "Slider" | Yes | Track length (10–200 pt), Orientation (V/H) |
| Screen | "Screen" | Yes | Width (5–200 pt), Height (5–200 pt) |

Size scales: S = 0.6x, M = 1.0x, L = 1.5x, XL = 2.2x.

---

## Module Properties

| Property | Default | Range |
|----------|---------|-------|
| Name | "New Module" | Free text, auto-uniquified |
| Format | 3U | 3U, 1U |
| Width | 8 HP | 2–999 HP |
| Background image | None | PNG/JPEG/TIFF/HEIC |

Panel dimensions: 3U = 256pt height, 1U = 79pt height. Width = HP x 10pt.

---

## Menu Items (Modules Menu)

Visible only in Modules mode. All items disabled when not in Modules mode.

| Item | Shortcut | Condition |
|------|----------|-----------|
| New Module from Image... | Cmd+N | — |
| New Blank Module | Cmd+Shift+N | — |
| Rename Module | Cmd+R | Module selected |
| Duplicate Module | Cmd+D | Module selected |
| Delete Module | Delete | Module(s) selected |
| Set Background Image... | — | Module selected |
| Analyse Image | Cmd+Shift+A | Module selected |
| Place Knob (toggle) | — | — |
| Place Patch Point (toggle) | — | — |
| Place Toggle Switch (toggle) | — | — |
| Place Button (toggle) | — | — |
| Place Slider (toggle) | — | — |
| Place Screen (toggle) | — | — |
| Snap to Grid | — | Control(s) selected |
| Centre Horizontally | — | Control(s) selected |
| Centre Vertically | — | Control(s) selected |
| Distribute Horizontally | — | 2+ controls selected |
| Distribute Vertically | — | 2+ controls selected |
| Delete Selected Controls | — | Control(s) selected |

## View Menu Items (Modules Mode)

| Item | Shortcut | Behaviour in Modules Mode |
|------|----------|--------------------------|
| Zoom In | Cmd+= | Zoom canvas in |
| Zoom Out | Cmd+- | Zoom canvas out |
| Frame | Cmd+0 | Reset zoom and pan |
| Show Labels | Cmd+Shift+L | Disabled |
| Show Groups | — | Disabled |
| Show Patch Numbers | — | Disabled |
| Show Patch Notes | — | Disabled |
| Show Grid | — | Enabled: toggles grid overlay |
| Show Detections | — | Enabled: toggles detection bounding boxes |
| Hide Controls | — | Enabled: toggles control visibility |

## Keyboard Shortcuts Summary

| Shortcut | Context | Action |
|----------|---------|--------|
| Cmd+1 | Global | Switch to Modules mode |
| Cmd+N | — | New Module from Image |
| Cmd+Shift+N | — | New Blank Module |
| Cmd+R | Library | Rename Module |
| Cmd+D | Library | Duplicate Module |
| Cmd+D | Canvas, controls selected | Duplicate selected controls |
| Cmd+A | Canvas | Select all controls |
| Delete | Library | Delete selected module(s) |
| Delete | Canvas | Delete selected control(s) |
| Cmd+Shift+A | — | Analyse Image |
| Cmd+= | — | Zoom In |
| Cmd+- | — | Zoom Out |
| Cmd+0 | — | Frame (reset zoom/pan) |
| Arrow keys | Canvas, controls selected | Nudge 0.5 pt |
| Shift+Arrows | Canvas, controls selected | Nudge 5 pt |
| Cmd+Z | — | Undo |
| Cmd+Shift+Z | — | Redo |
