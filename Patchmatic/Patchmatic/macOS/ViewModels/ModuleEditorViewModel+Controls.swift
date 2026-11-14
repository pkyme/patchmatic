import SwiftUI

extension ModuleEditorViewModel {
    // MARK: - Grid Snapping

    /// `point` moved to the nearest grid intersection when snap to grid is on.
    func snapped(_ point: NormalizedPoint) -> NormalizedPoint {
        guard snapToGrid, let module = selectedModule else { return point }
        return Self.snap(point, toGridOf: module, divisions: gridDivisions)
    }

    /// `point` moved to the nearest intersection of a square grid with `divisions`
    /// cells along the panel's shorter side.
    static func snap(_ point: NormalizedPoint, toGridOf module: ModuleDefinition, divisions: Int) -> NormalizedPoint {
        guard divisions >= 2 else { return point }
        let panelWidth = Double(EurorackConstants.width(forHP: module.widthHP))
        let panelHeight = Double(module.panelHeight)
        let cellSize = min(panelWidth, panelHeight) / Double(divisions)
        return NormalizedPoint(
            x: ((point.x * panelWidth) / cellSize).rounded() * cellSize / panelWidth,
            y: ((point.y * panelHeight) / cellSize).rounded() * cellSize / panelHeight
        )
    }
    // MARK: - Control drag grouping

    func beginControlDrag() {
        beginEditing()
        undoManager?.beginUndoGrouping()
        controlDragSnapshotPending = true
    }

    func endControlDrag() {
        controlDragSnapshotPending = false
        undoManager?.endUndoGrouping()
    }

    /// Starts editing and, on the first change of a drag, records the undo snapshot so
    /// the whole drag is one undo step.
    func recordDragSnapshotIfNeeded() {
        beginEditing()
        if controlDragSnapshotPending {
            recordUndoSnapshot()
            controlDragSnapshotPending = false
        }
    }
    // MARK: - Control CRUD

    func addControl(kind: Control.Kind, at normalizedPosition: NormalizedPoint) {
        guard let module = selectedModule else { return }
        prepareEdit()
        let label = kind.defaultLabel
        let screenWidth = kind == .screen ? EurorackConstants.defaultScreenWidth : 0.0
        let screenHeight = kind == .screen ? EurorackConstants.defaultScreenHeight : 0.0
        let control = Control(kind: kind, label: label, position: snapped(normalizedPosition), screenWidth: screenWidth, screenHeight: screenHeight)
        module.controls.append(control)
        selectedControlIDs = [control.id]
    }

    func deleteSelectedControls() {
        guard let module = selectedModule else { return }
        prepareEdit()
        module.controls.removeAll { selectedControlIDs.contains($0.id) }
        selectedControlIDs = []
    }

    func moveControl(_ controlID: UUID, to position: NormalizedPoint) {
        guard let module = selectedModule,
              let index = module.controls.firstIndex(where: { $0.id == controlID }) else { return }
        let newPosition = snapped(position)
        let current = module.controls[index].position
        let ddx = newPosition.x - current.x
        let ddy = newPosition.y - current.y
        guard ddx * ddx + ddy * ddy > 1e-6 else { return }
        recordDragSnapshotIfNeeded()
        module.controls[index].position = newPosition
    }

    func moveSelectedControls(dx: Double, dy: Double) {
        guard dx * dx + dy * dy > 1e-10 else { return }
        recordDragSnapshotIfNeeded()
        guard let module = selectedModule else { return }
        for i in module.controls.indices {
            if selectedControlIDs.contains(module.controls[i].id) {
                let newX = module.controls[i].position.x + dx
                let newY = module.controls[i].position.y + dy
                module.controls[i].position = snapped(NormalizedPoint(x: newX, y: newY))
            }
        }
    }
    // MARK: - Batch Operations

    /// Applies `mutate` to each selected control matching `filter`, as one undo step.
    func updateSelectedControls(where filter: (Control) -> Bool = { _ in true },
                                        _ mutate: (inout Control) -> Void) {
        guard let module = selectedModule else { return }
        prepareEdit()
        for i in module.controls.indices
        where selectedControlIDs.contains(module.controls[i].id) && filter(module.controls[i]) {
            mutate(&module.controls[i])
        }
    }

    static func hasStates(_ control: Control) -> Bool {
        control.kind == .button || control.kind == .toggleSwitch
    }

    func setSelectedControlsSize(_ size: Control.Size) {
        updateSelectedControls(where: { $0.kind != .patchPoint }) { $0.size = size }
    }

    /// Labels the selected controls `prefix1`, `prefix2`, … in panel order.
    func numberSelectedControls(prefix: String) {
        guard let module = selectedModule, !selectedControlIDs.isEmpty else { return }
        prepareEdit()
        var number = 1
        for i in module.controls.indices where selectedControlIDs.contains(module.controls[i].id) {
            module.controls[i].label = "\(prefix)\(number)"
            number += 1
        }
    }

    func setSelectedControlsKind(_ kind: Control.Kind) {
        setControlsKind(kind, ids: selectedControlIDs)
    }

