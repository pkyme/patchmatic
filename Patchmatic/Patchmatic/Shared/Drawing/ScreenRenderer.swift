import SwiftUI

enum ScreenRenderer {
    static func cornerRadius(zoom: CGFloat) -> CGFloat { 3 * zoom }

    static func draw(
        in context: GraphicsContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        image: Image? = nil,
        zoom: CGFloat = 1.0,
        showState: Bool = true
    ) {
        let rect = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
        let roundedRect = Path(roundedRect: rect, cornerRadius: cornerRadius(zoom: zoom))

        if showState, let image {
            var imgContext = context
            imgContext.clip(to: roundedRect)
            imgContext.draw(image, in: rect)
        }

        context.stroke(roundedRect, with: .foreground, lineWidth: 1.5 * zoom)
    }
}
