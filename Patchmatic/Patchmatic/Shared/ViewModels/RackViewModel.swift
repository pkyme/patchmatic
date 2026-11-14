import SwiftUI

@MainActor
@Observable
final class RackViewModel: EditSessionOwner, CommittedStateRestoring, EditCommitting {
    /// Allowed canvas zoom
    static let zoomRange: ClosedRange<CGFloat> = 0.25...5.0
    /// Zoom factor of one zoom in or out step
    static let zoomStep: CGFloat = 1.25

    /// Resets stored zoom and pan that are out of range or not finite, which would
    /// otherwise break layout during window restoration.
    static func sanitizeStoredCanvasState() {
        let defaults = UserDefaults.standard
        if let z = defaults.object(forKey: AppSettings.canvasZoom) as? CGFloat,
           !z.isFinite || !zoomRange.contains(z) {
            defaults.set(1.0, forKey: AppSettings.canvasZoom)
            defaults.set(0.0, forKey: AppSettings.canvasPanOffsetX)
            defaults.set(0.0, forKey: AppSettings.canvasPanOffsetY)
        }
        for key in [AppSettings.canvasPanOffsetX, AppSettings.canvasPanOffsetY] {
            if let v = defaults.object(forKey: key) as? CGFloat, !v.isFinite {
                defaults.set(0.0, forKey: key)
            }
        }
    }

    /// `value` limited to `zoomRange`, or 1 when missing or not finite.
    static func clampedZoom(_ value: CGFloat?) -> CGFloat {
        guard let value, value.isFinite, value > 0 else { return 1.0 }
        return min(max(value, zoomRange.lowerBound), zoomRange.upperBound)
    }

