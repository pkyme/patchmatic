# Agents

## Build

Xcode project at `Patchmatic/Patchmatic.xcodeproj` (Xcode 16 or later). One multiplatform target: macOS 14.0+ editor and an iPadOS 17.0+ read-only Sets viewer. Swift 6 language mode, with complete concurrency checking.

```sh
xcodebuild -project Patchmatic/Patchmatic.xcodeproj -scheme Patchmatic -configuration Debug -destination platform=macOS build
xcodebuild -project Patchmatic/Patchmatic.xcodeproj -scheme Patchmatic -configuration Debug -destination generic/platform=iOS build
```

**Always build Debug** unless specifically requested to build Release.

**Always rebuild after every code change**, for both platforms when touching `Shared/`. Swift type errors and missing symbols are common after refactors and won't surface until you build.

The project has one SPM dependency: `onnxruntime-swift-package-manager` (Microsoft ONNX Runtime, macOS only). Xcode resolves it automatically on first build.

The detection model is not in git. Run `scripts/fetch_model.sh` to download it from the GitHub release into `Patchmatic/Models/`; a build phase copies it into the macOS app when present. Without it the app builds and image detection is unavailable.

Signing settings live in `Patchmatic/Config/Signing.xcconfig`. Set your own `DEVELOPMENT_TEAM` (and optionally `PATCHMATIC_BUNDLE_ID`) in a git-ignored `Patchmatic/Config/Local.xcconfig`, or build with `CODE_SIGNING_ALLOWED=NO`.

## Tests

Unit tests live in `Patchmatic/PatchmaticTests/` (Swift Testing, macOS only) and run inside the app with `@testable import Patchmatic`:

```sh
xcodebuild test -project Patchmatic/Patchmatic.xcodeproj -scheme Patchmatic -destination platform=macOS
```

Under tests the app starts with an empty in-memory library that is never saved (`DocumentManager.isRunningTests`), so test runs don't touch the user's data. `SampleFixture` in `TestSupport.swift` provides the sample library for tests.

## Project layout

```
Patchmatic/
  Patchmatic.xcodeproj/
  Media.xcassets/                 # App icon
  Patchmatic/                     # App source (file-system-synchronized folder)
    Shared/                       # Built for both platforms
      Models/                     #   Control, ModuleDefinition, Rack, Patch, PatchSet, PatchmaticDocument
      ViewModels/                 #   RackViewModel, PatchViewModel, PatchSetViewModel, CableGeometry
      Views/                      #   Rack canvas (Rack/), Sets views (PatchSets/), shared controls
      Drawing/                    #   GraphicsContext renderers, cable simulation
      Persistence/                #   DocumentManager, SyncFolder, SampleData
      Utilities/                  #   AppSettings, EditSession, ImageStore, AudioStore, etc.
      Resources/
    macOS/                        # macOS only
      PatchmaticApp.swift         #   Entry point and menus
      ContentView.swift           #   Root view, mode switching, autosave
      ViewModels/                 #   ModuleEditorViewModel
      Views/                      #   Module editor, library, patch list, rack list, printing
      Utilities/                  #   ImageAnalyzer (ONNX), FocusedValues, PatchPrinter, AskSiriMenuSuppressor
      Resources/                  #   Credits.rtf
    iPad/                         # iPad only: PatchmaticPadApp, PadRootView, PadPatchSetsView
  Config/                         # Signing.xcconfig (shared), Local.xcconfig (yours, git-ignored)
  Models/                         # eurorack-controls.onnx, from scripts/fetch_model.sh (git-ignored)
  docs/                           # Technical notes per mode, for developers
docs/                             # User guide (MkDocs), published to GitHub Pages
scripts/                          # fetch_model.sh, build_dmg.sh, sync_platform_filters.py
.github/workflows/                # CI build and test; docs deployment
```

Files are picked up from the folder automatically; no project file edits are needed to add, move or rename them. Each file in `macOS/` and `iPad/` has a per-file platform filter on the synchronized folder (Xcode file inspector, Target Membership). After adding, moving or removing files in either folder, run `python3 scripts/sync_platform_filters.py` to regenerate the filters.

## Architecture

