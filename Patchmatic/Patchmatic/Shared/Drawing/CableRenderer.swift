import SwiftUI

enum CableRenderer {
    // 20 hues evenly spaced at 18° intervals for maximum visual distinction
    static let darkModePalette: [Color] = {
        var colors: [Color] = []
        for i in 0..<20 {
            colors.append(Color(hue: Double(i) / 20.0, saturation: 0.80, brightness: 0.95))
        }
        colors += [Color(white: 0.95), Color(white: 0.70), Color(white: 0.45), Color(white: 0.25)]
        return colors
    }()

    static let lightModePalette: [Color] = {
        var colors: [Color] = []
        for i in 0..<20 {
            colors.append(Color(hue: Double(i) / 20.0, saturation: 0.85, brightness: 0.70))
        }
        colors += [Color(white: 0.90), Color(white: 0.60), Color(white: 0.35), Color(white: 0.10)]
        return colors
    }()

    static func color(forIndex index: Int, isDarkMode: Bool) -> Color {
        let palette = isDarkMode ? darkModePalette : lightModePalette
        return palette[index % palette.count]
    }

    static func color(for cable: PatchCable, isDarkMode: Bool) -> Color {
        if let custom = cable.customColor {
            return custom.color
        }
        return color(forIndex: cable.colorIndex, isDarkMode: isDarkMode)
    }

    /// Bezier control points approximating a hanging cable (catenary) between two
    /// points. The sag grows with horizontal distance; a pinned segment has none.
    static func catenaryControlPoints(from start: CGPoint, to end: CGPoint, pinned: Bool = false) -> (CGPoint, CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = hypot(dx, dy)
        let horizontalFraction = dist > 0 ? abs(dx) / dist : 0
        let sag = pinned ? 0 : dist * (CableRope.horizontalLengthRatio - 1.0) * horizontalFraction
        let midY = (start.y + end.y) / 2 + sag
        let offset = CableRope.catenaryControlPointOffset
        return (CGPoint(x: start.x + dx * offset, y: midY), CGPoint(x: end.x - dx * offset, y: midY))
    }

    static func catenaryPath(from start: CGPoint, to end: CGPoint) -> Path {
        let (cp1, cp2) = catenaryControlPoints(from: start, to: end)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: cp1, control2: cp2)
        return path
    }

    /// Evenly spaced parameter samples along the catenary bezier
    static func sampleCatenary(from start: CGPoint, to end: CGPoint, count: Int, pinned: Bool = false) -> [CGPoint] {
        let (cp1, cp2) = catenaryControlPoints(from: start, to: end, pinned: pinned)
        return (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            let mt = 1 - t
            return CGPoint(
                x: mt * mt * mt * start.x + 3 * mt * mt * t * cp1.x + 3 * mt * t * t * cp2.x + t * t * t * end.x,
                y: mt * mt * mt * start.y + 3 * mt * mt * t * cp1.y + 3 * mt * t * t * cp2.y + t * t * t * end.y
            )
        }
    }
}
