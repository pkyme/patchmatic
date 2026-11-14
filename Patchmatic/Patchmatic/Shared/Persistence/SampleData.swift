import Foundation

enum SampleData {
    static func makeDocument() -> PatchmaticDocument {
        let vco = makeVCO()
        let vcf = makeVCF()
        let vca = makeVCA()

        let modules = [vco, vcf, vca]

        let mainCase = Case(name: "Main Case", rows: [RackRow(size: .threeU)], rowWidthHP: 84, placedModules: [
            PlacedModule(moduleDefinitionID: vco.id, rowIndex: 0, positionInRow: 0),
            PlacedModule(moduleDefinitionID: vcf.id, rowIndex: 0, positionInRow: 10),
            PlacedModule(moduleDefinitionID: vca.id, rowIndex: 0, positionInRow: 20),
        ])
        let rack = Rack(name: "Main Rack", cases: [mainCase])

        let placedVCO = mainCase.placedModules[0]
        let placedVCF = mainCase.placedModules[1]
        let placedVCA = mainCase.placedModules[2]

        let vcoOut = vco.controls.first { $0.label == "Out" }!
        let vcfIn = vcf.controls.first { $0.label == "In" }!
        let vcfOut = vcf.controls.first { $0.label == "Out" }!
        let vcaIn = vca.controls.first { $0.label == "In" }!

        let cables = [
            PatchCable(fromModuleID: placedVCO.id, fromControlID: vcoOut.id, toModuleID: placedVCF.id, toControlID: vcfIn.id, colorIndex: 0),
            PatchCable(fromModuleID: placedVCF.id, fromControlID: vcfOut.id, toModuleID: placedVCA.id, toControlID: vcaIn.id, colorIndex: 1),
        ]

        let knobValues = [
            KnobValue(placedModuleID: placedVCO.id, controlID: vco.controls.first { $0.label == "Freq" }!.id, value: 0.5),
            KnobValue(placedModuleID: placedVCF.id, controlID: vcf.controls.first { $0.label == "Cutoff" }!.id, value: 0.7),
            KnobValue(placedModuleID: placedVCF.id, controlID: vcf.controls.first { $0.label == "Res" }!.id, value: 0.3),
            KnobValue(placedModuleID: placedVCA.id, controlID: vca.controls.first { $0.label == "Level" }!.id, value: 0.8),
        ]

        let patch = Patch(name: "Init Patch", rackID: rack.id, cables: cables, knobValues: knobValues)

        return PatchmaticDocument(
            moduleLibrary: modules,
            racks: [rack],
            patches: [patch],
            activeRackID: rack.id,
            activePatchID: patch.id
        )
    }

    // MARK: - Module factories

    private static func makeVCO() -> ModuleDefinition {
        ModuleDefinition(name: "VCO", widthHP: 10, controls: [
            Control(kind: .knob, label: "Freq", position: NormalizedPoint(x: 0.5, y: 0.2)),
            Control(kind: .knob, label: "PW", position: NormalizedPoint(x: 0.5, y: 0.4)),
            Control(kind: .patchPoint, label: "V/Oct", position: NormalizedPoint(x: 0.25, y: 0.7)),
            Control(kind: .patchPoint, label: "PWM", position: NormalizedPoint(x: 0.5, y: 0.7)),
            Control(kind: .patchPoint, label: "Out", position: NormalizedPoint(x: 0.75, y: 0.7)),
        ])
    }

    private static func makeVCF() -> ModuleDefinition {
        ModuleDefinition(name: "VCF", widthHP: 8, controls: [
            Control(kind: .knob, label: "Cutoff", position: NormalizedPoint(x: 0.5, y: 0.2)),
            Control(kind: .knob, label: "Res", position: NormalizedPoint(x: 0.5, y: 0.4)),
            Control(kind: .patchPoint, label: "In", position: NormalizedPoint(x: 0.25, y: 0.7)),
            Control(kind: .patchPoint, label: "CV", position: NormalizedPoint(x: 0.5, y: 0.7)),
            Control(kind: .patchPoint, label: "Out", position: NormalizedPoint(x: 0.75, y: 0.7)),
        ])
    }

    private static func makeVCA() -> ModuleDefinition {
        ModuleDefinition(name: "VCA", widthHP: 6, controls: [
            Control(kind: .knob, label: "Level", position: NormalizedPoint(x: 0.5, y: 0.25)),
            Control(kind: .patchPoint, label: "In", position: NormalizedPoint(x: 0.25, y: 0.7)),
            Control(kind: .patchPoint, label: "CV", position: NormalizedPoint(x: 0.5, y: 0.7)),
            Control(kind: .patchPoint, label: "Out", position: NormalizedPoint(x: 0.75, y: 0.7)),
        ])
    }
}
