import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct RackViewModelTests {
    let fixture = SampleFixture()
    let viewModel: RackViewModel
    let undoManager = makeUndoManager()

    init() {
        viewModel = RackViewModel(document: fixture.document)
        viewModel.undoManager = undoManager
    }

    @Test func removingAModuleRemovesItsPatchData() {
        let vcf = fixture.placed(named: "VCF")
        viewModel.selectedPlacedModuleIDs = [vcf.id]
        viewModel.removeSelectedModules()
        #expect(!fixture.rackCase.placedModules.contains { $0.id == vcf.id })
        #expect(fixture.patch.cables.isEmpty)
        #expect(!fixture.patch.knobValues.contains { $0.placedModuleID == vcf.id })
    }

    @Test func undoingAModuleRemovalRestoresItsPatchData() {
        let vcf = fixture.placed(named: "VCF")
        viewModel.selectedPlacedModuleIDs = [vcf.id]
        viewModel.removeSelectedModules()
        undoManager.undo()
        #expect(fixture.rackCase.placedModules.contains { $0.id == vcf.id })
        #expect(fixture.patch.cables.count == 2)
        #expect(fixture.patch.knobValues.count == 4)
        undoManager.redo()
        #expect(fixture.patch.cables.isEmpty)
    }

    @Test func discardRestoresPatchData() {
        viewModel.selectedPlacedModuleIDs = [fixture.placed(named: "VCF").id]
        viewModel.removeSelectedModules()
        viewModel.discardEditing()
        #expect(fixture.patch.cables.count == 2)
        #expect(fixture.rackCase.placedModules.count == 3)
    }

    @Test func removingSeveralModulesIsOneUndoStep() {
        viewModel.selectedPlacedModuleIDs = Set(fixture.rackCase.placedModules.map(\.id))
        viewModel.removeSelectedModules()
        #expect(fixture.rackCase.placedModules.isEmpty)
        undoManager.undo()
        #expect(fixture.rackCase.placedModules.count == 3)
    }

    @Test func theLastCaseIsNeverRemoved() {
        viewModel.selectedCaseIDs = [fixture.rackCase.id]
        viewModel.removeSelectedCases()
        #expect(fixture.rack.cases.count == 1)
        #expect(!viewModel.isEditing)
    }

    @Test func addingAModuleUsesTheNextFreePosition() {
        viewModel.addModuleToRack(fixture.definition(named: "VCA"), case: fixture.rackCase, row: 0)
        // Existing modules occupy 0..<10, 10..<18 and 20..<26
        #expect(fixture.rackCase.placedModules.last?.positionInRow == 26)
    }

    @Test func savingEditsToARackWithPatchesWarnsFirst() {
        viewModel.addCase()
        #expect(viewModel.inUseWarning != nil)
        viewModel.requestCommit()
        #expect(viewModel.pendingSaveConfirmation)
        #expect(viewModel.isEditing)
    }
}
