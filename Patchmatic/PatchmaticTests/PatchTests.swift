import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct PatchTests {
    private func cable(_ from: (UUID, UUID), _ to: (UUID, UUID)) -> PatchCable {
        PatchCable(fromModuleID: from.0, fromControlID: from.1, toModuleID: to.0, toControlID: to.1)
    }

    @Test func patchPointsAreNumberedInConnectionOrderWhenCreated() {
        let a = (UUID(), UUID()), b = (UUID(), UUID()), c = (UUID(), UUID())
        let patch = Patch(rackID: UUID(), cables: [cable(a, b), cable(b, c)])
        #expect(patch.patchPointOrder == [
            PatchPointKey(moduleID: a.0, controlID: a.1),
            PatchPointKey(moduleID: b.0, controlID: b.1),
            PatchPointKey(moduleID: c.0, controlID: c.1),
        ])
    }

    @Test func compactingDropsDisconnectedPatchPoints() {
        let a = (UUID(), UUID()), b = (UUID(), UUID()), c = (UUID(), UUID())
        let patch = Patch(rackID: UUID(), cables: [cable(a, b), cable(b, c)])
        patch.cables.removeLast()
        patch.compactPatchPointOrder()
        #expect(patch.patchPointOrder.count == 2)
    }

    @Test func nextCableColourCyclesThroughThePalette() {
        let patch = Patch(rackID: UUID())
        #expect(patch.nextCableColorIndex == 0)
        let count = CableRenderer.darkModePalette.count
        patch.cables = (0..<count).map { _ in cable((UUID(), UUID()), (UUID(), UUID())) }
        #expect(patch.nextCableColorIndex == 0)
        patch.cables.append(cable((UUID(), UUID()), (UUID(), UUID())))
        #expect(patch.nextCableColorIndex == 1)
    }

    @Test func restoringContentsKeepsTheInstance() {
        let patch = SampleFixture().patch
        let original = Patch(id: patch.id, name: "Original", rackID: patch.rackID)
        let instance = ObjectIdentifier(patch)
        patch.restoreContents(from: original)
        #expect(ObjectIdentifier(patch) == instance)
        #expect(patch.name == "Original")
        #expect(patch.cables.isEmpty)
    }
}
