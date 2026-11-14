import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct GeometryHelpersTests {
    @Test func distanceToShortPolylinesIsInfinite() {
        #expect(GeometryHelpers.distanceToPolyline(point: .zero, polyline: []) == .greatestFiniteMagnitude)
        #expect(GeometryHelpers.distanceToPolyline(point: .zero, polyline: [.zero]) == .greatestFiniteMagnitude)
    }

    @Test func distanceToPolylineIsToTheNearestSegment() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)]
        #expect(GeometryHelpers.distanceToPolyline(point: CGPoint(x: 5, y: 3), polyline: line) == 3)
        #expect(GeometryHelpers.distanceToPolyline(point: CGPoint(x: 12, y: 5), polyline: line) == 2)
    }

    @Test func polylineCrossingARectangleIntersectsIt() {
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
        let crossing = [CGPoint(x: -5, y: 5), CGPoint(x: 15, y: 5)]
        let outside = [CGPoint(x: -5, y: -5), CGPoint(x: 15, y: -5)]
        #expect(GeometryHelpers.polyline(crossing, intersects: rect))
        #expect(!GeometryHelpers.polyline(outside, intersects: rect))
    }
}
