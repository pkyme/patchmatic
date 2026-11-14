import SwiftUI

struct ModeCommands: View {
    @FocusedValue(\.switchMode) private var switchMode
    let currentMode: AppMode

    var body: some View {
        Picker("Mode", selection: Binding(
            get: { currentMode },
            set: { switchMode?($0) }
        )) {
            Text("Modules").tag(AppMode.modules)
                .keyboardShortcut("1", modifiers: .command)
            Text("Racks").tag(AppMode.racks)
                .keyboardShortcut("2", modifiers: .command)
            Text("Patches").tag(AppMode.patches)
                .keyboardShortcut("3", modifiers: .command)
            Text("Sets").tag(AppMode.sets)
                .keyboardShortcut("4", modifiers: .command)
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}

struct ZoomCommands: View {
    @FocusedValue(\.zoomIn) var zoomIn
    @FocusedValue(\.zoomOut) var zoomOut
    @FocusedValue(\.frameContent) var frameContent
    let currentMode: AppMode

    private var isZoomable: Bool { currentMode != .sets }

    var body: some View {
        Button("Zoom In") { zoomIn?() }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(!isZoomable || zoomIn == nil)
        Button("Zoom Out") { zoomOut?() }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(!isZoomable || zoomOut == nil)
        Button("Frame") { frameContent?() }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(!isZoomable || frameContent == nil)
    }
}

struct ViewToggleCommands: View {
    @FocusedValue(\.editorVM) var editorVM
    @FocusedValue(\.rackVM) private var rackVM
    let currentMode: AppMode

    var body: some View {
        Toggle("Show Labels", isOn: Binding(
            get: { rackVM?.showLabels ?? true },
            set: { rackVM?.showLabels = $0 }
        ))
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(currentMode == .modules || currentMode == .sets)

        Toggle("Show Groups", isOn: Binding(
            get: { patchVM?.showGroups ?? false },
            set: { patchVM?.showGroups = $0 }
        ))
        .disabled(currentMode != .patches)

        Toggle("Show Patch Numbers", isOn: Binding(
            get: { rackVM?.showPatchNumbers ?? false },
            set: { rackVM?.showPatchNumbers = $0 }
        ))
            .disabled(currentMode != .patches)

        Toggle("Show Patch Notes", isOn: Binding(
            get: { patchVM?.showPatchNotes ?? false },
            set: { patchVM?.showPatchNotes = $0 }
        ))
            .disabled(currentMode != .patches)

        Divider()

        Toggle("Show Grid", isOn: Binding(
            get: { editorVM?.showGrid ?? false },
            set: { editorVM?.showGrid = $0 }
        ))
        .disabled(currentMode != .modules)

        Toggle("Show Detections", isOn: Binding(
            get: { editorVM?.showDetections ?? false },
            set: { newValue in
                editorVM?.showDetections = newValue
                editorVM?.toggleDetections()
            }
        ))
        .disabled(currentMode != .modules)

        Toggle("Hide Controls", isOn: Binding(
            get: { !(editorVM?.showControls ?? true) },
            set: { editorVM?.showControls = !$0 }
        ))
        .disabled(currentMode != .modules)
    }

    @FocusedValue(\.patchVM) private var patchVM
}

struct AppearanceCommands: View {
    @AppStorage(AppSettings.appearanceMode) private var appearanceMode: String = "system"

    var body: some View {
        Menu("Appearance") {
            Picker("Appearance", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
}
