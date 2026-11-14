import Foundation
import CoreGraphics
import SwiftUI

extension Path {
    init(circleAt center: CGPoint, radius: CGFloat) {
        self.init(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
}

enum GeometryHelpers {
    /// Distance between two CGPoints
    static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    /// Point on a circle at a given angle (radians) and radius from center
    static func pointOnCircle(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    /// Converts a knob value (0...1) to an angle in radians.
    /// Sweep: 300° from 25-to (7 o'clock, 120°) to 25-past (5 o'clock, 60°)
    static func knobAngle(for value: Double) -> CGFloat {
        // Sweep: 300° CW from :35 (120°) to :25 (60°), dead zone at bottom
        let degreesStart: CGFloat = 120
        let sweep: CGFloat = 300
        let degrees = degreesStart + sweep * CGFloat(value)
        return degrees * .pi / 180
    }

    /// Returns `name` if it is not already in `existing`, otherwise appends the lowest
    /// available integer suffix (" 2", " 3", …). Any trailing " N" in the input is
    /// stripped before searching so that "Rack 2" → "Rack 3" rather than "Rack 2 2".
    static func uniqueName(_ name: String, among existing: some Collection<String>) -> String {
        let occupied = Set(existing)
        guard occupied.contains(name) else { return name }
        let base: String
        if let range = name.range(of: #" \d+$"#, options: .regularExpression) {
            base = String(name[name.startIndex..<range.lowerBound])
        } else {
            base = name
        }
        var n = 2
        while occupied.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    /// Shortest distance from a point to a line segment
    static func distanceToSegment(point: CGPoint, segStart: CGPoint, segEnd: CGPoint) -> CGFloat {
        let dx = segEnd.x - segStart.x
        let dy = segEnd.y - segStart.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return hypot(point.x - segStart.x, point.y - segStart.y) }
        let t = max(0, min(1, ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / lengthSq))
        let projX = segStart.x + t * dx
        let projY = segStart.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }

    /// Shortest distance from a point to a polyline, or `.greatestFiniteMagnitude`
    /// when the polyline has fewer than two points.
    static func distanceToPolyline(point: CGPoint, polyline: [CGPoint]) -> CGFloat {
        var best = CGFloat.greatestFiniteMagnitude
        guard polyline.count >= 2 else { return best }
        for i in 0..<(polyline.count - 1) {
            let dist = distanceToSegment(point: point, segStart: polyline[i], segEnd: polyline[i + 1])
            if dist < best { best = dist }
        }
        return best
    }

    /// Whether any part of a polyline lies inside `rect`.
    static func polyline(_ points: [CGPoint], intersects rect: CGRect) -> Bool {
        guard let first = points.first else { return false }
        if rect.contains(first) { return true }
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)
        ]
        for (a, b) in zip(points, points.dropFirst()) {
            if rect.contains(b) { return true }
            for i in 0..<4 where segmentsIntersect(a, b, corners[i], corners[(i + 1) % 4]) {
                return true
            }
        }
        return false
    }

    /// Whether segments p1–p2 and q1–q2 properly cross.
    static func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        let d1 = cross(q1, q2, p1), d2 = cross(q1, q2, p2)
        let d3 = cross(p1, p2, q1), d4 = cross(p1, p2, q2)
        return (d1 * d2 < 0) && (d3 * d4 < 0)
    }

    /// Resolves a cable pin's world position, accounting for case anchoring
    static func pinWorldPosition(_ pin: CablePin, rack: Rack) -> CGPoint {
        if let caseID = pin.caseID,
           let rackCase = rack.cases.first(where: { $0.id == caseID }) {
            return CGPoint(x: rackCase.positionX + pin.x, y: rackCase.positionY + pin.y)
        }
        return pin.position
    }

    /// Computes the absolute screen position of a control within a placed module
    static func controlScreenPosition(
        control: Control,
        moduleOrigin: CGPoint,
        moduleSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: moduleOrigin.x + control.position.x * moduleSize.width,
            y: moduleOrigin.y + control.position.y * moduleSize.height
        )
    }
}
