import SwiftUI

enum ToggleSwitchRenderer {
    static func shortAxis(radius: CGFloat) -> CGFloat { radius * 1.2 }
    static func cornerRadius(zoom: CGFloat) -> CGFloat { 2 * zoom }

    static func draw(
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        value: Double = 0,
        orientation: Control.Orientation = .vertical,
        zoom: CGFloat = 1.0,
        stateCount: Int = 2,
        showState: Bool = true
    ) {
        let isHorizontal = orientation == .horizontal
        let short = shortAxis(radius: radius)
        let n = max(2, stateCount)
        let long = Self.longAxis(radius: radius, stateCount: n, zoom: zoom)
        let rectW = isHorizontal ? long : short
        let rectH = isHorizontal ? short : long
        let rect = CGRect(
            x: center.x - rectW / 2,
            y: center.y - rectH / 2,
            width: rectW,
            height: rectH
        )
        let roundedRect = Path(roundedRect: rect, cornerRadius: cornerRadius(zoom: zoom))
        context.stroke(roundedRect, with: .foreground, lineWidth: 1.5 * zoom)

        if showState {
            // Toggle indicator positioned by value across N discrete positions
            let indicatorRadius = short * 0.3
            let halfTravel = long / 2 - indicatorRadius - 1.5 * zoom
            let t = CGFloat(value)
            let offset = halfTravel * (1 - 2 * t)
            let indicatorCenter: CGPoint
            if isHorizontal {
                indicatorCenter = CGPoint(x: center.x - offset, y: center.y)
            } else {
                indicatorCenter = CGPoint(x: center.x, y: center.y + offset)
            }
            context.fill(Path(circleAt: indicatorCenter, radius: indicatorRadius), with: .foreground)
        }
    }

    /// Shared long-axis calculation. At small sizes (baseRadius < 5) the toggle is
    /// stretched so the indicator travel is large enough to distinguish states.
    static func longAxis(radius: CGFloat, stateCount: Int, zoom: CGFloat) -> CGFloat {
        let baseRadius = zoom > 0 ? radius / zoom : radius
        let smallBoost: CGFloat = baseRadius < 5 ? 1.25 : 1.0
        let n = max(2, stateCount)
        return radius * (1.0 + 0.8 * CGFloat(n - 1)) * smallBoost
    }
}
