import Foundation
import Testing
@testable import Patchmatic

/// Saving or discarding an edit removes only that edit's undo steps, so earlier
/// document-level actions such as deleting a set or patch stay undoable.
@MainActor
struct UndoHistoryTests {
    let fixture = SampleFixture()
    let undoManager = makeUndoManager()
    let patchVM: PatchViewModel
    let setVM: PatchSetViewModel

    init() {
        patchVM = PatchViewModel(document: fixture.document)
        setVM = PatchSetViewModel(document: fixture.document)
        patchVM.undoManager = undoManager
        setVM.undoManager = undoManager
        setVM.addSet()
    }

    private func editPatch() {
        patchVM.selectedCableIDs = [fixture.patch.cables[0].id]
        patchVM.setSelectedCableColor(paletteIndex: 7)
    }

    @Test func savingAnEditKeepsEarlierDeletionsUndoable() {
        let set = setVM.activeSet!
        setVM.deleteSet(set)
        editPatch()
        patchVM.commitEditing()
        #expect(undoManager.canUndo)
        undoManager.undo()
        #expect(fixture.document.sets.map(\.id) == [set.id])
        // The saved edit itself is not undone
        #expect(fixture.patch.cables[0].colorIndex == 7)
    }

    @Test func discardingAnEditKeepsEarlierDeletionsUndoable() {
        let set = setVM.activeSet!
        setVM.deleteSet(set)
        editPatch()
        patchVM.discardEditing()
        undoManager.undo()
        #expect(fixture.document.sets.map(\.id) == [set.id])
    }

    @Test func savingRemovesTheEditsOwnUndoSteps() {
        editPatch()
        patchVM.commitEditing()
        #expect(!undoManager.canUndo)
    }
}

@MainActor
struct UndoAfterLaterEditsTests {
    let fixture = SampleFixture()
    let undoManager = makeUndoManager()
    let patchVM: PatchViewModel
    let rackVM: RackViewModel
    let setVM: PatchSetViewModel

    init() {
        patchVM = PatchViewModel(document: fixture.document)
        rackVM = RackViewModel(document: fixture.document)
        setVM = PatchSetViewModel(document: fixture.document)
        for vm in [patchVM.editSession, rackVM.editSession] { vm.undoManager = undoManager }
        setVM.undoManager = undoManager
    }

    @Test func restoredPatchDropsReferencesToModulesRemovedSinceItWasDeleted() {
        let patch = fixture.patch
        let vcf = fixture.placed(named: "VCF")
        patchVM.deletePatch(patch)
        rackVM.selectedPlacedModuleIDs = [vcf.id]
        rackVM.removeSelectedModules()
        rackVM.commitEditing()
        undoManager.undo()
        #expect(fixture.document.patches.map(\.id) == [patch.id])
        #expect(patch.cables.isEmpty)
        #expect(!patch.knobValues.contains { $0.placedModuleID == vcf.id })
        #expect(patch.knobValues.count == 2)
    }

    @Test func restoredSetDropsPatchesThatNoLongerExist() {
        setVM.addSet()
        setVM.addPatchToSet(fixture.patch)
        let set = setVM.activeSet!
        setVM.deleteSet(set)
        // The patch disappears without its own undo step, e.g. a library reloaded from sync
        fixture.document.patches.removeAll()
        undoManager.undo()
        #expect(fixture.document.sets.map(\.id) == [set.id])
        #expect(set.patchIDs.isEmpty)
    }
}
