# Module Editor

The Module Editor is where you define the layout of individual Eurorack modules. Each module definition serves as a reusable template that can be placed into racks.

## Creating a module from a photo

Click the **camera** icon button in the library toolbar, or drag an image file onto the library (supported formats: PNG, JPEG, TIFF, HEIC). You can also use **Modules > New Module from Image** (Cmd+N).

Patchmatic creates a new module, sets the photo as the background image, and prompts you to run automatic control detection. The ML model identifies knobs, patch points, toggle switches, buttons, and sliders and places them on the panel, and estimates the module's format (1U or 3U) and width in HP.

Review the results after detection — some controls may be missed or misclassified. Adjust, delete, or add controls as needed. To re-run detection at any time, click the **Analyse Background Image** button (cpu icon) in the canvas toolbar, or use Cmd+Shift+A.

To create a blank module instead, click the **+** button or use Cmd+Shift+N.

## Module properties

Edit the module's name, format (3U or 1U), and width in HP in the inspector panel on the right. Changing the format rescales the HP width proportionally.

## Adding controls manually

Select a control type from the canvas toolbar to enter placement mode, then click on the canvas to place the control. Clicking the active button again exits placement mode. Available types:

| Type | Description |
|---|---|
| Knob | Rotary control |
| Patch Point | 3.5 mm jack |
| Toggle Switch | Multi-position switch |
| Button | Momentary or latching button |
| Slider | Linear fader |
| Screen | Rectangular display area |

## Control properties

Select a control to edit its properties in the inspector:

- **Size** — small, medium, large, or extra large (not applicable to patch points, which are always medium)
- **Orientation** — vertical or horizontal (toggle switches and sliders)
- **Label** — position (above, below, left, right, or off), font size, and offset
- **State Label** — separate label position settings for the state indicator (buttons and toggle switches)
- **States** — named states for buttons and toggle switches (e.g. "Off", "On"); minimum 2, no maximum
- **Width / Height** — independent dimensions for screens
- **Length** — track length for sliders

When two or more controls are selected, the inspector shows batch editing options: bulk label prefix, kind, size, and label positioning.

## Selecting and editing controls

| Action | Behaviour |
|---|---|
| Click control | Select single control |
| Shift+Click | Add or remove from selection |
| Drag on empty space | Pan canvas |
| Shift+Drag on empty space | Marquee selection |
| Click empty space | Clear selection |
| Click overlapping controls repeatedly | Cycle through the stack |
| Cmd+A | Select all controls |
| Cmd+D | Duplicate selected controls (offset slightly) |
| Delete | Remove selected controls |
| Arrow keys | Nudge selected controls 0.5 pt |
| Shift+Arrow keys | Nudge 5 pt |

## Resizing controls

Screen and slider controls can be resized by dragging a handle on their selection highlight:

| Control | Handle location | Resizes |
|---|---|---|
| Screen | Bottom-right corner | Width and height |
| Horizontal slider | Right edge | Length |
| Vertical slider | Bottom edge | Length |

## Alignment and layout tools

With multiple controls selected, the canvas toolbar provides:

- **Snap to Grid** — snaps selected controls to the nearest grid intersection
- **Centre Horizontally / Vertically** — aligns to the average position across the selection
- **Distribute Horizontally / Vertically** — evenly spaces controls between the two outermost positions (requires 3+ controls)

## Background image

When a photo is imported, it appears behind the controls on the canvas. Use the **Image Opacity** slider in the window toolbar to fade it while positioning controls. To replace the background image without re-running detection, click the **photo** icon in the canvas toolbar.

Toggle **Show Detections** to show or hide the color-coded detection bounding boxes from the last analysis run. Toggle **Hide Controls** to temporarily hide placed controls and see the background image clearly.

## Canvas navigation

- **Scroll wheel or pinch** — zoom (1×–8×)
- **Option+Drag or drag on empty space** — pan
- **Zoom In / Zoom Out** — toolbar buttons or Cmd+= / Cmd+-
- **Frame** — reset zoom and center the view (Cmd+0)

## Saving and discarding changes

Any change enters edit mode. A Save/Discard toolbar appears at the bottom of the canvas. Switching to another module while in edit mode is blocked until you save or discard. Saving a module that is already placed in a rack will update all existing placements.

All edits support Undo/Redo (Cmd+Z / Cmd+Shift+Z).
