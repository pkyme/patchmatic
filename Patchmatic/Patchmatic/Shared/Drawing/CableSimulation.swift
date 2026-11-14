import SwiftUI

struct CableRope {
    var particles: [CGPoint]
    var prevPositions: [CGPoint]
    var restLengths: [CGFloat]
    var settledFrames: Int = 0
    var startFixed: CGPoint
    var endFixed: CGPoint
    var neverSettle: Bool = false
    var pinned: Bool = false
    /// Higher values run more constraint iterations, producing a stiffer cable
    var stiffness: Int = 0

    static let particleCount = 5
    static let settleThreshold: CGFloat = 0.05
    static let settleFramesRequired = 3
    static let pinnedStiffness = 8
    static let verticalLengthRatio: CGFloat = 0.97
    static let horizontalLengthRatio: CGFloat = 1.02
    static let perturbationRange: ClosedRange<CGFloat> = -5...5
    static let minSegmentLength: CGFloat = 0
    static let catenaryControlPointOffset: CGFloat = 0.25
}

@MainActor
@Observable
final class CableSimulator {
    /// Ropes still moving. The simulation timer runs only while this is non-empty,
    /// so a settled rack lets the CPU idle.
    private(set) var ropes: [UUID: CableRope] = [:] {
        didSet { updateTimer() }
    }
    private(set) var settledRopes: [UUID: CableRope] = [:]

    /// Called after each simulation step, e.g. to re-test what the cursor is over
    @ObservationIgnored var onStep: (() -> Void)?
    @ObservationIgnored private var timer: Timer?
    private static let frameInterval: TimeInterval = 1.0 / 60.0

    private func updateTimer() {
        if ropes.isEmpty {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            let t = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
                // Scheduled on the main run loop below
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.step(dt: CGFloat(Self.frameInterval))
                    self.onStep?()
                }
            }
            // Common modes keep the simulation running during drags and menu tracking
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    isolated deinit { timer?.invalidate() }

    private let gravity = CGPoint(x: 0, y: 1960)
    private let damping: CGFloat = 0.98
    private let constraintIterations = 2
    private let minFrameDt: CGFloat = 1.0 / 30.0

    var hasActiveRopes: Bool { !ropes.isEmpty }

    func step(dt: CGFloat) {
        let clampedDt = min(dt, minFrameDt)
        var toRemove: [UUID] = []

        for (id, _) in ropes {
            stepRope(id: id, dt: clampedDt)

            if let rope = ropes[id],
               !rope.neverSettle,
               rope.settledFrames >= CableRope.settleFramesRequired {
                toRemove.append(id)
            }
        }

        for id in toRemove {
            settledRopes[id] = ropes.removeValue(forKey: id)
        }
    }

    func addRope(id: UUID, from start: CGPoint, to end: CGPoint, perturbed: Bool, neverSettle: Bool = false, pinned: Bool = false) {
        let points = CableRenderer.sampleCatenary(from: start, to: end, count: CableRope.particleCount, pinned: pinned)
        var prevPositions = points

        if perturbed {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let len = hypot(dx, dy)
            let perpX = len > 0 ? -dy / len : 0
            let perpY = len > 0 ? dx / len : 0

            for i in 1..<(points.count - 1) {
                let t = CGFloat(i) / CGFloat(points.count - 1)
                let envelope = sin(t * .pi)
                let offset = envelope * CGFloat.random(in: CableRope.perturbationRange)
                prevPositions[i].x += perpX * offset
                prevPositions[i].y += perpY * offset
            }
        }

        ropes[id] = CableRope(
            particles: points,
            prevPositions: prevPositions,
            restLengths: CableSimulator.makeRestLengths(from: start, to: end, count: CableRope.particleCount, pinned: pinned),
            startFixed: start,
            endFixed: end,
            neverSettle: neverSettle,
            pinned: pinned,
            stiffness: pinned ? CableRope.pinnedStiffness : 0
        )
    }

    func updateEndpoints(id: UUID, from start: CGPoint, to end: CGPoint) {
        // Restore from settled state if needed
        if ropes[id] == nil, let settled = settledRopes.removeValue(forKey: id) {
            ropes[id] = settled
        }
        guard var rope = ropes[id] else { return }
        let last = rope.particles.count - 1
        rope.particles[0] = start
        rope.prevPositions[0] = start
        rope.particles[last] = end
        rope.prevPositions[last] = end
        rope.startFixed = start
        rope.endFixed = end
        rope.settledFrames = 0
        rope.restLengths = CableSimulator.makeRestLengths(from: start, to: end, count: rope.particles.count, pinned: rope.pinned)
        ropes[id] = rope
    }

