import SwiftUI

/// Positions and hit testing for the cables of the active patch. Cable shapes come from
/// the physics ropes when they exist, and from catenary curves otherwise.
@MainActor
struct CableGeometry {
    let patch: Patch
    let rack: Rack
    let rackVM: RackViewModel
    let simulator: CableSimulator

    init?(rackVM: RackViewModel, patchVM: PatchViewModel) {
        guard let patch = patchVM.activePatch,
              let rack = rackVM.document.rack(for: patch.rackID) else { return nil }
        self.patch = patch
        self.rack = rack
        self.rackVM = rackVM
        self.simulator = patchVM.cableSimulator
    }

    /// The cable's fixed points in world coordinates: start control, each pin in order, end control.
    func fixedPoints(for cable: PatchCable) -> [CGPoint]? {
        guard let start = rackVM.controlScreenPosition(in: rack, moduleID: cable.fromModuleID, controlID: cable.fromControlID),
              let end = rackVM.controlScreenPosition(in: rack, moduleID: cable.toModuleID, controlID: cable.toControlID)
        else { return nil }
        return [start] + cable.orderedPins.map { GeometryHelpers.pinWorldPosition($0, rack: rack) } + [end]
    }

    /// One polyline per segment between fixed points.
    func segmentPolylines(for cable: PatchCable) -> [[CGPoint]] {
        var fixed: [CGPoint]?
        var result: [[CGPoint]] = []
        for segment in 0..<cable.segmentCount {
            if let points = simulator.pointsForRope(id: cable.segmentRopeID(segment)) {
                result.append(points)
                continue
            }
            if fixed == nil { fixed = fixedPoints(for: cable) }
            guard let fixed, fixed.count > segment + 1 else { continue }
            result.append(CableRenderer.sampleCatenary(from: fixed[segment], to: fixed[segment + 1], count: 20))
        }
        return result
    }

    /// The cable closest to `point` within `threshold`.
    func cable(at point: CGPoint, threshold: CGFloat = 6) -> UUID? {
        var bestID: UUID?
        var bestDistance = threshold
        for cable in patch.cables {
            for polyline in segmentPolylines(for: cable) {
                let distance = GeometryHelpers.distanceToPolyline(point: point, polyline: polyline)
                if distance < bestDistance {
                    bestDistance = distance
                    bestID = cable.id
                }
            }
        }
        return bestID
    }

    /// Cables with any part inside `rect`.
    func cables(intersecting rect: CGRect) -> Set<UUID> {
        guard rect.width > 0 || rect.height > 0 else { return [] }
        var result: Set<UUID> = []
        for cable in patch.cables
        where segmentPolylines(for: cable).contains(where: { GeometryHelpers.polyline($0, intersects: rect) }) {
            result.insert(cable.id)
        }
        return result
    }

    /// The pin closest to `point` within `threshold`.
    func pin(at point: CGPoint, threshold: CGFloat = 8) -> (cableID: UUID, pinID: UUID)? {
        var best: (cableID: UUID, pinID: UUID)?
        var bestDistance = threshold
        for cable in patch.cables {
            for pin in cable.pins {
                let position = GeometryHelpers.pinWorldPosition(pin, rack: rack)
                let distance = hypot(point.x - position.x, point.y - position.y)
                if distance < bestDistance {
                    bestDistance = distance
                    best = (cable.id, pin.id)
                }
            }
        }
        return best
    }

    // MARK: - Ropes

    /// Replaces the cable's ropes with new ones: one free rope without pins, or one
    /// pinned rope per segment.
    func rebuildRopes(for cable: PatchCable) {
        guard let fixed = fixedPoints(for: cable) else { return }
        simulator.removeRopes(forCable: cable)
        if cable.pins.isEmpty {
            simulator.addRope(id: cable.id, from: fixed[0], to: fixed[1], perturbed: true)
        } else {
            for segment in 0..<cable.segmentCount {
                simulator.addRope(id: cable.segmentRopeID(segment), from: fixed[segment], to: fixed[segment + 1],
                                  perturbed: true, pinned: true)
            }
        }
    }

    /// Replaces every rope with fresh ones for the patch's cables.
    func rebuildAllRopes() {
        simulator.removeAll()
        for cable in patch.cables { rebuildRopes(for: cable) }
    }

    /// Adds ropes for cables that have none, e.g. after a cable is drawn, pasted or
    /// restored by redo. The rope drawn while dragging becomes the last new cable's rope,
    /// so a drawn cable keeps its shape.
    func addMissingRopes(adoptingDragRope dragRopeID: UUID) {
        let missing = patch.cables.filter { simulator.pointsForRope(id: $0.segmentRopeID(0)) == nil }
        for cable in missing {
            if cable.id == missing.last?.id, cable.pins.isEmpty,
               simulator.pointsForRope(id: dragRopeID) != nil,
               let fixed = fixedPoints(for: cable) {
                simulator.convertRope(from: dragRopeID, to: cable.id)
                simulator.updateEndpoints(id: cable.id, from: fixed[0], to: fixed[1])
            } else {
                rebuildRopes(for: cable)
            }
        }
    }

    /// After undo or discard, rebuilds ropes for cables whose segments changed and moves
    /// the endpoints of the rest, keeping their physics state.
    func syncRopesAfterRestore() {
        /// Highest number of stale segment ropes removed when a cable loses pins
        let maxStaleSegments = 10
        for cable in patch.cables {
            let count = cable.segmentCount
            let missingSegment = (0..<count).contains { simulator.pointsForRope(id: cable.segmentRopeID($0)) == nil }
            let staleSegment = simulator.pointsForRope(id: cable.segmentRopeID(count)) != nil
            if missingSegment || staleSegment {
                for extra in count..<(count + maxStaleSegments) {
                    simulator.removeRope(id: cable.segmentRopeID(extra))
                }
                rebuildRopes(for: cable)
            } else if !cable.pins.isEmpty {
                syncSegmentRopes(for: cable.id)
            }
        }
    }

    /// Moves each segment rope's endpoints to the cable's current fixed points, adding
    /// ropes for new segments, e.g. after a pin is moved, added or removed.
    func syncSegmentRopes(for cableID: UUID) {
        guard let cable = patch.cables.first(where: { $0.id == cableID }),
              let fixed = fixedPoints(for: cable) else { return }
        for segment in 0..<cable.segmentCount {
            let ropeID = cable.segmentRopeID(segment)
            if simulator.pointsForRope(id: ropeID) != nil {
                simulator.updateEndpoints(id: ropeID, from: fixed[segment], to: fixed[segment + 1])
            } else {
                simulator.addRope(id: ropeID, from: fixed[segment], to: fixed[segment + 1], perturbed: true, pinned: true)
            }
        }
    }
}
