import SwiftUI

struct ModulesMenuCommands: View {
    @FocusedValue(\.editorVM) var editorVM

    var body: some View {
        Button("New Module from Image\u{2026}") {
            editorVM?.showingImageImporter = true
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("New Blank Module") { editorVM?.addModule() }
            .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("Rename Module") {
            editorVM?.renameModuleRequested = true
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(editorVM?.selectedModule == nil)

        Button("Duplicate Module") {
            if let module = editorVM?.selectedModule {
                editorVM?.duplicateModule(module)
            }
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(editorVM?.selectedModule == nil)

        Button("Delete Module") {
            editorVM?.requestDeleteSelectedModules()
        }
        .keyboardShortcut(.delete, modifiers: [])
        .disabled(editorVM?.selectedModuleIDs.isEmpty ?? true)

        Divider()

        Button("Set Background Image\u{2026}") {
            editorVM?.showingBackgroundImagePicker = true
        }
        .disabled(editorVM?.selectedModule == nil)

        Button("Analyse Image") { editorVM?.analyseImage() }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(editorVM?.selectedModule == nil)

        Divider()

        placeControlSection

        Divider()

        layoutSection

        Divider()

        Button("Delete Selected Controls") { editorVM?.deleteSelectedControls() }
            .disabled(editorVM?.selectedControlIDs.isEmpty ?? true)
    }

    @ViewBuilder private var placeControlSection: some View {
        placeToggle("Place Knob", kind: .knob)
        placeToggle("Place Patch Point", kind: .patchPoint)
        placeToggle("Place Toggle Switch", kind: .toggleSwitch)
        placeToggle("Place Button", kind: .button)
        placeToggle("Place Slider", kind: .slider)
        placeToggle("Place Screen", kind: .screen)
    }

    private func placeToggle(_ title: String, kind: Control.Kind) -> some View {
        Toggle(title, isOn: Binding(
            get: { editorVM?.placingControlKind == kind },
            set: { editorVM?.placingControlKind = $0 ? kind : nil }
        ))
    }

    @ViewBuilder private var layoutSection: some View {
        Button("Snap to Grid") {
            editorVM?.snapSelectedToGrid(divisions: editorVM?.gridDivisions ?? 4)
        }
        .disabled(editorVM?.selectedControlIDs.isEmpty ?? true)

        Button("Centre Horizontally") { editorVM?.centerSelectedHorizontally() }
            .disabled(editorVM?.selectedControlIDs.isEmpty ?? true)

        Button("Centre Vertically") { editorVM?.centerSelectedVertically() }
            .disabled(editorVM?.selectedControlIDs.isEmpty ?? true)

        Button("Distribute Horizontally") { editorVM?.distributeSelectedHorizontally() }
            .disabled((editorVM?.selectedControlIDs.count ?? 0) < 2)

        Button("Distribute Vertically") { editorVM?.distributeSelectedVertically() }
            .disabled((editorVM?.selectedControlIDs.count ?? 0) < 2)
    }
}

struct RacksMenuCommands: View {
    @FocusedValue(\.rackVM) var rackVM

    var body: some View {
        Button("New Rack") { rackVM?.addRack() }
            .keyboardShortcut("n", modifiers: .command)

        Button("Rename Rack") {
            rackVM?.renamingRackID = rackVM?.rack?.id
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(rackVM?.rack == nil)

        Button("Duplicate Rack") {
            if let rack = rackVM?.rack {
                rackVM?.duplicateRack(rack)
            }
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(rackVM?.rack == nil)

        Button("Delete Rack") {
            if let rack = rackVM?.rack {
                rackVM?.deleteRack(rack)
            }
        }
        .disabled(rackVM?.rack == nil)

        Divider()

        Button("New Case") { rackVM?.addCase() }
            .keyboardShortcut("c", modifiers: [.command, .shift])
    }
}

struct PatchesMenuCommands: View {
    @FocusedValue(\.patchVM) var patchVM

    var body: some View {
        Menu("New Patch") {
            if let racks = patchVM?.document.racks {
                ForEach(racks) { rack in
                    Button(rack.name) {
                        patchVM?.addPatch(rackID: rack.id)
                    }
                }
            }
        }
        .disabled(patchVM?.document.racks.isEmpty ?? true)

        Button("Rename Patch") {
            patchVM?.renamingPatchID = patchVM?.activePatch?.id
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(patchVM?.activePatch == nil)

        Button("Duplicate Patch") {
            if let patch = patchVM?.activePatch {
                patchVM?.duplicatePatch(patch)
            }
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(patchVM?.activePatch == nil)

        Button("Delete Patch\u{2026}") {
            if let patch = patchVM?.activePatch {
                patchVM?.requestDeletePatch(patch)
            }
        }
        .disabled(patchVM?.activePatch == nil)

        Divider()

        Button("Patch Notes\u{2026}") {
            patchVM?.showingPatchNotesSheet = true
        }
        .disabled(patchVM?.activePatch == nil)

        Divider()

        Button("Copy Cables") { patchVM?.copySelectedCables() }
            .disabled(patchVM?.selectedCableIDs.isEmpty ?? true)

        Button("Paste Cables") { patchVM?.pasteCables() }
            .disabled(!(patchVM?.canPasteCables ?? false))
    }
}

struct SetsMenuCommands: View {
    @FocusedValue(\.setVM) var setVM

    var body: some View {
        Button("New Set") { setVM?.addSet() }
            .keyboardShortcut("n", modifiers: .command)

        Button("Rename Set") {
            setVM?.renamingSetID = setVM?.activeSet?.id
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(setVM?.activeSet == nil)

        Button("Delete Set\u{2026}") {
            if let set = setVM?.activeSet {
                setVM?.requestDeleteSet(set)
            }
        }
        .disabled(setVM?.activeSet == nil)

        Divider()

        Button("Next Patch") { setVM?.goToNext() }
            .keyboardShortcut(.rightArrow, modifiers: .command)

        Button("Previous Patch") { setVM?.goToPrevious() }
            .keyboardShortcut(.leftArrow, modifiers: .command)
    }
}