    func removeRope(id: UUID) {
        ropes.removeValue(forKey: id)
        settledRopes.removeValue(forKey: id)
    }

    func removeRopes(forCable cable: PatchCable) {
        for i in 0..<cable.segmentCount {
            removeRope(id: cable.segmentRopeID(i))
        }
    }

    func removeAll() {
        ropes.removeAll()
        settledRopes.removeAll()
    }

    func pointsForRope(id: UUID) -> [CGPoint]? {
        if let rope = ropes[id] { return rope.particles }
        if let rope = settledRopes[id] { return rope.particles }
        return nil
    }

    func pathForRope(id: UUID) -> Path? {
        if let rope = ropes[id] {
            return catmullRomPath(through: rope.particles)
        }
        if let rope = settledRopes[id] {
            return catmullRomPath(through: rope.particles)
        }
        return nil
    }

    func convertRope(from sourceID: UUID, to targetID: UUID) {
        guard var rope = ropes[sourceID] else { return }
        rope.neverSettle = false
        rope.settledFrames = 0
        ropes[targetID] = rope
        ropes.removeValue(forKey: sourceID)
    }

    // MARK: - Private

    private func stepRope(id: UUID, dt: CGFloat) {
        guard var rope = ropes[id] else { return }
        let count = rope.particles.count
        var maxDisplacement: CGFloat = 0

        // Verlet integration for interior particles
        for i in 1..<(count - 1) {
            let pos = rope.particles[i]
            let prev = rope.prevPositions[i]
            let velocity = CGPoint(
                x: (pos.x - prev.x) * damping,
                y: (pos.y - prev.y) * damping
            )
            rope.prevPositions[i] = pos
            rope.particles[i] = CGPoint(
                x: pos.x + velocity.x + gravity.x * dt * dt,
                y: pos.y + velocity.y + gravity.y * dt * dt
            )
        }

        // Distance constraints
        let iterations = constraintIterations + rope.stiffness
        for _ in 0..<iterations {
            for i in 0..<(count - 1) {
                let p1 = rope.particles[i]
                let p2 = rope.particles[i + 1]
                let dx = p2.x - p1.x
                let dy = p2.y - p1.y
                let dist = hypot(dx, dy)
                guard dist > 0 else { continue }
                let diff = (dist - rope.restLengths[i]) / dist * 0.5
                let offsetX = dx * diff
                let offsetY = dy * diff
                let pin1 = (i == 0)
                let pin2 = (i + 1 == count - 1)
                if pin1 && pin2 { continue }
                if pin1 {
                    rope.particles[i + 1].x -= offsetX * 2
                    rope.particles[i + 1].y -= offsetY * 2
                } else if pin2 {
                    rope.particles[i].x += offsetX * 2
                    rope.particles[i].y += offsetY * 2
                } else {
                    rope.particles[i].x += offsetX
                    rope.particles[i].y += offsetY
                    rope.particles[i + 1].x -= offsetX
                    rope.particles[i + 1].y -= offsetY
                }
            }
            rope.particles[0] = rope.startFixed
            rope.particles[count - 1] = rope.endFixed
        }

        // Check settle
        for i in 1..<(count - 1) {
            let dx = rope.particles[i].x - rope.prevPositions[i].x
            let dy = rope.particles[i].y - rope.prevPositions[i].y
            maxDisplacement = max(maxDisplacement, hypot(dx, dy))
        }

        rope.settledFrames = maxDisplacement < CableRope.settleThreshold ? rope.settledFrames + 1 : 0
        ropes[id] = rope
    }

    private func catmullRomPath(through points: [CGPoint]) -> Path {
        guard points.count >= 2 else { return Path() }

        var path = Path()
        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return path
    }

    static func makeRestLengths(from start: CGPoint, to end: CGPoint, count: Int, pinned: Bool = false) -> [CGFloat] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = hypot(dx, dy)
        let lengthRatio: CGFloat
        if pinned {
            lengthRatio = CableRope.verticalLengthRatio
        } else {
            let horizontalFraction = dist > 0 ? abs(dx) / dist : 0
            lengthRatio = CableRope.verticalLengthRatio + (CableRope.horizontalLengthRatio - CableRope.verticalLengthRatio) * horizontalFraction
        }
        let segCount = CGFloat(count - 1)
        let segLen = max(dist * lengthRatio, segCount * CableRope.minSegmentLength) / segCount
        return Array(repeating: segLen, count: count - 1)
    }
}
