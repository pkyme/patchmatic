# iPad

Patchmatic for iPad lets you look through your sets but not change them. It reads the library from a sync folder in iCloud Drive that the Mac app writes to. The iPad never modifies the library; all editing happens on the Mac.

## Setting up the sync folder on the Mac

1. Choose **File > Sync Folder…**.
2. Select a folder in iCloud Drive (the dialog opens there by default) and click **Use Folder**.

Patchmatic moves the library into the folder, along with its screen images and audio. If the folder already contains a Patchmatic library, you are asked to confirm before it is replaced with the library on the Mac.

While a sync folder is in use, Patchmatic saves to it every 30 seconds when no edit is in progress, so changes reach the iPad without quitting the app.

To go back to storing the library only on the Mac, choose **File > Stop Using Sync Folder**. The library, images, and audio are copied back to the Mac's local storage.

If the sync folder cannot be read at launch, Patchmatic shows a warning and uses the copy stored on the Mac. Changes made in that state do not reach the iPad. Check that iCloud Drive is available, then relaunch or choose the folder again.

## Connecting the iPad

On first launch, tap **Choose Folder** and select the same iCloud Drive folder chosen on the Mac. The library loads and the folder is remembered. To switch folders later, tap the folder button in the sidebar toolbar.

If the library cannot be loaded, tap **Try Again** or **Choose Another Folder**.

The iPad reloads the library automatically when it changes on the Mac, and again when the app returns to the foreground.

## Browsing sets

The sidebar contains two lists:

- **Sets** — tap a set to open it
- **Patches in Set** — tap a patch to jump to it; patches with an audio preview show a play button

The selected set and patch are stored on the iPad and restored on the next launch.

When the sidebar is hidden:

- Swipe in from the left edge of the screen for the previous patch, or from the right edge for the next patch
- Dots along the bottom of the rack show the current position in the set; they brighten briefly when the patch changes

## Viewing a patch

- **Pinch** — zoom
- **Frame Rack** toolbar button — fit the rack to the screen; the rack also refits when the iPad rotates or the sidebar is shown or hidden
- **Display** toolbar button — set the opacity of module panel photos and the appearance (system, light, or dark)
- **Notes** — tap a module note or patch point note indicator to read it in a popover
- **Screen images** — tap a screen to open the magnifier; swipe to page between images. Tap the magnified image to close it.
- **Patch notes** — the overlay shows a play button when the patch has an audio file

## Requirements

- iPadOS 17.0 or later
- An iCloud Drive folder shared with a Mac running Patchmatic
