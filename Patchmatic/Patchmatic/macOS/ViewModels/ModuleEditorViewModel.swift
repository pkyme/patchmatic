import SwiftUI

@MainActor
@Observable
final class ModuleEditorViewModel: EditSessionOwner, CommittedStateRestoring, EditCommitting {
    /// Allowed module editor canvas zoom
    static let zoomRange: ClosedRange<CGFloat> = 1.0...8.0
    /// Zoom factor of one zoom in or out step
    static let zoomStep: CGFloat = 1.25

    /// Multiplies the canvas zoom by `factor`, within `zoomRange`.
    func zoom(by factor: CGFloat) {
        canvasZoom = min(max(canvasZoom * factor, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }

    var document: PatchmaticDocument
    var selectedModuleIDs: Set<UUID> = []
    /// Selection waiting for the user to save or discard uncommitted edits
    var pendingModuleSelection: Set<UUID>?
    var selectedControlIDs: Set<UUID> = []
    /// Set to move focus to the selected module's name field
    var renameModuleRequested = false
    var showingImageImporter = false
    var showingBackgroundImagePicker = false
    var placingControlKind: Control.Kind?
    var backgroundImage: PlatformImage? {
        didSet { backgroundCGImage = backgroundImage?.platformCGImage }
    }
    /// `backgroundImage` as a CGImage, converted once rather than on every canvas redraw
    private(set) var backgroundCGImage: CGImage?
    var gridDivisions: Int = 8
    var showGrid: Bool = false
    var snapToGrid: Bool = false
    var backgroundOpacity: Double = 1.0
    var canvasZoom: CGFloat = 1.0
    var showControls: Bool = true
    var showDetections: Bool = false
    var detections: [Detection] = []
    var highlightedDetectionID: UUID?
    var pendingDeleteModuleIDs: Set<UUID>?

    let editSession = EditSession()
    var controlDragSnapshotPending: Bool = false
    // MARK: - Edit session forwarding

    var pendingSaveConfirmation: Bool {
        get { editSession.pendingSaveConfirmation }
        set { editSession.pendingSaveConfirmation = newValue }
    }

    func beginEditing() {
        guard let module = selectedModule,
              let snap = jsonSnapshot(module) else { return }
        editSession.beginEditing(snapshot: snap)
    }

    /// Prepares an undoable edit. Use `grouped: true` for drag sessions
    /// so all intermediate changes collapse into one undo step.
    func prepareEdit(grouped: Bool = false) {
        beginEditing()
        if grouped { undoManager?.beginUndoGrouping() }
        recordUndoSnapshot()
        lastControlEditField = nil
    }

    /// Field of the last `editControl` call, so repeated edits to it share one undo step
    @ObservationIgnored var lastControlEditField: String?

    /// Applies an inspector edit to one control of the selected module. Consecutive
    /// edits to the same `field` of the same control are one undo step; pass nil for
    /// edits that should always be their own step.
    func editControl(_ id: UUID, field: String?, _ mutate: (inout Control) -> Void) {
        guard let module = selectedModule,
              let index = module.controls.firstIndex(where: { $0.id == id }) else { return }
        let key = field.map { "\(id)-\($0)" }
        if key == nil || key != lastControlEditField || !isEditing {
            prepareEdit()
        }
        lastControlEditField = key
        mutate(&module.controls[index])
    }

    func commitEditing() {
        editSession.commitEditing()
    }

    func requestCommit() {
        if inUseWarning != nil { pendingSaveConfirmation = true } else { commitEditing() }
    }

    /// Warning to show before saving edits to a module that is placed in racks
    var inUseWarning: String? {
        guard isEditing, let module = selectedModule, document.isModuleInUse(module.id) else { return nil }
        return "This module is placed in one or more racks. Changes to its definition will affect all existing placements."
    }

    func restoreCommittedState(in document: PatchmaticDocument) {
        guard let data = editSession.snapshot,
              let original = restoreFromSnapshot(data, as: ModuleDefinition.self),
              let idx = document.moduleLibrary.firstIndex(where: { $0.id == original.id })
        else { return }
        document.moduleLibrary[idx] = original
    }

    func discardEditing() {
        guard let data = editSession.discardEditing(),
              let original = restoreFromSnapshot(data, as: ModuleDefinition.self),
              let idx = document.moduleLibrary.firstIndex(where: { $0.id == original.id })
        else { return }
        document.moduleLibrary[idx] = original
    }

    func requestSelectModule(_ id: UUID) {
        requestSelectModules([id])
    }

    /// Changes the selection, first asking to save or discard any uncommitted edits.
    func requestSelectModules(_ ids: Set<UUID>) {
        guard ids != selectedModuleIDs else { return }
        if isEditing {
            pendingModuleSelection = ids
        } else {
            selectedModuleIDs = ids
        }
    }

    func confirmSelectionChange(save: Bool) {
        if save { commitEditing() } else { discardEditing() }
        if let ids = pendingModuleSelection {
            selectedModuleIDs = ids
            pendingModuleSelection = nil
        }
    }

    func cancelSelectionChange() {
        pendingModuleSelection = nil
    }

    init(document: PatchmaticDocument) {
        self.document = document
    }

    /// Backward-compatible single selection (returns the ID when exactly one is selected)
    var selectedControlID: UUID? {
        selectedControlIDs.count == 1 ? selectedControlIDs.first : nil
    }

    var selectedModuleID: UUID? {
        selectedModuleIDs.count == 1 ? selectedModuleIDs.first : nil
    }

    var selectedModule: ModuleDefinition? {
        guard let id = selectedModuleID else { return nil }
        return document.moduleLibrary.first { $0.id == id }
    }

    func loadBackgroundImage() {
        guard let module = selectedModule, let filename = module.imageFileName else {
            backgroundImage = nil
            return
        }
        backgroundImage = ImageStore.load(filename)
    }
    // MARK: - Undo helpers

    func recordUndoSnapshot() {
        guard let moduleID = selectedModule?.id else { return }
        editSession.recordSnapshotUndo(
            target: self,
            capture: { vm in vm.document.moduleLibrary.first { $0.id == moduleID }.flatMap(jsonSnapshot) },
            apply: { vm, data in
                vm.lastControlEditField = nil
                if let restored = restoreFromSnapshot(data, as: ModuleDefinition.self) {
                    vm.applyModuleSnapshot(restored, id: moduleID)
                }
            }
        )
    }

    func applyModuleSnapshot(_ src: ModuleDefinition, id: UUID) {
        guard let dst = document.moduleLibrary.first(where: { $0.id == id }) else { return }
        dst.name      = src.name
        dst.format    = src.format
        dst.widthHP   = src.widthHP
        dst.controls  = src.controls
        dst.imageFileName = src.imageFileName
    }
    // MARK: - Selection

    func selectControl(_ id: UUID, extending: Bool) {
        if extending {
            if selectedControlIDs.contains(id) {
                selectedControlIDs.remove(id)
            } else {
                selectedControlIDs.insert(id)
            }
        } else {
            selectedControlIDs = [id]
        }
    }

    func selectControls(_ ids: Set<UUID>) {
        selectedControlIDs = ids
    }

    func clearSelection() {
        selectedControlIDs = []
    }

    func selectAllControls() {
        guard let module = selectedModule else { return }
        selectedControlIDs = Set(module.controls.map(\.id))
    }

    func duplicateSelectedControls() {
        guard let module = selectedModule, !selectedControlIDs.isEmpty else { return }
        prepareEdit()
        var newIDs = Set<UUID>()
        for controlID in selectedControlIDs {
            guard let original = module.controls.first(where: { $0.id == controlID }) else { continue }
            let offset = 0.03
            let newPos = NormalizedPoint(
                x: min(1.0, original.position.x + offset),
                y: min(1.0, original.position.y + offset)
            )
            var copy = original
            copy.id = UUID()
            copy.position = newPos
            module.controls.append(copy)
            newIDs.insert(copy.id)
        }
        selectedControlIDs = newIDs
    }

    /// Known physical diameter of a 3.5mm audio jack panel cutout in mm
    static let jackDiameterMM: Double = 9.0
    /// Midpoint between 1U and 3U for format classification
    static let formatThresholdMM: Double = (RowSize.threeU.heightMM + RowSize.oneU.heightMM) / 2
}
