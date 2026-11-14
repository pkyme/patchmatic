import CoreGraphics
import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct PatchViewModelTests {
    let fixture = SampleFixture()
    let viewModel: PatchViewModel
    let undoManager = makeUndoManager()

    init() {
        viewModel = PatchViewModel(document: fixture.document)
        viewModel.undoManager = undoManager
    }

    private var cable: PatchCable { fixture.patch.cables[0] }

    @Test func addedPinsAreRenumberedInOrder() {
        let cableID = cable.id
        viewModel.addCablePin(cableID: cableID, pin: CablePin(x: 1, y: 1, sortIndex: 0))
        viewModel.addCablePin(cableID: cableID, pin: CablePin(x: 2, y: 2, sortIndex: 0))
        let pins = fixture.patch.cables[0].orderedPins
        #expect(pins.map(\.sortIndex) == [0, 1])
        #expect(pins.map(\.x) == [2, 1])
    }

    @Test func deletingAPinRenumbersTheRest() {
        let cableID = cable.id
        for x in [1.0, 2.0, 3.0] {
            viewModel.addCablePin(cableID: cableID, pin: CablePin(x: x, y: 0, sortIndex: Int(x) - 1))
        }
        let middle = fixture.patch.cables[0].orderedPins[1].id
        viewModel.deleteCablePin(cableID: cableID, pinID: middle)
        #expect(fixture.patch.cables[0].orderedPins.map(\.sortIndex) == [0, 1])
        #expect(fixture.patch.cables[0].orderedPins.map(\.x) == [1, 3])
    }

    @Test func recolouringClearsCustomColours() {
        fixture.patch.cables[0].customColor = CableColor(red: 1, green: 0, blue: 0)
        viewModel.selectedCableIDs = [cable.id]
        viewModel.setSelectedCableColor(paletteIndex: 5)
        #expect(fixture.patch.cables[0].colorIndex == 5)
        #expect(fixture.patch.cables[0].customColor == nil)
        #expect(fixture.patch.cables[1].colorIndex == 1)
    }

    @Test func undoRestoresAndRedoReappliesAnEdit() {
        viewModel.selectedCableIDs = [cable.id]
        viewModel.setSelectedCableColor(paletteIndex: 7)
        undoManager.undo()
        #expect(fixture.patch.cables[0].colorIndex == 0)
        undoManager.redo()
        #expect(fixture.patch.cables[0].colorIndex == 7)
    }

    @Test func discardRestoresThePatch() {
        viewModel.selectedCableIDs = [cable.id]
        viewModel.setSelectedCableColor(paletteIndex: 7)
        viewModel.discardEditing()
        #expect(fixture.patch.cables[0].colorIndex == 0)
        #expect(!viewModel.isEditing)
    }

    @Test func committedStateExcludesUncommittedEdits() throws {
        viewModel.selectedCableIDs = [cable.id]
        viewModel.setSelectedCableColor(paletteIndex: 7)
        let copy = try JSONDecoder().decode(PatchmaticDocument.self, from: encode(fixture.document))
        viewModel.restoreCommittedState(in: copy)
        #expect(copy.patches[0].cables[0].colorIndex == 0)
        #expect(fixture.patch.cables[0].colorIndex == 7)
    }

    @Test func deletingAPatchCanBeUndone() {
        let patch = fixture.patch
        viewModel.deletePatch(patch)
        #expect(fixture.document.patches.isEmpty)
        undoManager.undo()
        #expect(fixture.document.patches.map(\.id) == [patch.id])
    }
}