- **Rendering**: All module controls are drawn via `GraphicsContext`, not native SwiftUI views. Renderers live in `Shared/Drawing/`; `ModuleRenderer.swift` dispatches to per-control-type renderers.
- **Control geometry**: `Control.bodyShape(in:zoom:)` (in `ModuleRenderer.swift`) is the single source for highlighting, hit testing (`hitTest(point:in:zoom:padding:)`) and label placement. It is built from size constants exposed by each renderer.
- **Gestures**: A single `DragGesture` on `RackView` handles canvas interaction. `showCables` switches between patch mode and rack mode; `readOnly` is used by Sets mode. Handlers are split across `RackView+CableGestures.swift`, `RackView+ModuleGestures.swift` and `RackView+Navigation.swift`, sharing transient state in `RackGestureState`. AppKit scroll and right-click monitors read view state through `RackEventMonitors`.
- **Cables**: `CableGeometry` provides cable/pin hit testing and keeps physics ropes in sync with cables and pins. `CableSimulation.swift` runs the Verlet simulation; a cable without a rope is treated as a catenary.
- **Coordinates**: Control positions within modules use normalized (0...1) coordinates. Rack layout uses absolute points with zoom. Conversion helpers are in `GeometryHelpers.swift`. Zoom limits are `RackViewModel.zoomRange`.
- **Persistence**: `DocumentManager` saves JSON to `~/Library/Application Support/Patchmatic/` or a user-chosen sync folder (`SyncFolder`) that the iPad reads. Autosave runs every 30 seconds, on deactivate and on quit. A library that fails to decode is moved aside, never overwritten. Selection (active rack, patch, set) is stored per device in UserDefaults, not in the document.
- **Edit session**: Editing VMs share `EditSession` for undo, commit and discard. Saves write each item's last committed state (`CommittedStateRestoring`), so uncommitted edits are never persisted. Edit steps are registered against the session and removed when it ends; document-level actions (deleting a patch or set) are registered against their view model and stay undoable across sessions.
- **Detection**: `ImageAnalyzer.swift` loads `eurorack-controls.onnx` (RF-DETR) via ONNX Runtime on a serial queue, runs inference at 704x704, and returns bounding boxes. macOS only.

## Key conventions

- The `@Observable` macro is used for view models (not `ObservableObject`/`@Published`).
- View models, `DocumentManager`, `EditSession`, `CableSimulator` and `CableGeometry` are `@MainActor`. Work done off the main thread (image thumbnails, ONNX inference, file coordination) touches only lock-protected or `nonisolated` state, and results come back on the main actor. Timers scheduled on the main run loop use `MainActor.assumeIsolated` in their callbacks.
- **Codable compatibility**: `PatchmaticDocument.currentSchemaVersion` must be incremented for changes older builds can't read. New model fields must be optional or decoded with `decodeIfPresent` and a default. All model enums use raw `String` values. Keep existing coding keys when renaming properties (e.g. `Patch.moduleNotes` is stored as `notes`).
- Screen controls store absolute point dimensions (`screenWidth`/`screenHeight`), unlike other controls which use normalized positions and a size scale.
- Mutators call `prepareEdit()` only after their guards pass, so no-ops don't create undo steps.
- `EditableText` uses an `NSEvent` monitor for double-click detection because SwiftUI gesture modifiers break `List` selection.

## Common tasks

**Adding a new control type**: Add the case to `Control.Kind` (raw String enum), create a renderer in `Shared/Drawing/`, add dispatch in `ModuleRenderer.swift` and a case in `Control.bodyShape`, handle it in the gesture handlers (`RackView+CableGestures.swift`), and map a detection class to it in `DetectedClass.controlKind` (`ImageAnalyzer.swift`) if the model detects it.

**Updating the detection model**: The model is trained outside this repository and distributed pre-trained. To replace it, put the new ONNX file at `Patchmatic/Models/eurorack-controls.onnx`, publish it as a new release asset, and update the tag and checksum in `scripts/fetch_model.sh`. It must keep the interface `ImageAnalyzer.swift` expects:

- Input `input`: `[1, 3, 704, 704]` float, RGB with ImageNet normalisation
- Output `dets`: `[1, 300, 4]` boxes as normalised centre x, centre y, width, height
- Output `labels`: `[1, 300, N]` raw logits (sigmoid, not softmax); the first five columns are the classes in `DetectedClass` order

**Making a release**: Run `scripts/fetch_model.sh`, build Release in Xcode, then `scripts/build_dmg.sh <version>` and attach the DMG to a GitHub release.

## Documentation

The user guide is in `docs/` and built with MkDocs (`mkdocs.yml`). When writing user documentation, all described features must be verified by referencing the application source code before being included.
