import SwiftUI

extension PatchViewModel {
    // MARK: - Patch CRUD

    func addPatch(rackID: UUID) {
        let name = GeometryHelpers.uniqueName("Patch", among: document.patches.map(\.name))
        let patch = Patch(name: name, rackID: rackID)
        document.patches.append(patch)
        document.activePatchID = patch.id
        document.activeRackID = rackID
    }

    func requestDeletePatch(_ patch: Patch) {
        pendingDeletePatch = patch
    }

    func confirmDeletePatch() {
        guard let patch = pendingDeletePatch else { return }
        pendingDeletePatch = nil
        deletePatch(patch)
    }

    /// Removes a patch as an undoable action. Its media files stay on disk until
    /// the undo action is discarded, so undo can restore the patch intact.
    func deletePatch(_ patch: Patch) {
        guard let index = document.patches.firstIndex(where: { $0.id == patch.id }) else { return }
        if isEditing && document.activePatchID == patch.id { commitEditing() }

        let setPositions = document.sets.compactMap { set in
            set.patchIDs.firstIndex(of: patch.id).map { (setID: set.id, index: $0) }
        }
        let wasActive = document.activePatchID == patch.id
        let media = DeferredMediaDeletion(
            imageFilenames: patch.screenImages.flatMap(\.imageFilenames),
            audioFilenames: patch.audioPreviewFilename.map { [$0] } ?? []
        )
        deferredMediaDeletions.add(media)

        document.patches.remove(at: index)
        document.removeMissingPatchesFromSets()
        if wasActive {
            let next = document.patches.first
            document.activePatchID = next?.id
            if let next { document.activeRackID = next.rackID }
        }

        editSession.registerGroupedUndo(target: self, actionName: "Delete Patch") { target in
            target.restoreDeletedPatch(patch, at: index, setPositions: setPositions,
                                       makeActive: wasActive, media: media)
        }
    }

    func restoreDeletedPatch(_ patch: Patch, at index: Int,
                                     setPositions: [(setID: UUID, index: Int)],
                                     makeActive: Bool, media: DeferredMediaDeletion) {
        guard !document.patches.contains(where: { $0.id == patch.id }),
              let rack = document.rack(for: patch.rackID) else { return }
        media.cancel()
        // Modules may have been removed from the rack since the patch was deleted
        patch.removeReferencesMissing(from: rack)
        document.patches.insert(patch, at: min(index, document.patches.count))
        for position in setPositions {
            guard let set = document.sets.first(where: { $0.id == position.setID }),
                  !set.patchIDs.contains(patch.id) else { continue }
            set.patchIDs.insert(patch.id, at: min(position.index, set.patchIDs.count))
        }
        if makeActive && !isEditing {
            document.activePatchID = patch.id
            document.activeRackID = patch.rackID
        }
        editSession.registerGroupedUndo(target: self, actionName: "Delete Patch") { target in
            target.deletePatch(patch)
        }
    }

    /// Deletes media held for undoable patch deletions. Called on app termination.
    func flushDeferredMediaDeletions() {
        for media in deferredMediaDeletions.allObjects { media.perform() }
    }

    func duplicatePatch(_ patch: Patch) {
        let copyName = GeometryHelpers.uniqueName("\(patch.name) Copy", among: document.patches.map(\.name))
        let copyID = UUID()
        var copiedScreenImages: [ScreenImage] = []
        for si in patch.screenImages {
            var newFilenames: [String] = []
            for oldFilename in si.imageFilenames {
                let newFilename = ImageStore.makeScreenFilename(patchID: copyID, placedModuleID: si.placedModuleID, controlID: si.controlID)
                if ImageStore.copy(oldFilename, to: newFilename) {
                    newFilenames.append(newFilename)
                }
            }
            copiedScreenImages.append(ScreenImage(
                placedModuleID: si.placedModuleID,
                controlID: si.controlID,
                imageFilenames: newFilenames,
                activeIndex: si.activeIndex
            ))
        }
        var copiedAudioFilename: String?
        if let srcFilename = patch.audioPreviewFilename {
            let ext = (srcFilename as NSString).pathExtension
            let newFilename = AudioStore.makeFilename(patchID: copyID, ext: ext)
            if AudioStore.save(from: AudioStore.url(for: srcFilename), as: newFilename) {
                copiedAudioFilename = newFilename
            }
        }
        let copy = Patch(
            id: copyID,
            name: copyName,
            rackID: patch.rackID,
            cables: patch.cables.map { var c = $0; c.id = UUID(); c.pins = c.pins.map { var p = $0; p.id = UUID(); return p }; return c },
            knobValues: patch.knobValues.map { var kv = $0; kv.id = UUID(); return kv },
            screenImages: copiedScreenImages,
            moduleNotes: patch.moduleNotes.map { var n = $0; n.id = UUID(); return n },
            patchPointOrder: patch.patchPointOrder,
            moduleGroups: patch.moduleGroups.map { var g = $0; g.id = UUID(); return g },
            patchNotes: patch.patchNotes,
            audioPreviewFilename: copiedAudioFilename
        )
        document.patches.append(copy)
        selectPatch(copy)
    }

    func selectPatch(_ patch: Patch) {
        if isEditing { pendingPatchSelectionID = patch.id }
        else {
            document.activePatchID = patch.id
            document.activeRackID = patch.rackID
        }
    }

    func renamePatch(_ patch: Patch, to newName: String) {
        let others = document.patches.filter { $0.id != patch.id }.map(\.name)
        patch.name = GeometryHelpers.uniqueName(newName, among: others)
    }
    // MARK: - Patch Notes

    func updatePatchNotes(_ text: String) {
        prepareEdit()
        activePatch?.patchNotes = text
    }

    func attachAudioPreview(from sourceURL: URL) {
        guard let patch = activePatch else { return }
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let filename = AudioStore.makeFilename(patchID: patch.id, ext: ext)
        guard AudioStore.save(from: sourceURL, as: filename) else { return }
        prepareEdit()
        if let old = patch.audioPreviewFilename {
            pendingAudioDeletionFilenames.append(old)
        }
        patch.audioPreviewFilename = filename
    }

    func removeAudioPreview() {
        guard let patch = activePatch, let filename = patch.audioPreviewFilename else { return }
        prepareEdit()
        pendingAudioDeletionFilenames.append(filename)
        patch.audioPreviewFilename = nil
    }
}
