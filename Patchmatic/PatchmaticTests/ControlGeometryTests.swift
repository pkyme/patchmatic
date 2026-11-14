import Foundation
import Testing
@testable import Patchmatic

@MainActor
struct ControlGeometryTests {
    let panel = CGSize(width: 100, height: 200)

    @Test func knobHitsInsideItsCircleOnly() {
        let knob = Control(kind: .knob, label: "K", position: NormalizedPoint(x: 0.5, y: 0.5))
        let r = knob.effectiveRadius
        #expect(knob.hitTest(point: CGPoint(x: 50 + r - 1, y: 100), in: panel))
        #expect(!knob.hitTest(point: CGPoint(x: 50 + r + 1, y: 100), in: panel))
        // Padding grows the hit area
        #expect(knob.hitTest(point: CGPoint(x: 50 + r + 1, y: 100), in: panel, padding: Control.hitPadding))
    }

    @Test func screenHitsAcrossItsWholeRectangle() {
        let screen = Control(kind: .screen, label: "S", position: NormalizedPoint(x: 0.5, y: 0.5),
                             screenWidth: 60, screenHeight: 20)
        // Corner of a wide screen, outside the old radius-based circle
        #expect(screen.hitTest(point: CGPoint(x: 50 + 29, y: 100 + 9), in: panel))
        // Above the screen, inside that circle
        #expect(!screen.hitTest(point: CGPoint(x: 50, y: 100 - 15), in: panel))
    }

    @Test func horizontalSliderIsWiderThanTall() {
        let slider = Control(kind: .slider, label: "S", position: NormalizedPoint(x: 0.5, y: 0.5),
                             orientation: .horizontal, sliderTrackLength: 40)
        let size = slider.bodySize()
        #expect(size.width == 40)
        #expect(size.height == SliderRenderer.knobSide(radius: slider.effectiveRadius))
    }

    @Test func bodySizeDoesNotDependOnPosition() {
        let a = Control(kind: .button, label: "B", position: NormalizedPoint(x: 0.1, y: 0.1))
        let b = Control(kind: .button, label: "B", position: NormalizedPoint(x: 0.9, y: 0.9))
        #expect(a.bodySize(zoom: 2) == b.bodySize(zoom: 2))
    }

    @Test func highlightMatchesHitTestForRectangularControls() {
        let toggle = Control(kind: .toggleSwitch, label: "T", position: NormalizedPoint(x: 0.5, y: 0.5))
        let bounds = toggle.highlightPath(in: panel).boundingRect
        #expect(toggle.hitTest(point: CGPoint(x: bounds.midX, y: bounds.minY + 0.5), in: panel))
        #expect(!toggle.hitTest(point: CGPoint(x: bounds.midX, y: bounds.minY - 0.5), in: panel))
    }
}
