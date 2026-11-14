import SwiftUI

extension PatchViewModel {
    // MARK: - Module Notes

    func addNote(forModule moduleID: UUID, at position: NormalizedPoint) {
        guard let patch = activePatch else { return }
        prepareEdit()
        let note = ModuleNote(placedModuleID: moduleID, position: position, text: "")
        patch.addNote(note)
    }

    func addPatchPointNote(forModule moduleID: UUID, controlID: UUID) {
        guard let patch = activePatch else { return }
        prepareEdit()
        let note = ModuleNote(placedModuleID: moduleID, controlID: controlID,
                              position: NormalizedPoint(x: 0.5, y: 0.5), text: "")
        patch.addNote(note)
    }

    func patchPointNote(forModule moduleID: UUID, controlID: UUID) -> ModuleNote? {
        activePatch?.patchPointNote(moduleID: moduleID, controlID: controlID)
    }

    func updateNote(_ note: ModuleNote, text: String) {
        prepareEdit()
        activePatch?.updateNote(note, text: text)
    }

    func deleteNote(_ note: ModuleNote) {
        prepareEdit()
        activePatch?.deleteNote(note)
    }

    func notes(forModule moduleID: UUID) -> [ModuleNote] {
        activePatch?.notes(forModule: moduleID) ?? []
    }
    // MARK: - Module Groups

    func addGroup(name: String, notes: String = "", moduleIDs: [UUID]) {
        guard let patch = activePatch else { return }
        prepareEdit()
        let usedIndices = patch.moduleGroups.map(\.colorIndex)
        let colorIndex = GroupPalette.leastUsedIndex(excluding: usedIndices)
        var group = ModuleGroup(name: name, colorIndex: colorIndex, placedModuleIDs: moduleIDs)
        group.notes = notes
        patch.addGroup(group)
    }

    func deleteGroup(_ groupID: UUID) {
        prepareEdit()
        activePatch?.deleteGroup(groupID)
    }

    func renameGroup(_ groupID: UUID, to name: String) {
        guard let patch = activePatch,
              let index = patch.moduleGroups.firstIndex(where: { $0.id == groupID }) else { return }
        prepareEdit()
        patch.moduleGroups[index].name = name
    }

    func updateGroupNotes(_ groupID: UUID, notes: String) {
        guard let patch = activePatch,
              let index = patch.moduleGroups.firstIndex(where: { $0.id == groupID }) else { return }
        prepareEdit()
        patch.moduleGroups[index].notes = notes
    }

    func toggleModulesInGroup(moduleIDs: Set<UUID>, groupID: UUID) {
        guard let patch = activePatch else { return }
        prepareEdit()
        for moduleID in moduleIDs {
            patch.toggleModuleInGroup(moduleID: moduleID, groupID: groupID)
        }
    }

    func addModulesToGroup(moduleIDs: Set<UUID>, groupID: UUID) {
        guard let patch = activePatch,
              let index = patch.moduleGroups.firstIndex(where: { $0.id == groupID }) else { return }
        prepareEdit()
        for moduleID in moduleIDs {
            if !patch.moduleGroups[index].placedModuleIDs.contains(moduleID) {
                patch.moduleGroups[index].placedModuleIDs.append(moduleID)
            }
        }
    }

    func removeModulesFromGroup(moduleIDs: Set<UUID>, groupID: UUID) {
        guard let patch = activePatch,
              let index = patch.moduleGroups.firstIndex(where: { $0.id == groupID }) else { return }
        prepareEdit()
        patch.moduleGroups[index].placedModuleIDs.removeAll { moduleIDs.contains($0) }
    }

    func groupOverlays(forModule moduleID: UUID) -> [(groupID: UUID, colorIndex: Int, name: String)] {
        guard let patch = activePatch else { return [] }
        return patch.groups(forModule: moduleID).map { ($0.id, $0.colorIndex, $0.name) }
    }

    func groupsContainingAny(of moduleIDs: Set<UUID>) -> [ModuleGroup] {
        guard let patch = activePatch else { return [] }
        return patch.moduleGroups.filter { group in
            moduleIDs.contains(where: { group.placedModuleIDs.contains($0) })
        }
    }
}
