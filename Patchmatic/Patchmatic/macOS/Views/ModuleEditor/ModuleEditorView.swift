import SwiftUI

struct ModuleEditorView: View {
    @Bindable var viewModel: ModuleEditorViewModel
    @FocusState var moduleNameFocused: Bool
    @State var batchLabelPrefix = ""
    @State private var frameModuleTrigger = false

    var body: some View {
        if let module = viewModel.selectedModule {
            HorizontalSplitOrStack {
                // Left: Canvas + toolbar
                VStack(spacing: 0) {
                    canvasToolbar
                    Divider()
                    ModulePreviewCanvas(
                        definition: module,
                        selectedControlIDs: viewModel.selectedControlIDs,
                        knobValues: [:],
                        isPlacementMode: viewModel.placingControlKind != nil,
                        backgroundImage: viewModel.backgroundCGImage,
                        backgroundOpacity: viewModel.backgroundOpacity,
                        showGrid: viewModel.showGrid,
                        gridDivisions: viewModel.gridDivisions,
                        showControls: viewModel.showControls,
                        detections: viewModel.detections,
                        highlightedDetectionID: viewModel.highlightedDetectionID,
                        onTap: { normalizedPos in
                            if let kind = viewModel.placingControlKind {
                                viewModel.addControl(kind: kind, at: normalizedPos)
                            }
                        },
                        onBeginDragControl: {
                            viewModel.beginControlDrag()
                        },
                        onEndDragControl: {
                            viewModel.endControlDrag()
                        },
                        onDragControl: { controlID, normalizedPos in
                            viewModel.moveControl(controlID, to: normalizedPos)
                        },
                        onSelectControl: { controlID, extending in
                            viewModel.selectControl(controlID, extending: extending)
                        },
                        onClearSelection: {
                            viewModel.clearSelection()
                        },
                        onMarqueeSelect: { ids in
                            viewModel.selectControls(ids)
                        },
                        onDragSelectedControls: { dx, dy in
                            viewModel.moveSelectedControls(dx: dx, dy: dy)
                        },
                        onDetectionClick: { point in
                            viewModel.highlightDetection(at: point)
                        },
                        onNudge: { dx, dy in
                            viewModel.moveSelectedControls(dx: dx, dy: dy)
                        },
                        onBeginResizeControl: { id in
                            viewModel.beginControlDrag()
                        },
                        onResizeScreen: { id, w, h, center in
                            viewModel.resizeControlScreen(id, width: w, height: h, center: center)
                        },
                        onResizeSlider: { id, len, center in
                            viewModel.resizeControlSlider(id, length: len, center: center)
                        },
                        onEndResizeControl: { id in
                            viewModel.endControlDrag()
                        },
                        zoom: $viewModel.canvasZoom,
                        frameModuleTrigger: $frameModuleTrigger
                    )
                    .frame(minWidth: 200, minHeight: 300)
                    .padding()
                    .overlay(alignment: .bottom) {
                        if viewModel.isEditing {
                            EditConfirmationToolbar(
                                onSave: { viewModel.requestCommit() },
                                onDiscard: { viewModel.discardEditing() }
                            )
                            .padding(.bottom, 16)
                        }
                    }
                    .alert("Module In Use", isPresented: $viewModel.pendingSaveConfirmation) {
                        Button("Save Anyway", role: .destructive) { viewModel.commitEditing() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(viewModel.inUseWarning ?? "")
                    }
                    .focusable()
                    .focusEffectDisabled()
                    .onDeleteCommand {
                        viewModel.deleteSelectedControls()
                    }
                    .onKeyPress(characters: CharacterSet(charactersIn: "ad")) { keyPress in
                        guard keyPress.modifiers == .command else { return .ignored }
                        switch keyPress.characters {
                        case "a":
                            viewModel.selectAllControls()
                            return .handled
                        case "d":
                            guard !viewModel.selectedControlIDs.isEmpty else { return .ignored }
                            viewModel.duplicateSelectedControls()
                            return .handled
                        default:
                            return .ignored
                        }
                    }
                }

                // Right: Property inspector
                Form {
                    moduleSection(module)
                    selectedControlSection(module)
                    multipleControlsSection(module)
                }
                .formStyle(.grouped)
                .frame(minWidth: 250, maxWidth: 300)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ControlGroup {
                        Button {
                            viewModel.zoom(by: ModuleEditorViewModel.zoomStep)
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .help("Zoom In")

                        Button {
                            viewModel.zoom(by: 1 / ModuleEditorViewModel.zoomStep)
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .help("Zoom Out")

                        Button {
                            frameModuleTrigger = true
                        } label: {
                            Image(systemName: "1.magnifyingglass")
                        }
                        .help("Frame Module")
                    }

                    ControlGroup {
                        Slider(value: $viewModel.backgroundOpacity, in: 0...1)
                            .frame(width: 80)
                            .help("Image Opacity")
                            .padding(.horizontal, 4)
                    }
                }
            }
            .fileImporter(
                isPresented: $viewModel.showingBackgroundImagePicker,
                allowedContentTypes: [.png, .jpeg, .tiff, .heic],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result,
                      let url = urls.first,
                      url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let image = PlatformImage.fromURL(url) else { return }
                viewModel.setBackgroundImage(image)
            }
            .focusedSceneValue(\.zoomIn) {
                viewModel.zoom(by: ModuleEditorViewModel.zoomStep)
            }
            .focusedSceneValue(\.zoomOut) {
                viewModel.zoom(by: 1 / ModuleEditorViewModel.zoomStep)
            }
            .focusedSceneValue(\.frameContent) {
                frameModuleTrigger = true
            }
        } else if viewModel.selectedModuleIDs.count > 1 {
            Text("\(viewModel.selectedModuleIDs.count) modules selected")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Select a module from the library or create a new one.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func placementToggle(kind: Control.Kind, label: String, icon: String) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.placingControlKind == kind },
            set: { viewModel.placingControlKind = $0 ? kind : nil }
        )) {
            Label(label, systemImage: icon)
        }
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .help(label)
    }

