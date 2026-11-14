import SwiftUI

enum ButtonRenderer {
    static func side(radius: CGFloat) -> CGFloat { radius * 1.8 }
    static func cornerRadius(zoom: CGFloat) -> CGFloat { 3 * zoom }

    /// Draws a button as a small filled rounded square
    static func draw(
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        value: Double = 0,
        zoom: CGFloat = 1.0,
        stateCount: Int = 2,
        isPressed: Bool = false,
        showState: Bool = true
    ) {
        let side = side(radius: radius)
        let rect = CGRect(
            x: center.x - side / 2,
            y: center.y - side / 2,
            width: side,
            height: side
        )
        let roundedRect = Path(roundedRect: rect, cornerRadius: cornerRadius(zoom: zoom))
        let filled = showState && (stateCount >= 3 ? isPressed : value >= 0.5)
        if filled {
            context.fill(roundedRect, with: .foreground)
        } else {
            context.stroke(roundedRect, with: .foreground, lineWidth: 1.5 * zoom)
        }
    }
}
