import SwiftUI

// MARK: - App Mode

enum AppMode: String, CaseIterable, Identifiable {
    case modules = "Modules"
    case racks = "Racks"
    case patches = "Patches"
    case sets = "Sets"

    var id: String { rawValue }

}

// MARK: - Focused Value Keys

private struct EditorVMKey: FocusedValueKey {
    typealias Value = ModuleEditorViewModel
}

private struct RackVMKey: FocusedValueKey {
    typealias Value = RackViewModel
}

private struct PatchVMKey: FocusedValueKey {
    typealias Value = PatchViewModel
}

private struct SetVMKey: FocusedValueKey {
    typealias Value = PatchSetViewModel
}

private struct ZoomInKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ZoomOutKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct FrameContentKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct PrintPatchKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct SwitchModeKey: FocusedValueKey {
    typealias Value = @MainActor (AppMode) -> Void
}

extension FocusedValues {
    var editorVM: ModuleEditorViewModel? {
        get { self[EditorVMKey.self] }
        set { self[EditorVMKey.self] = newValue }
    }

    var rackVM: RackViewModel? {
        get { self[RackVMKey.self] }
        set { self[RackVMKey.self] = newValue }
    }

    var patchVM: PatchViewModel? {
        get { self[PatchVMKey.self] }
        set { self[PatchVMKey.self] = newValue }
    }

    var setVM: PatchSetViewModel? {
        get { self[SetVMKey.self] }
        set { self[SetVMKey.self] = newValue }
    }

    var zoomIn: (() -> Void)? {
        get { self[ZoomInKey.self] }
        set { self[ZoomInKey.self] = newValue }
    }

    var zoomOut: (() -> Void)? {
        get { self[ZoomOutKey.self] }
        set { self[ZoomOutKey.self] = newValue }
    }

    var frameContent: (() -> Void)? {
        get { self[FrameContentKey.self] }
        set { self[FrameContentKey.self] = newValue }
    }

    /// Prints the active patch; set only in Patches mode
    var printPatch: (() -> Void)? {
        get { self[PrintPatchKey.self] }
        set { self[PrintPatchKey.self] = newValue }
    }

    /// Switches mode, asking to save or discard uncommitted edits first
    var switchMode: (@MainActor (AppMode) -> Void)? {
        get { self[SwitchModeKey.self] }
        set { self[SwitchModeKey.self] = newValue }
    }
}

// MARK: - Helper Modifier

struct FocusedAppState: ViewModifier {
    let editorVM: ModuleEditorViewModel
    let rackVM: RackViewModel
    let patchVM: PatchViewModel
    let setVM: PatchSetViewModel

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.editorVM, editorVM)
            .focusedSceneValue(\.rackVM, rackVM)
            .focusedSceneValue(\.patchVM, patchVM)
            .focusedSceneValue(\.setVM, setVM)
    }
}