    var document: PatchmaticDocument
    var canvasZoom: CGFloat = RackViewModel.clampedZoom(UserDefaults.standard.object(forKey: AppSettings.canvasZoom) as? CGFloat) {
        didSet { scheduleCanvasStateSave() }
    }
    var canvasLastZoom: CGFloat = RackViewModel.clampedZoom(UserDefaults.standard.object(forKey: AppSettings.canvasZoom) as? CGFloat)
    var canvasPanOffset: CGSize = {
        let x = UserDefaults.standard.object(forKey: AppSettings.canvasPanOffsetX) as? CGFloat ?? 0
        let y = UserDefaults.standard.object(forKey: AppSettings.canvasPanOffsetY) as? CGFloat ?? 0
        return CGSize(width: x, height: y)
    }() {
        didSet { scheduleCanvasStateSave() }
    }
    var canvasLastPanOffset: CGSize = {
        let x = UserDefaults.standard.object(forKey: AppSettings.canvasPanOffsetX) as? CGFloat ?? 0
        let y = UserDefaults.standard.object(forKey: AppSettings.canvasPanOffsetY) as? CGFloat ?? 0
        return CGSize(width: x, height: y)
    }()
    var backgroundImageOpacity: Double = UserDefaults.standard.object(forKey: AppSettings.backgroundImageOpacity) as? Double ?? 0.5 {
        didSet { UserDefaults.standard.set(backgroundImageOpacity, forKey: AppSettings.backgroundImageOpacity) }
    }
    var showLabels: Bool = UserDefaults.standard.object(forKey: AppSettings.showLabels) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showLabels, forKey: AppSettings.showLabels) }
    }
    var showPatchNumbers: Bool = UserDefaults.standard.object(forKey: AppSettings.showPatchNumbers) as? Bool ?? false {
        didSet { UserDefaults.standard.set(showPatchNumbers, forKey: AppSettings.showPatchNumbers) }
    }
    var caseHeaderHeight: CGFloat = 0
    var moduleStripHeight: CGFloat = UserDefaults.standard.object(forKey: AppSettings.moduleStripHeight) as? CGFloat ?? 140 {
        didSet { scheduleCanvasStateSave() }
    }
    var moduleStripDragStartHeight: CGFloat = UserDefaults.standard.object(forKey: AppSettings.moduleStripHeight) as? CGFloat ?? 140

    /// Pending save of zoom, pan and strip height, which change on every gesture frame
    @ObservationIgnored var canvasStateSave: DispatchWorkItem?

    func scheduleCanvasStateSave() {
        canvasStateSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveCanvasState() }
        canvasStateSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// Writes zoom, pan and strip height to UserDefaults now, e.g. before quitting.
    func saveCanvasState() {
        canvasStateSave?.cancel()
        canvasStateSave = nil
        let defaults = UserDefaults.standard
        defaults.set(canvasZoom, forKey: AppSettings.canvasZoom)
        defaults.set(canvasPanOffset.width, forKey: AppSettings.canvasPanOffsetX)
        defaults.set(canvasPanOffset.height, forKey: AppSettings.canvasPanOffsetY)
        defaults.set(moduleStripHeight, forKey: AppSettings.moduleStripHeight)
    }

    let editSession = EditSession()
    var originalPatchSnapshots: [UUID: Data] = [:]
    // MARK: - Edit session forwarding

    var pendingRackSelectionID: UUID? {
        get { editSession.pendingSelectionID }
        set { editSession.pendingSelectionID = newValue }
    }
    var pendingSaveConfirmation: Bool {
        get { editSession.pendingSaveConfirmation }
        set { editSession.pendingSaveConfirmation = newValue }
    }

    /// Rack whose name is being edited in the rack list
    var renamingRackID: UUID?

    var selectedPlacedModuleIDs: Set<UUID> = []
    var selectedCaseIDs: Set<UUID> = []
    /// Marquee rectangle in rack coordinates (unzoomed)
    var marqueeRect: CGRect?

    var caseDragStartPositions: [UUID: CGPoint] = [:]
    var caseDragAnchor: CGPoint = .zero

    let caseSnapGrid: CGFloat = EurorackConstants.pointsPerHP * 8  // 8HP = 80pts
    let caseSnapThresholdPx: CGFloat = 10                           // screen pixels

    var moduleDragID: UUID?
    var moduleDragPoint: CGPoint?
    var moduleDragGrabOffset: CGSize = .zero
    var dropIndicator: DropIndicator?
    var moduleWidthCache: [UUID: Int] = [:]
    /// Additional modules being dragged along with the primary (multi-module drag)
    var multiDragIDs: Set<UUID> = []
    var multiDragOriginalPositions: [UUID: (row: Int, hp: Int)] = [:]

    /// Definition being dragged from the library strip (not yet placed)
    var newModuleDragDefinitionID: UUID?
    var newModuleDragPoint: CGPoint?
    /// Raw screen-space point for ghost overlay (not divided by zoom)
    var newModuleDragScreenPoint: CGPoint?
    // MARK: - Edit session

    func beginEditing() {
        guard let rack = document.activeRack,
              let snap = jsonSnapshot(rack) else { return }
        editSession.beginEditing(snapshot: snap)
        guard editSession.isEditing else { return }
        for patch in document.patches where patch.rackID == rack.id {
            originalPatchSnapshots[patch.id] = jsonSnapshot(patch)
        }
    }

    /// Prepares an undoable edit. Use `grouped: true` for drag sessions
    /// so all intermediate changes collapse into one undo step.
    func prepareEdit(grouped: Bool = false) {
        beginEditing()
        if grouped { undoManager?.beginUndoGrouping() }
        recordUndoSnapshot()
    }

    func commitEditing() {
        // Screen images of removed modules are only deleted now, so discard and undo can restore them
        let originalFilenames = originalPatchSnapshots.values
            .compactMap { restoreFromSnapshot($0, as: Patch.self) }
            .reduce(into: Set<String>()) { $0.formUnion($1.screenImageFilenames) }
        let currentFilenames = document.patches.reduce(into: Set<String>()) { $0.formUnion($1.screenImageFilenames) }
        for filename in originalFilenames.subtracting(currentFilenames) { ImageStore.delete(filename) }
        editSession.commitEditing()
        originalPatchSnapshots = [:]
    }

    func requestCommit() {
        if inUseWarning != nil { pendingSaveConfirmation = true } else { commitEditing() }
    }

    /// Warning to show before saving edits to a rack that patches are built on
    var inUseWarning: String? {
        guard isEditing, let rack = document.activeRack,
              document.patches.contains(where: { $0.rackID == rack.id }) else { return nil }
        return "This rack has patches associated with it. Saving changes may affect those patches."
    }

    func restoreCommittedState(in document: PatchmaticDocument) {
        if let data = editSession.snapshot,
           let original = restoreFromSnapshot(data, as: Rack.self),
           let idx = document.racks.firstIndex(where: { $0.id == original.id }) {
            document.racks[idx] = original
        }
        for (id, data) in originalPatchSnapshots {
            if let patch = restoreFromSnapshot(data, as: Patch.self),
               let idx = document.patches.firstIndex(where: { $0.id == id }) {
                document.patches[idx] = patch
            }
        }
    }

    func discardEditing() {
        if let data = editSession.discardEditing(),
           let original = restoreFromSnapshot(data, as: Rack.self),
           let dst = document.racks.first(where: { $0.id == original.id }) {
            applyRackSnapshot(original, to: dst)
        }
        for (id, data) in originalPatchSnapshots {
            if let original = restoreFromSnapshot(data, as: Patch.self),
               let patch = document.patches.first(where: { $0.id == id }) {
                patch.restoreContents(from: original)
            }
        }
        originalPatchSnapshots = [:]
    }

    func confirmSelectionChange(save: Bool) {
        if save { commitEditing() } else { discardEditing() }
        if let id = editSession.pendingSelectionID {
            document.activeRackID = id
            editSession.pendingSelectionID = nil
        }
    }

    func cancelSelectionChange() {
        editSession.cancelSelectionChange()
    }
    // MARK: - Undo helpers

    /// Undo state for a rack edit: the rack and its patches, since removing modules also
    /// removes their cables, notes and screen images from those patches.
    struct RackUndoState: Codable {
        var rack: Rack
        var patches: [Patch]
    }

    func undoSnapshot(rackID: UUID) -> Data? {
        guard let rack = document.racks.first(where: { $0.id == rackID }) else { return nil }
        return jsonSnapshot(RackUndoState(rack: rack, patches: document.patches.filter { $0.rackID == rackID }))
    }

    func recordUndoSnapshot() {
        guard let rackID = document.activeRack?.id else { return }
        editSession.recordSnapshotUndo(
            target: self,
            capture: { vm in vm.undoSnapshot(rackID: rackID) },
            apply: { vm, data in
                guard let restored = restoreFromSnapshot(data, as: RackUndoState.self) else { return }
                if let rack = vm.document.racks.first(where: { $0.id == rackID }) {
                    vm.applyRackSnapshot(restored.rack, to: rack)
                }
                for original in restored.patches {
                    vm.document.patches.first(where: { $0.id == original.id })?.restoreContents(from: original)
                }
            }
        )
    }

    func applyRackSnapshot(_ src: Rack, to dst: Rack) {
        dst.name = src.name
        // Mutate existing Case objects in-place so views observing their
        // individual properties (e.g. placedModules) receive direct notifications.
        var updatedCases: [Case] = []
        for srcCase in src.cases {
            if let dstCase = dst.cases.first(where: { $0.id == srcCase.id }) {
                dstCase.name = srcCase.name
                dstCase.rows = srcCase.rows
                dstCase.rowWidthHP = srcCase.rowWidthHP
                dstCase.placedModules = srcCase.placedModules
                dstCase.positionX = srcCase.positionX
                dstCase.positionY = srcCase.positionY
                updatedCases.append(dstCase)
            } else {
                updatedCases.append(srcCase)
            }
        }
        dst.cases = updatedCases
    }

    init(document: PatchmaticDocument) {
        self.document = document
    }

    var rack: Rack? { document.activeRack }
}
