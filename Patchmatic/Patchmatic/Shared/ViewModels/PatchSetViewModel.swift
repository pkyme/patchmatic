import SwiftUI

@MainActor
@Observable
final class PatchSetViewModel {
    var document: PatchmaticDocument
    /// Set whose name is being edited in the set list
    var renamingSetID: UUID?
    /// Set awaiting delete confirmation
    var pendingDeleteSet: PatchSet?
    weak var undoManager: UndoManager?

    init(document: PatchmaticDocument) {
        self.document = document
        if let set = activeSet, let id = document.activePatchID,
           let index = set.patchIDs.firstIndex(of: id) {
            patchIndex = index
        }
    }

    var activeSet: PatchSet? {
        guard let id = document.activeSetID else { return nil }
        return document.sets.first { $0.id == id }
    }

    /// The currently displayed patch within the active set
    var currentPatch: Patch? {
        guard let set = activeSet,
              let index = currentIndex,
              index < set.patchIDs.count else { return nil }
        let patchID = set.patchIDs[index]
        return document.patches.first { $0.id == patchID }
    }

    /// Position of the displayed patch in the active set. Kept separately from the
    /// document's active patch, which Patches mode also changes.
    private var patchIndex = 0

    var currentIndex: Int? {
        guard let set = activeSet, !set.patchIDs.isEmpty else { return nil }
        return min(patchIndex, set.patchIDs.count - 1)
    }

    var canGoBack: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }

    var canGoForward: Bool {
        guard let set = activeSet, let index = currentIndex else { return false }
        return index < set.patchIDs.count - 1
    }

    // MARK: - Navigation

    func goToNext() {
        guard let index = currentIndex else { return }
        goTo(index: index + 1)
    }

    func goToPrevious() {
        guard let index = currentIndex else { return }
        goTo(index: index - 1)
    }

    func goTo(index: Int) {
        guard let set = activeSet,
              index >= 0, index < set.patchIDs.count else { return }
        patchIndex = index
        let patchID = set.patchIDs[index]
        document.activePatchID = patchID
        if let patch = document.patches.first(where: { $0.id == patchID }) {
            document.activeRackID = patch.rackID
        }
    }

    /// Makes the document's active patch the one Sets mode is showing, e.g. after
    /// returning from Patches mode.
    func showCurrentPatch() {
        if let index = currentIndex { goTo(index: index) }
    }

    /// Applies a saved selection, falling back to the first set and its first patch
    /// when the saved IDs no longer exist in the document.
    func restoreSelection(setID: UUID?, patchID: UUID?) {
        guard let set = document.sets.first(where: { $0.id == setID }) ?? document.sets.first else {
            document.activeSetID = nil
            return
        }
        document.activeSetID = set.id
        goTo(index: patchID.flatMap { set.patchIDs.firstIndex(of: $0) } ?? 0)
    }

    // MARK: - Set CRUD

    func addSet() {
        let name = GeometryHelpers.uniqueName("New Set", among: document.sets.map(\.name))
        let set = PatchSet(name: name)
        document.sets.append(set)
        document.activeSetID = set.id
        patchIndex = 0
    }

    func requestDeleteSet(_ set: PatchSet) {
        pendingDeleteSet = set
    }

    func confirmDeleteSet() {
        guard let set = pendingDeleteSet else { return }
        pendingDeleteSet = nil
        deleteSet(set)
    }

    /// Removes a set as an undoable action. Its patches are not affected.
    func deleteSet(_ set: PatchSet) {
        guard let index = document.sets.firstIndex(where: { $0.id == set.id }) else { return }
        let wasActive = document.activeSetID == set.id
        let previousPatchIndex = patchIndex
        document.sets.remove(at: index)
        if wasActive {
            document.activeSetID = document.sets.first?.id
            patchIndex = 0
        }
        undoManager?.registerGroupedUndo(target: self, actionName: "Delete Set") { target in
            target.restoreDeletedSet(set, at: index, makeActive: wasActive, patchIndex: previousPatchIndex)
        }
    }

    private func restoreDeletedSet(_ set: PatchSet, at index: Int, makeActive: Bool, patchIndex: Int) {
        guard !document.sets.contains(where: { $0.id == set.id }) else { return }
        document.sets.insert(set, at: min(index, document.sets.count))
        // Patches may have been deleted since the set was
        document.removeMissingPatchesFromSets()
        if makeActive {
            document.activeSetID = set.id
            self.patchIndex = patchIndex
        }
        undoManager?.registerGroupedUndo(target: self, actionName: "Delete Set") { target in
            target.deleteSet(set)
        }
    }

    func selectSet(_ set: PatchSet) {
        document.activeSetID = set.id
        patchIndex = 0
        showCurrentPatch()
    }

    func renameSet(_ set: PatchSet, to newName: String) {
        let others = document.sets.filter { $0.id != set.id }.map(\.name)
        set.name = GeometryHelpers.uniqueName(newName, among: others)
    }

    // MARK: - Set editing

    func addPatchToSet(_ patch: Patch) {
        guard let set = activeSet else { return }
        set.patchIDs.append(patch.id)
    }

    func removePatchFromSet(at index: Int) {
        guard let set = activeSet, index < set.patchIDs.count else { return }
        set.patchIDs.remove(at: index)
        if index < patchIndex { patchIndex -= 1 }
    }

    func movePatchInSet(from source: IndexSet, to destination: Int) {
        guard let set = activeSet else { return }
        // Keep showing the same entry after the move
        var positions = Array(set.patchIDs.indices)
        positions.move(fromOffsets: source, toOffset: destination)
        set.patchIDs.move(fromOffsets: source, toOffset: destination)
        if let current = currentIndex, let moved = positions.firstIndex(of: current) {
            patchIndex = moved
        }
    }

    /// Patches available to add (exist in document but not yet in this set)
    var availablePatches: [Patch] {
        guard let set = activeSet else { return [] }
        let existing = Set(set.patchIDs)
        return document.patches.filter { !existing.contains($0.id) }
    }

    /// Resolved patches for the active set (in order, skipping any with missing IDs)
    var resolvedPatches: [(index: Int, patch: Patch)] {
        guard let set = activeSet else { return [] }
        var result: [(index: Int, patch: Patch)] = []
        for (i, patchID) in set.patchIDs.enumerated() {
            if let patch = document.patches.first(where: { $0.id == patchID }) {
                result.append((i, patch))
            }
        }
        return result
    }
}
