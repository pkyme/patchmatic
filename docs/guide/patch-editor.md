# Patch Editor

A patch is a snapshot of a rack: it stores cable connections, control positions, notes, and other state independently from every other patch on the same rack. You can have as many patches per rack as you like.

## Creating a patch

In **Patches** mode, click **+** in the patch list. A submenu lists all racks — click a rack name to create a patch for it. The patch opens showing the rack layout.

## Drawing cables

Drag from a patch point to another patch point to create a cable. A preview cable is shown while dragging. The cable is created when you release over a valid target. Colors are auto-assigned from the 24-color palette in round-robin order.

To change a cable's color, right-click the cable and select **Change Color**, then pick from the color grid.

## Selecting and deleting cables

- Right-click a cable to select it and show its context menu
- Shift+Click to add a cable to the selection
- Right-click a patch point to select all cables connected to it
- Delete selected cables with the Delete key or via the context menu

## Routing cables with pins

Pins are intermediate waypoints that redirect cable routing.

- **Cmd+Click** on a cable to insert a pin at that location
- Drag a pin to reposition it
- Right-click a pin and select **Delete Cable Pin** to remove it, or select it and press Delete

Pins attached to a case move with the case when it is repositioned.

## Control interaction

**Knobs** — drag vertically to adjust (up increases, down decreases).

**Sliders** — drag along the slider axis.

**Toggle switches and buttons** — click to advance to the next state, cycling through all named states.

**Screens** — hover over a screen to reveal a toolbar:
- **+** — attach an image (cropped to the control's aspect ratio)
- **← / →** — cycle through multiple attached images
- **Magnifier** — zoom the current image
- **✕** — delete the current image

All control values are stored per patch and restored when you switch back to a patch.

## Module notes

**Patch point notes** — right-click while hovering a patch point to add or edit a short text note. Notes appear as indicators on the module panel; hover to read them.

**General module notes** — right-click on the module body (not over a patch point) and select **Add Note** to place a free-form text note on the panel.

Both types of notes are stored per patch.

## Groups

Groups are named overlays that color-highlight sets of modules for organizational purposes. Click the **Groups** toolbar toggle to show or hide group overlays and the floating group list.

- **Create a group** — right-click a module and select **New Group with [name]**. To include multiple modules, select them first, then right-click.
- **Add / remove modules** — right-click a module and use **Add to Group** or **Remove from Group**
- **Hover a group card** — highlights that group's modules and fades others
- **Click a group card** — animates the canvas to fit all modules in the group
- **Right-click a group card** — rename, edit notes, or delete the group

## Patch notes

Each patch has a free-form text field and an optional audio file attachment.

Open the patch notes sheet from the **Patches** menu, the canvas context menu (**Patch Notes…**), or by clicking the patch notes overlay on the canvas (visible when the **Notes** toolbar toggle is on). The overlay shows the first line of patch notes and an audio icon if an audio file is attached.

## Toolbar toggles

| Toggle | Action |
|---|---|
| Labels | Show or hide control labels |
| Groups | Show or hide group overlays |
| Numbers | Show or hide patch point sequence numbers |
| Notes | Show or hide the patch notes overlay |

## Canvas navigation

- **Scroll wheel or pinch** — zoom (0.25×–5.0×)
- **Drag on empty space** — pan
- **Frame to Fit** — fits all cases to the viewport (Cmd+0 or toolbar button)
