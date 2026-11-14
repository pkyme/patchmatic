import SwiftUI

// The property inspector beside the module canvas
extension ModuleEditorView {
    /// Name, format and width of the module
    @ViewBuilder func moduleSection(_ module: ModuleDefinition) -> some View {
        Section("Module") {
            TextField("Name", text: Binding(
                get: { module.name },
                set: { viewModel.renameModule(module, to: $0) }
            ))
            .focused($moduleNameFocused)
            .onChange(of: viewModel.renameModuleRequested, initial: true) { _, requested in
                guard requested else { return }
                moduleNameFocused = true
                viewModel.renameModuleRequested = false
            }
            Picker("Format", selection: Binding(
                get: { module.format },
                set: { viewModel.setModuleFormat(module, to: $0) }
            )) {
                ForEach(RowSize.allCases, id: \.self) { size in
                    Text(size.rawValue).tag(size)
                }
            }
            .pickerStyle(.segmented)
            Stepper("Width: \(module.widthHP) HP",
                    value: Binding(
                        get: { module.widthHP },
                        set: { viewModel.setModuleWidthHP(module, to: $0) }
                    ),
                    in: EurorackConstants.minModuleHP...EurorackConstants.maxModuleHP)
        }
    }

    /// Properties of the single selected control
    @ViewBuilder func selectedControlSection(_ module: ModuleDefinition) -> some View {
        if let controlID = viewModel.selectedControlID,
           let control = module.controls.first(where: { $0.id == controlID }) {
            Section("Selected Control") {
                TextField("Label", text: controlBinding(controlID, \.label, default: ""))
                Picker("Kind", selection: Binding<Control.Kind>(
                    get: { control.kind },
                    set: { viewModel.setControlsKind($0, ids: [controlID]) }
                )) {
                    ForEach(Control.Kind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                if control.kind != .patchPoint {
                    Picker("Size", selection: controlBinding(controlID, \.size, default: .medium)) {
                        ForEach(Control.Size.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if control.kind == .screen {
                    Stepper("Width: \(Int(control.screenWidth)) pt",
                            value: controlBinding(controlID, \.screenWidth, default: EurorackConstants.defaultScreenWidth),
                            in: 5...200, step: 1)
                    Stepper("Height: \(Int(control.screenHeight)) pt",
                            value: controlBinding(controlID, \.screenHeight, default: EurorackConstants.defaultScreenHeight),
                            in: 5...200, step: 1)
                }
                if control.kind == .slider {
                    Stepper("Length: \(Int(control.sliderTrackLength)) pt",
                            value: controlBinding(controlID, \.sliderTrackLength, default: EurorackConstants.defaultSliderTrackLength),
                            in: 10...200, step: 1)
                }
                if control.kind == .toggleSwitch || control.kind == .slider {
                    Picker("Orientation", selection: controlBinding(controlID, \.orientation, default: .vertical)) {
                        ForEach(Control.Orientation.allCases, id: \.self) { o in
                            Text(o.rawValue).tag(o)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Control Label") {
                    labelConfigEditor(controlID, \.controlLabel, current: control.controlLabel)
                }

                if control.kind == .button || control.kind == .toggleSwitch {
                    Section("State Label") {
                        labelConfigEditor(controlID, \.stateLabel, current: control.stateLabel)
                    }

                    Section("States") {
                        ForEach(control.controlStates.indices, id: \.self) { si in
                            HStack {
                                TextField("", text: Binding(
                                    get: {
                                        let states = viewModel.selectedModule?.controls.first(where: { $0.id == controlID })?.controlStates ?? []
                                        return si < states.count ? states[si] : ""
                                    },
                                    set: { newName in
                                        viewModel.editControl(controlID, field: "controlStates[\(si)]") { c in
                                            if si < c.controlStates.count { c.controlStates[si] = newName }
                                        }
                                    }
                                ))
                                Button(role: .destructive) {
                                    viewModel.editControl(controlID, field: nil) { c in
                                        if si < c.controlStates.count { c.controlStates.remove(at: si) }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .disabled(control.controlStates.count <= 2)
                            }
                            .labelsHidden()
                        }
                        Button("+ Add State") {
                            viewModel.editControl(controlID, field: nil) { c in
                                c.controlStates.append("State \(c.controlStates.count + 1)")
                            }
                        }
                    }
                }
            }
        }
    }

    /// Properties shared by several selected controls
    @ViewBuilder func multipleControlsSection(_ module: ModuleDefinition) -> some View {
        if viewModel.selectedControlIDs.count > 1 {
            let selectedControls = module.controls.filter { viewModel.selectedControlIDs.contains($0.id) }

            Section("\(viewModel.selectedControlIDs.count) Controls Selected") {
                HStack {
                    TextField("Label Prefix", text: $batchLabelPrefix)
                    Button("Apply") {
                        viewModel.numberSelectedControls(prefix: batchLabelPrefix)
                        batchLabelPrefix = ""
                    }
                    .disabled(batchLabelPrefix.isEmpty)
                }

                let kinds = Set(selectedControls.map(\.kind))
                Picker("Kind", selection: Binding<Control.Kind?>(
                    get: { kinds.count == 1 ? kinds.first : nil },
                    set: { if let k = $0 { viewModel.setSelectedControlsKind(k) } }
                )) {
                    if kinds.count > 1 { Text("–").tag(Control.Kind?.none) }
                    ForEach(Control.Kind.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                }

                let sizableControls = selectedControls.filter { $0.kind != .patchPoint }
                if !sizableControls.isEmpty {
                    let sizes = Set(sizableControls.map(\.size))
                    Picker("Size", selection: Binding<Control.Size?>(
                        get: { sizes.count == 1 ? sizes.first : nil },
                        set: { if let s = $0 { viewModel.setSelectedControlsSize(s) } }
                    )) {
                        ForEach(Control.Size.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    .pickerStyle(.segmented)
                }

                let screenControls = selectedControls.filter { $0.kind == .screen }
                if !screenControls.isEmpty {
                    let widths = Set(screenControls.map(\.screenWidth))
                    Stepper(
                        widths.count > 1 ? "Width: Mixed" : "Width: \(Int(widths.first ?? EurorackConstants.defaultScreenWidth)) pt",
                        value: Binding(
                            get: { widths.min() ?? EurorackConstants.defaultScreenWidth },
                            set: { viewModel.setSelectedControlsScreenWidth($0) }
                        ),
                        in: 5...200, step: 1
                    )
                    let heights = Set(screenControls.map(\.screenHeight))
                    Stepper(
                        heights.count > 1 ? "Height: Mixed" : "Height: \(Int(heights.first ?? EurorackConstants.defaultScreenHeight)) pt",
                        value: Binding(
                            get: { heights.min() ?? EurorackConstants.defaultScreenHeight },
                            set: { viewModel.setSelectedControlsScreenHeight($0) }
                        ),
                        in: 5...200, step: 1
                    )
                }

                let sliderControls = selectedControls.filter { $0.kind == .slider }
                if !sliderControls.isEmpty {
                    let lengths = Set(sliderControls.map(\.sliderTrackLength))
                    Stepper(
                        lengths.count > 1 ? "Length: Mixed" : "Length: \(Int(lengths.first ?? EurorackConstants.defaultSliderTrackLength)) pt",
                        value: Binding(
                            get: { lengths.min() ?? EurorackConstants.defaultSliderTrackLength },
                            set: { viewModel.setSelectedControlsSliderTrackLength($0) }
                        ),
                        in: 10...200, step: 1
                    )
                }

                let switchControls = selectedControls.filter { $0.kind == .toggleSwitch || $0.kind == .slider }
                if !switchControls.isEmpty {
                    let orientations = Set(switchControls.map(\.orientation))
                    Picker("Orientation", selection: Binding<Control.Orientation?>(
                        get: { orientations.count == 1 ? orientations.first : nil },
                        set: { if let o = $0 { viewModel.setSelectedControlsOrientation(o) } }
                    )) {
                        ForEach(Control.Orientation.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Control Label") {
                let positions = Set(selectedControls.map(\.controlLabel.position))
                Picker("Position", selection: Binding<Control.LabelPosition?>(
                    get: { positions.count == 1 ? positions.first : nil },
                    set: { if let p = $0 { viewModel.setSelectedControlsControlLabelPosition(p) } }
                )) {
                    if positions.count > 1 { Text("–").tag(Control.LabelPosition?.none) }
                    ForEach(Control.LabelPosition.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }

                let fontSizes = Set(selectedControls.map(\.controlLabel.fontSize))
                Stepper(
                    fontSizes.count > 1 ? "Size: Mixed" : "Size: \(String(format: "%.1f", fontSizes.first ?? 5.0)) pt",
                    value: Binding(
                        get: { fontSizes.min() ?? 5.0 },
                        set: { viewModel.setSelectedControlsControlLabelFontSize($0) }
                    ),
                    in: 3.0...14.0, step: 0.5
                )

                let offsets = Set(selectedControls.map(\.controlLabel.offset))
                Stepper(
                    offsets.count > 1 ? "Offset: Mixed" : "Offset: \(String(format: "%.1f", offsets.first ?? 0.0)) pt",
                    value: Binding(
                        get: { offsets.min() ?? 0.0 },
                        set: { viewModel.setSelectedControlsControlLabelOffset($0) }
                    ),
                    in: -20.0...20.0, step: 0.5
                )
            }

            let statefulControls = selectedControls.filter { $0.kind == .button || $0.kind == .toggleSwitch }
            if !statefulControls.isEmpty {
                Section("State Label") {
                    let sPositions = Set(statefulControls.map(\.stateLabel.position))
                    Picker("Position", selection: Binding<Control.LabelPosition?>(
                        get: { sPositions.count == 1 ? sPositions.first : nil },
                        set: { if let p = $0 { viewModel.setSelectedControlsStateLabelPosition(p) } }
                    )) {
                        if sPositions.count > 1 { Text("–").tag(Control.LabelPosition?.none) }
                        ForEach(Control.LabelPosition.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                    }

                    let sFontSizes = Set(statefulControls.map(\.stateLabel.fontSize))
                    Stepper(
                        sFontSizes.count > 1 ? "Size: Mixed" : "Size: \(String(format: "%.1f", sFontSizes.first ?? 5.0)) pt",
                        value: Binding(
                            get: { sFontSizes.min() ?? 5.0 },
                            set: { viewModel.setSelectedControlsStateLabelFontSize($0) }
                        ),
                        in: 3.0...14.0, step: 0.5
                    )

                    let sOffsets = Set(statefulControls.map(\.stateLabel.offset))
                    Stepper(
                        sOffsets.count > 1 ? "Offset: Mixed" : "Offset: \(String(format: "%.1f", sOffsets.first ?? 0.0)) pt",
                        value: Binding(
                            get: { sOffsets.min() ?? 0.0 },
                            set: { viewModel.setSelectedControlsStateLabelOffset($0) }
                        ),
                        in: -20.0...20.0, step: 0.5
                    )
                }
            }
        }
    }

    /// A binding to one property of a control. Writes go through the view model, so
    /// consecutive edits to the same field (typing, stepper clicks) are one undo step.
    func controlBinding<T>(_ id: UUID, _ keyPath: WritableKeyPath<Control, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { viewModel.selectedModule?.controls.first(where: { $0.id == id })?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                viewModel.editControl(id, field: "\(keyPath)") { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    /// Position, size and offset editors for a control or state label.
    @ViewBuilder func labelConfigEditor(_ id: UUID, _ keyPath: WritableKeyPath<Control, Control.LabelConfig>, current: Control.LabelConfig) -> some View {
        Picker("Position", selection: controlBinding(id, keyPath.appending(path: \.position), default: .below)) {
            ForEach(Control.LabelPosition.allCases, id: \.self) { pos in
                Text(pos.rawValue).tag(pos)
            }
        }
        if current.position != .disabled {
            Stepper("Size: \(String(format: "%.1f", current.fontSize)) pt",
                    value: controlBinding(id, keyPath.appending(path: \.fontSize), default: 5.0),
                    in: 3.0...14.0, step: 0.5)
            Stepper("Offset: \(String(format: "%.1f", current.offset)) pt",
                    value: controlBinding(id, keyPath.appending(path: \.offset), default: 0.0),
                    in: -20.0...20.0, step: 0.5)
        }
    }
}