    @ViewBuilder private var canvasToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Placement
                placementToggle(kind: .knob,        label: "Place Knob",         icon: "dial.medium")
                placementToggle(kind: .patchPoint,  label: "Place Patch Point",  icon: "cable.connector")
                placementToggle(kind: .toggleSwitch,label: "Place Toggle Switch",icon: "switch.2")
                placementToggle(kind: .button,      label: "Place Button",       icon: "hand.tap")
                placementToggle(kind: .slider,      label: "Place Slider",       icon: "slider.horizontal.3")
                placementToggle(kind: .screen,      label: "Place Screen",       icon: "rectangle")

                Divider().frame(height: 20)

                Button {
                    viewModel.showingBackgroundImagePicker = true
                } label: {
                    Label("Set Background Image", systemImage: "photo")
                }
                .labelStyle(.iconOnly)
                .help("Set Background Image")

                Button {
                    viewModel.analyseImage()
                } label: {
                    Label("Analyse Background Image", systemImage: "cpu")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.backgroundImage == nil)
                .help("Analyse Background Image")

                Toggle(isOn: Binding(
                    get: { viewModel.showDetections },
                    set: {
                        viewModel.showDetections = $0
                        viewModel.toggleDetections()
                    }
                )) {
                    Label("Show Detections", systemImage: "viewfinder")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .disabled(viewModel.backgroundImage == nil)
                .help("Show Detections")

                Toggle(isOn: Binding(
                    get: { !viewModel.showControls },
                    set: { viewModel.showControls = !$0 }
                )) {
                    Label("Hide Controls", systemImage: "eye.slash")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Hide Controls")

                Divider().frame(height: 20)

                Button(role: .destructive) {
                    viewModel.deleteSelectedControls()
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.selectedControlIDs.isEmpty)
                .help("Delete Selected Controls")

                Button {
                    viewModel.snapSelectedToGrid(divisions: viewModel.gridDivisions)
                } label: {
                    Label("Snap to Grid", systemImage: "square.dashed")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.selectedControlIDs.isEmpty)
                .help("Snap Selected to Grid")

                Divider().frame(height: 20)

                Button {
                    viewModel.centerSelectedHorizontally()
                } label: {
                    Label("Centre Horizontally", systemImage: "align.horizontal.center")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.selectedControlIDs.count < 2)
                .help("Centre Horizontally")

                Button {
                    viewModel.centerSelectedVertically()
                } label: {
                    Label("Centre Vertically", systemImage: "align.vertical.center")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.selectedControlIDs.count < 2)
                .help("Centre Vertically")

                Button {
                    viewModel.distributeSelectedHorizontally()
                } label: {
                    Label("Distribute Horizontally", systemImage: "distribute.horizontal.center")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.selectedControlIDs.count < 3)
                .help("Distribute Horizontally")

                Button {
                    viewModel.distributeSelectedVertically()
                } label: {
                    Label("Distribute Vertically", systemImage: "distribute.vertical.center")
                }
                .labelStyle(.iconOnly)
                .disabled(viewModel.selectedControlIDs.count < 3)
                .help("Distribute Vertically")

                Divider().frame(height: 20)

                Toggle(isOn: $viewModel.showGrid) {
                    Label("Show Grid", systemImage: "grid")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Show Grid")

                HStack(spacing: 2) {
                    Text("\(viewModel.gridDivisions)")
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 22, alignment: .trailing)
                    Stepper("Grid Size", value: $viewModel.gridDivisions, in: 2...128)
                        .labelsHidden()
                }
                .help("Grid Divisions")

            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}
