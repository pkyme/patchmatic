import SwiftUI

enum KnobRenderer {
    /// Draws a knob as an open circle with a radial indicator line
    static func draw(
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        value: Double,
        zoom: CGFloat = 1.0,
        showState: Bool = true
    ) {
        let circle = Path(circleAt: center, radius: radius)
        context.stroke(circle, with: .foreground, lineWidth: 1.5 * zoom)

        if showState {
            let angle = GeometryHelpers.knobAngle(for: value)
            let innerPoint = GeometryHelpers.pointOnCircle(center: center, radius: radius * 0.3, angle: angle)
            let outerPoint = GeometryHelpers.pointOnCircle(center: center, radius: radius * 0.9, angle: angle)
            var indicator = Path()
            indicator.move(to: innerPoint)
            indicator.addLine(to: outerPoint)
            context.stroke(indicator, with: .foreground, lineWidth: 2 * zoom)
        }
    }
}
