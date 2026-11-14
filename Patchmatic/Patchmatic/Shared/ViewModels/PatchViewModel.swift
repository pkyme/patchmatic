import SwiftUI

@MainActor
@Observable
final class PatchViewModel: EditSessionOwner, CommittedStateRestoring, EditCommitting {
    var document: PatchmaticDocument
    /// Source patch point during a cable drag
    var dragFrom: (moduleID: UUID, controlID: UUID)?
    /// Current cursor position in rack coordinates during a cable drag
    var dragCurrentPoint: CGPoint?
    /// Patch whose name is being edited in the patch list
    var renamingPatchID: UUID?
    /// Whether the active patch's notes sheet is shown
    var showingPatchNotesSheet = false
    /// Currently selected cables (shift-click)
    var selectedCableIDs: Set<UUID> = []
    /// Currently selected cable pin
    var selectedPinID: (cableID: UUID, pinID: UUID)?
    /// Whether group overlays are visible
    var showGroups: Bool = false
    var showPatchNotes: Bool = UserDefaults.standard.object(forKey: AppSettings.showPatchNotes) as? Bool ?? false {
        didSet { UserDefaults.standard.set(showPatchNotes, forKey: AppSettings.showPatchNotes) }
    }
    /// Shared audio player for patch audio previews
    let audioPlayer = AudioPlayer()
    /// Groups currently highlighted (via group list hover or module hover)
    var hoveredGroupIDs: Set<UUID> = []
    /// Group IDs highlighted because the cursor is over a module belonging to them (title buttons only, not module overlays)
    var moduleHoverGroupIDs: Set<UUID> = []
    /// Cable physics simulator, shared so hit testing can use actual rope positions
    let cableSimulator = CableSimulator()
    /// Rack layout used to position cable ropes; set by whoever creates both view models
    weak var rackVM: RackViewModel?

    /// Cable geometry for the active patch, when the rack layout is available
    var cableGeometry: CableGeometry? {
        rackVM.flatMap { CableGeometry(rackVM: $0, patchVM: self) }
    }

    func rebuildRopes(forCable cableID: UUID) {
        guard let cable = activePatch?.cables.first(where: { $0.id == cableID }) else { return }
        cableGeometry?.rebuildRopes(for: cable)
    }

    let editSession = EditSession()
    var pendingImageDeletionFilenames: [String] = []
    var pendingAudioDeletionFilenames: [String] = []
    /// Media of deleted patches whose deletion can still be undone
    let deferredMediaDeletions = NSHashTable<DeferredMediaDeletion>.weakObjects()
    /// Patch awaiting delete confirmation
    var pendingDeletePatch: Patch?
    /// Cables copied from a patch, pasteable into patches on the same rack
    var cableClipboard: CableClipboard?
    @ObservationIgnored var patchPointNumberMap: [PatchPointKey: Int] = [:]
    @ObservationIgnored var patchPointNumberMapPatchID: UUID?
    @ObservationIgnored var patchPointNumberMapOrder: [PatchPointKey] = []
    // MARK: - Edit session forwarding

    var pendingPatchSelectionID: UUID? {
        get { editSession.pendingSelectionID }
        set { editSession.pendingSelectionID = newValue }
    }

    func beginEditing() {
        guard let patch = document.activePatch,
              let snap = jsonSnapshot(patch) else { return }
        editSession.beginEditing(snapshot: snap)
    }

    /// Prepares an undoable edit. Use `grouped: true` for drag sessions
    /// so all intermediate changes collapse into one undo step.
    func prepareEdit(grouped: Bool = false) {
        beginEditing()
        if grouped { undoManager?.beginUndoGrouping() }
        recordUndoSnapshot()
    }

    func commitEditing() {
        for f in pendingImageDeletionFilenames { ImageStore.delete(f) }
        for f in pendingAudioDeletionFilenames { AudioStore.delete(f) }
        editSession.commitEditing()
        pendingImageDeletionFilenames = []
        pendingAudioDeletionFilenames = []
    }

    func restoreCommittedState(in document: PatchmaticDocument) {
        guard let data = editSession.snapshot,
              let original = restoreFromSnapshot(data, as: Patch.self),
              let idx = document.patches.firstIndex(where: { $0.id == original.id })
        else { return }
        document.patches[idx] = original
    }

    func discardEditing() {
        guard let data = editSession.discardEditing(),
              let original = restoreFromSnapshot(data, as: Patch.self),
              let current = document.activePatch
        else {
            pendingImageDeletionFilenames = []
            pendingAudioDeletionFilenames = []
            return
        }
        let originalFilenames = Set(original.screenImages.flatMap(\.imageFilenames))
        let currentFilenames = Set(current.screenImages.flatMap(\.imageFilenames))
        let toDelete = currentFilenames.subtracting(originalFilenames)
        for f in toDelete { ImageStore.delete(f) }
        if let currentAudio = current.audioPreviewFilename,
           currentAudio != original.audioPreviewFilename {
            AudioStore.delete(currentAudio)
        }
        current.restoreContents(from: original)
        pendingImageDeletionFilenames = []
        pendingAudioDeletionFilenames = []
        cableGeometry?.syncRopesAfterRestore()
    }

    func confirmSelectionChange(save: Bool) {
        if save { commitEditing() } else { discardEditing() }
        if let id = editSession.pendingSelectionID {
            if let patch = document.patches.first(where: { $0.id == id }) {
                document.activePatchID = patch.id
                document.activeRackID = patch.rackID
            }
            editSession.pendingSelectionID = nil
        }
    }

    func cancelSelectionChange() {
        editSession.cancelSelectionChange()
    }
    // MARK: - Undo helpers

    func recordUndoSnapshot() {
        guard let patchID = activePatch?.id else { return }
        editSession.recordSnapshotUndo(
            target: self,
            capture: { vm in vm.document.patches.first { $0.id == patchID }.flatMap(jsonSnapshot) },
            apply: { vm, data in
                guard let restored = restoreFromSnapshot(data, as: Patch.self),
                      let patch = vm.document.patches.first(where: { $0.id == patchID }) else { return }
                patch.restoreContents(from: restored)
                vm.cableGeometry?.syncRopesAfterRestore()
            }
        )
    }

    init(document: PatchmaticDocument) {
        self.document = document
    }

    var activePatch: Patch? {
        document.activePatch
    }

    /// Tracks an in-progress knob drag gesture
    var knobDragInfo: (moduleID: UUID, controlID: UUID, startValue: Double, startY: CGFloat)?

    /// Tracks an in-progress slider drag gesture (coordinates in un-zoomed rack space)
    var sliderDragInfo: (moduleID: UUID, controlID: UUID, centerX: CGFloat, centerY: CGFloat, trackHalf: CGFloat, isVertical: Bool)?
}

/// Deletes a removed patch's media files once nothing can restore the patch:
/// when the owning undo action is released, or when `perform()` is called.
final class DeferredMediaDeletion {
    private let imageFilenames: [String]
    private let audioFilenames: [String]
    private var isResolved = false

    init(imageFilenames: [String], audioFilenames: [String]) {
        self.imageFilenames = imageFilenames
        self.audioFilenames = audioFilenames
    }

    /// Keeps the files because the patch was restored.
    func cancel() { isResolved = true }

    func perform() {
        guard !isResolved else { return }
        isResolved = true
        for f in imageFilenames { ImageStore.delete(f) }
        for f in audioFilenames { AudioStore.delete(f) }
    }

    deinit { perform() }
}

/// Cables copied from a patch, with the rack whose module IDs they refer to
struct CableClipboard {
    let rackID: UUID
    let cables: [PatchCable]
}
