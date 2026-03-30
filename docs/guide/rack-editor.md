# Rack Editor

The Rack Editor is where you assemble module definitions into a physical case layout.

## Racks and cases

A **rack** is a top-level container that holds one or more **cases**. Cases represent physical enclosures. Multiple cases per rack let you model a multi-case setup as a single unit.

To create a rack, click **+** in the rack list (or Cmd+N). To add a case to a rack, click the **New Case** toolbar button, use Cmd+Shift+C, or right-click on empty canvas space.

## Configuring a case

- **Rename** — click the case name in its header
- **HP width** — click the HP value in the case header; applies to all rows in the case
- **Add a row** — click the gear icon in the case header (or right-click the case) and select **Add 3U Row** or **Add 1U Row**
- **Remove a row** — same menu, then choose the row to remove; this also removes all modules in that row

New cases start with two rows by default.

## Placing modules

Modules are placed from the **module strip** at the bottom of the canvas. Drag a module thumbnail from the strip onto a row. A dashed outline shows the target position while dragging.

Placement rules:
- A 3U module can only be placed in a 3U row; a 1U module only in a 1U row
- The module must fit within the available HP space in the row

To remove a module, select it and press Delete, or right-click and choose **Delete**.

## Moving modules

Drag a module within its row to reposition it. Modules snap to the HP grid. Modules cannot be moved between cases by dragging — remove and re-place instead.

Select multiple modules with Shift+Click or a marquee drag, then drag one to move all selected modules together.

Use the Left/Right arrow keys to nudge selected modules by 1 HP.

## Arranging cases on the canvas

Drag a case by its header to reposition it freely on the canvas. Guide lines appear when a case aligns with another, and cases snap to an 8HP grid while dragging. Selecting multiple cases and dragging one moves all selected cases together.

## Canvas navigation

- **Scroll wheel or pinch** — zoom (0.25×–5.0×)
- **Drag on empty space** — pan
- **Frame to Fit** — fits all cases to the viewport (Cmd+0 or toolbar button)

Zoom and pan position are saved between sessions.

## Saving and discarding changes

Any modification enters edit mode. A Save/Discard toolbar appears at the bottom of the canvas. If the rack has existing patches, saving will show a confirmation. Switching to a different rack while in edit mode triggers an alert.

All edits support Undo/Redo (Cmd+Z / Cmd+Shift+Z).
