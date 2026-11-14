import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct ModuleEditorViewModelTests {
    let fixture = SampleFixture()
    let viewModel: ModuleEditorViewModel
    let undoManager = makeUndoManager()
    var module: ModuleDefinition { fixture.definition(named: "VCO") }

    init() {
        viewModel = ModuleEditorViewModel(document: fixture.document)
        viewModel.undoManager = undoManager
        viewModel.selectedModuleIDs = [fixture.definition(named: "VCO").id]
    }

    private func select(_ labels: String...) {
        viewModel.selectedControlIDs = Set(module.controls.filter { labels.contains($0.label) }.map(\.id))
    }

    private func control(_ label: String) -> Control {
        module.controls.first { $0.label == label }!
    }

    @Test func duplicatingAControlKeepsItsProperties() {
        let index = module.controls.firstIndex { $0.label == "Freq" }!
        module.controls[index].size = .large
        module.controls[index].controlLabel.offset = 3
        select("Freq")
        viewModel.duplicateSelectedControls()
        let copy = module.controls.last!
        #expect(copy.id != control("Freq").id)
        #expect(copy.size == .large)
        #expect(copy.controlLabel.offset == 3)
    }

    @Test func labelPrefixNumbersWithinTheSelection() {
        select("PWM", "Out")
        viewModel.numberSelectedControls(prefix: "J")
        #expect(control("J1").label == "J1")
        #expect(module.controls.contains { $0.label == "J2" })
        #expect(!module.controls.contains { $0.label == "J4" || $0.label == "J5" })
    }

    @Test func changingAControlToAScreenGivesItASize() {
        let id = control("Freq").id
        viewModel.setControlsKind(.screen, ids: [id])
        let screen = module.controls.first { $0.id == id }!
        #expect(screen.kind == .screen)
        #expect(screen.screenWidth > 0 && screen.screenHeight > 0)
        // Only default labels follow the kind; a custom label is kept
        #expect(screen.label == "Freq")
    }

    @Test func distributeSpacesControlsEvenly() {
        select("V/Oct", "PWM", "Out")
        let ids = viewModel.selectedControlIDs
        for i in module.controls.indices where ids.contains(module.controls[i].id) {
            module.controls[i].position.x = [0.1, 0.2, 0.9][module.controls[0..<i].filter { ids.contains($0.id) }.count]
        }
        viewModel.distributeSelectedHorizontally()
        let xs = module.controls.filter { ids.contains($0.id) }.map(\.position.x).sorted()
        #expect(abs(xs[1] - 0.5) < 1e-9)
    }

    @Test func centreAlignsToTheAverage() {
        select("Freq", "PW")
        viewModel.centerSelectedVertically()
        #expect(abs(control("Freq").position.y - 0.3) < 1e-9)
        #expect(abs(control("PW").position.y - 0.3) < 1e-9)
    }

    @Test func snapToGridMovesToGridIntersections() {
        let index = module.controls.firstIndex { $0.label == "Freq" }!
        module.controls[index].position = NormalizedPoint(x: 0.47, y: 0.23)
        select("Freq")
        viewModel.snapSelectedToGrid(divisions: 4)
        // 10 HP is 100 pt wide, so the grid cell is 25 pt
        let point = control("Freq").position.toPoint(in: CGSize(width: 100, height: module.panelHeight))
        #expect(point.x.truncatingRemainder(dividingBy: 25) == 0)
        #expect(point.y.truncatingRemainder(dividingBy: 25) == 0)
    }

    @Test func consecutiveEditsToOneFieldAreOneUndoStep() {
        let id = control("Freq").id
        viewModel.editControl(id, field: "label") { $0.label = "F" }
        viewModel.editControl(id, field: "label") { $0.label = "Fr" }
        viewModel.editControl(id, field: "label") { $0.label = "Fre" }
        undoManager.undo()
        #expect(module.controls.first { $0.id == id }!.label == "Freq")
    }

    @Test func discardRestoresTheModule() {
        select("Freq")
        viewModel.deleteSelectedControls()
        #expect(viewModel.isEditing)
        viewModel.discardEditing()
        #expect(module.controls.contains { $0.label == "Freq" })
        #expect(!viewModel.isEditing)
    }

    @Test func changingSelectionWhileEditingAsksFirst() {
        select("Freq")
        viewModel.deleteSelectedControls()
        let other = fixture.definition(named: "VCF").id
        viewModel.requestSelectModules([module.id, other])
        #expect(viewModel.pendingModuleSelection == [module.id, other])
        #expect(viewModel.selectedModuleIDs == [module.id])
        viewModel.confirmSelectionChange(save: false)
        #expect(viewModel.selectedModuleIDs == [module.id, other])
        #expect(module.controls.contains { $0.label == "Freq" })
    }
}
