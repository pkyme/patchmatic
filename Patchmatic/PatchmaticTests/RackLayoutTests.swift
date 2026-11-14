import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct RackLayoutTests {
    @Test func nextPositionSkipsPastExistingModulesUsingTheirOwnWidth() {
        let wide = UUID(), narrow = UUID()
        let rackCase = Case(rows: [RackRow()], rowWidthHP: 84, placedModules: [
            PlacedModule(moduleDefinitionID: wide, rowIndex: 0, positionInRow: 0),
        ])
        let widths = [wide: 20, narrow: 4]
        let position = rackCase.nextAvailablePosition(inRow: 0, moduleWidth: 4) { widths[$0.moduleDefinitionID]! }
        #expect(position == 20)
    }

    @Test func nextPositionUsesGapsBetweenModules() {
        let id = UUID()
        let rackCase = Case(rows: [RackRow()], rowWidthHP: 84, placedModules: [
            PlacedModule(moduleDefinitionID: id, rowIndex: 0, positionInRow: 0),
            PlacedModule(moduleDefinitionID: id, rowIndex: 0, positionInRow: 20),
        ])
        #expect(rackCase.nextAvailablePosition(inRow: 0, moduleWidth: 8) { _ in 10 } == 10)
        #expect(rackCase.nextAvailablePosition(inRow: 0, moduleWidth: 12) { _ in 10 } == 30)
    }

    @Test func fullRowHasNoPosition() {
        let rackCase = Case(rows: [RackRow()], rowWidthHP: 10, placedModules: [
            PlacedModule(moduleDefinitionID: UUID(), rowIndex: 0, positionInRow: 0),
        ])
        #expect(rackCase.nextAvailablePosition(inRow: 0, moduleWidth: 4) { _ in 10 } == nil)
    }

    @Test func boundingBoxCoversCasesAtNegativePositions() {
        let rack = Rack(cases: [
            Case(rows: [RackRow(size: .oneU)], rowWidthHP: 10, positionX: -300, positionY: -400),
            Case(rows: [RackRow(size: .oneU)], rowWidthHP: 10, positionX: -200, positionY: -200),
        ])
        let box = rack.boundingBox()
        #expect(box.minX == -300)
        #expect(box.minY == -400)
        #expect(box.maxX == -200 + EurorackConstants.width(forHP: 10))
        #expect(box.maxY == -200 + rack.cases[1].totalHeight())
        #expect(box.maxY < 0)
    }
}
