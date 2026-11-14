import SwiftUI

enum SliderRenderer {
    /// Width of the track across its short axis, which is also the knob's size
    static func knobSide(radius: CGFloat) -> CGFloat {
        radius * 1.8
    }

    static func trackCornerRadius(zoom: CGFloat) -> CGFloat { 4 * zoom }

    /// Size of the knob cutout drawn inside the track
    static func cutoutSize(radius: CGFloat, isVertical: Bool) -> CGSize {
        let side = knobSide(radius: radius)
        return isVertical ? CGSize(width: side * 0.82, height: side * 0.45)
                          : CGSize(width: side * 0.45, height: side * 0.82)
    }

    /// Distance the knob centre can move either side of the track centre, leaving a gap
    /// at each end based on the cutout's height
    static func travelHalf(radius: CGFloat, trackLength: CGFloat, isVertical: Bool, zoom: CGFloat) -> CGFloat {
        let cutoutHeight = cutoutSize(radius: radius, isVertical: isVertical).height
        return trackLength / 2 - (cutoutHeight / 2 + 3 * zoom)
    }

    /// Draws a slider as a filled pill track with a rounded-square cutout knob positioned by value.
    static func draw(
        in context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        trackLength: CGFloat,
        isVertical: Bool = true,
        zoom: CGFloat = 1.0,
        value: Double = 0.5,
        showState: Bool = true
    ) {
        let knobSide = knobSide(radius: radius)
        let trackRect = isVertical
            ? CGRect(x: center.x - knobSide / 2, y: center.y - trackLength / 2,
                     width: knobSide, height: trackLength)
            : CGRect(x: center.x - trackLength / 2, y: center.y - knobSide / 2,
                     width: trackLength, height: knobSide)

        let cutout = cutoutSize(radius: radius, isVertical: isVertical)
        let cutoutW = cutout.width
        let cutoutH = cutout.height

        // Knob travels within the track, leaving a small gap at each end
        let travelHalf = travelHalf(radius: radius, trackLength: trackLength, isVertical: isVertical, zoom: zoom)
        let knobOffset = CGFloat(value - 0.5) * travelHalf * 2
        let knobCenter = isVertical
            ? CGPoint(x: center.x, y: center.y - knobOffset)
            : CGPoint(x: center.x + knobOffset, y: center.y)
        let cutoutRect = CGRect(
            x: knobCenter.x - cutoutW / 2,
            y: knobCenter.y - cutoutH / 2,
            width: cutoutW,
            height: cutoutH
        )

        context.drawLayer { ctx in
            ctx.fill(Path(roundedRect: trackRect, cornerRadius: trackCornerRadius(zoom: zoom)), with: .foreground)
            if showState {
                ctx.blendMode = .clear
                ctx.fill(Path(roundedRect: cutoutRect, cornerRadius: 3 * zoom), with: .color(.black))
            }
        }
    }
}
