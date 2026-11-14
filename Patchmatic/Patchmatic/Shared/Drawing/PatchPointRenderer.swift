import SwiftUI

extension EnvironmentValues {
    /// Whether patch points and their note dots draw drop shadows; off when printing
    @Entry var drawsShadows: Bool = true
}

enum PatchPointRenderer {
    /// Draws a patch point as a small filled circle
    static func draw(
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color? = nil,
        zoom: CGFloat = 1.0,
        showState: Bool = true,
        drawsShadow: Bool = true
    ) {
        let circle = Path(circleAt: center, radius: radius)
        var drawCtx = context
        if drawsShadow {
            drawCtx.addFilter(.shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2))
        }
        if showState, let color {
            drawCtx.fill(circle, with: .color(color))
        } else {
            drawCtx.fill(circle, with: .foreground)
        }
    }
}
