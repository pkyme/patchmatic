import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct PatchSetViewModelTests {
    let document: PatchmaticDocument
    let viewModel: PatchSetViewModel
    let undoManager = makeUndoManager()
    let patches: [Patch]

    init() {
        let rackID = UUID()
        patches = (1...3).map { Patch(name: "P\($0)", rackID: rackID) }
        document = PatchmaticDocument(racks: [Rack(id: rackID)], patches: patches)
        viewModel = PatchSetViewModel(document: document)
        viewModel.undoManager = undoManager
        viewModel.addSet()
        for patch in patches { viewModel.addPatchToSet(patch) }
    }

    @Test func navigationMovesThroughTheSet() {
        viewModel.goTo(index: 0)
        viewModel.goToNext()
        #expect(viewModel.currentPatch?.name == "P2")
        viewModel.goToNext()
        viewModel.goToNext()
        #expect(viewModel.currentPatch?.name == "P3")
        viewModel.goToPrevious()
        #expect(viewModel.currentPatch?.name == "P2")
    }

    @Test func positionInTheSetIsIndependentOfTheActivePatch() {
        viewModel.goTo(index: 1)
        document.activePatchID = UUID()
        #expect(viewModel.currentIndex == 1)
        viewModel.showCurrentPatch()
        #expect(document.activePatchID == patches[1].id)
    }

    @Test func movingPatchesKeepsShowingTheSamePatch() {
        viewModel.goTo(index: 0)
        viewModel.movePatchInSet(from: IndexSet(integer: 0), to: 3)
        #expect(viewModel.currentPatch?.name == "P1")
        #expect(viewModel.currentIndex == 2)
    }

    @Test func deletingASetAsksFirst() {
        let set = viewModel.activeSet!
        viewModel.requestDeleteSet(set)
        #expect(document.sets.count == 1)
        viewModel.confirmDeleteSet()
        #expect(document.sets.isEmpty)
    }

    @Test func deletingASetCanBeUndoneAndRedone() {
        let set = viewModel.activeSet!
        viewModel.goTo(index: 2)
        viewModel.deleteSet(set)
        #expect(document.sets.isEmpty)
        undoManager.undo()
        #expect(document.sets.map(\.id) == [set.id])
        #expect(document.activeSetID == set.id)
        #expect(viewModel.currentIndex == 2)
        undoManager.redo()
        #expect(document.sets.isEmpty)
    }
}