    /// Changes the kind of the given controls, updating default labels and giving
    /// new screens a default size.
    func setControlsKind(_ kind: Control.Kind, ids: Set<UUID>) {
        guard let module = selectedModule else { return }
        prepareEdit()
        for i in module.controls.indices {
            if ids.contains(module.controls[i].id) {
                let oldKind = module.controls[i].kind
                if module.controls[i].label == oldKind.defaultLabel {
                    module.controls[i].label = kind.defaultLabel
                }
                module.controls[i].kind = kind
                if kind == .screen && (module.controls[i].screenWidth <= 0 || module.controls[i].screenHeight <= 0) {
                    module.controls[i].screenWidth = EurorackConstants.defaultScreenWidth
                    module.controls[i].screenHeight = EurorackConstants.defaultScreenHeight
                }
            }
        }
    }

    func setSelectedControlsOrientation(_ orientation: Control.Orientation) {
        updateSelectedControls(where: { $0.kind == .toggleSwitch || $0.kind == .slider }) { $0.orientation = orientation }
    }

    func resizeControlScreen(_ id: UUID, width: CGFloat, height: CGFloat, center: NormalizedPoint) {
        guard let module = selectedModule,
              let index = module.controls.firstIndex(where: { $0.id == id }) else { return }
        recordDragSnapshotIfNeeded()
        module.controls[index].screenWidth = max(5, Double(width))
        module.controls[index].screenHeight = max(5, Double(height))
        module.controls[index].position = center
    }

    func resizeControlSlider(_ id: UUID, length: CGFloat, center: NormalizedPoint) {
        guard let module = selectedModule,
              let index = module.controls.firstIndex(where: { $0.id == id }) else { return }
        recordDragSnapshotIfNeeded()
        module.controls[index].sliderTrackLength = max(10, Double(length))
        module.controls[index].position = center
    }

    func setSelectedControlsSliderTrackLength(_ length: Double) {
        updateSelectedControls(where: { $0.kind == .slider }) { $0.sliderTrackLength = length }
    }

    func setSelectedControlsScreenWidth(_ width: Double) {
        updateSelectedControls(where: { $0.kind == .screen }) { $0.screenWidth = width }
    }

    func setSelectedControlsScreenHeight(_ height: Double) {
        updateSelectedControls(where: { $0.kind == .screen }) { $0.screenHeight = height }
    }

    func setSelectedControlsControlLabelPosition(_ position: Control.LabelPosition) {
        updateSelectedControls { $0.controlLabel.position = position }
    }

    func setSelectedControlsControlLabelFontSize(_ size: Double) {
        updateSelectedControls { $0.controlLabel.fontSize = size }
    }

    func setSelectedControlsControlLabelOffset(_ offset: Double) {
        updateSelectedControls { $0.controlLabel.offset = offset }
    }

    func setSelectedControlsStateLabelPosition(_ position: Control.LabelPosition) {
        updateSelectedControls(where: Self.hasStates) { $0.stateLabel.position = position }
    }

    func setSelectedControlsStateLabelFontSize(_ size: Double) {
        updateSelectedControls(where: Self.hasStates) { $0.stateLabel.fontSize = size }
    }

    func setSelectedControlsStateLabelOffset(_ offset: Double) {
        updateSelectedControls(where: Self.hasStates) { $0.stateLabel.offset = offset }
    }
    // MARK: - Layout Operations

    /// Spaces three or more selected controls evenly between the outermost two along `axis`.
    func distributeSelected(along axis: WritableKeyPath<NormalizedPoint, Double>) {
        guard let module = selectedModule, selectedControlIDs.count >= 3 else { return }
        prepareEdit()
        let indices = module.controls.indices
            .filter { selectedControlIDs.contains(module.controls[$0].id) }
            .sorted { module.controls[$0].position[keyPath: axis] < module.controls[$1].position[keyPath: axis] }
        guard let first = indices.first, let last = indices.last else { return }
        let start = module.controls[first].position[keyPath: axis]
        let step = (module.controls[last].position[keyPath: axis] - start) / Double(indices.count - 1)
        for (i, index) in indices.enumerated() {
            module.controls[index].position[keyPath: axis] = start + step * Double(i)
        }
    }

    /// Moves two or more selected controls to their average position along `axis`.
    func centerSelected(along axis: WritableKeyPath<NormalizedPoint, Double>) {
        guard let module = selectedModule, selectedControlIDs.count >= 2 else { return }
        let selected = module.controls.filter { selectedControlIDs.contains($0.id) }
        let average = selected.map { $0.position[keyPath: axis] }.reduce(0, +) / Double(selected.count)
        updateSelectedControls { $0.position[keyPath: axis] = average }
    }

    func distributeSelectedHorizontally() { distributeSelected(along: \.x) }
    func distributeSelectedVertically() { distributeSelected(along: \.y) }
    func centerSelectedHorizontally() { centerSelected(along: \.x) }
    func centerSelectedVertically() { centerSelected(along: \.y) }

    func snapSelectedToGrid(divisions: Int) {
        guard let module = selectedModule, divisions >= 2 else { return }
        updateSelectedControls { $0.position = Self.snap($0.position, toGridOf: module, divisions: divisions) }
    }
}
