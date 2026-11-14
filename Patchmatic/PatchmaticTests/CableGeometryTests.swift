import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct CableGeometryTests {
    let fixture = SampleFixture()
    let rackVM: RackViewModel
    let patchVM: PatchViewModel

    init() {
        rackVM = RackViewModel(document: fixture.document)
        patchVM = PatchViewModel(document: fixture.document)
        patchVM.rackVM = rackVM
    }

    private func catenaryMidpoint(of cable: PatchCable, in geometry: CableGeometry) -> CGPoint {
        let fixed = geometry.fixedPoints(for: cable)!
        return CableRenderer.sampleCatenary(from: fixed[0], to: fixed[1], count: 21)[10]
    }

    @Test func cablesWithoutRopesAreHitAlongTheirCatenary() throws {
        let geometry = try #require(patchVM.cableGeometry)
        let cable = fixture.patch.cables[0]
        #expect(patchVM.cableSimulator.pointsForRope(id: cable.id) == nil)
        #expect(geometry.cable(at: catenaryMidpoint(of: cable, in: geometry)) == cable.id)
        #expect(geometry.cable(at: CGPoint(x: -1000, y: -1000)) == nil)
    }

    @Test func marqueeSelectsCablesItCrosses() throws {
        let geometry = try #require(patchVM.cableGeometry)
        let cable = fixture.patch.cables[0]
        let mid = catenaryMidpoint(of: cable, in: geometry)
        let rect = CGRect(x: mid.x - 2, y: mid.y - 2, width: 4, height: 4)
        #expect(geometry.cables(intersecting: rect).contains(cable.id))
    }

    @Test func rebuildingGivesEveryCableARope() throws {
        let geometry = try #require(patchVM.cableGeometry)
        geometry.rebuildAllRopes()
        for cable in fixture.patch.cables {
            #expect(patchVM.cableSimulator.pointsForRope(id: cable.id) != nil)
        }
        patchVM.cableSimulator.removeAll()
    }
}
