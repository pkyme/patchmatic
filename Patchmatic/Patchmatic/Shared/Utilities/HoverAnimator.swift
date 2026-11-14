import SwiftUI

/// Fades the hover highlight of a module control in and out. Views that read
/// `brightness` re-render on each step, so only the hovered module should read it.
@MainActor
@Observable
final class HoverAnimator {
    private(set) var brightness: Double = 0.0
    private(set) var controlID: UUID? = nil
    private(set) var moduleID: UUID? = nil

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var target: Double = 0.0
    private let inSpeed: Double = 1.0 / 0.08
    private let outSpeed: Double = 1.0 / 0.12

    func hoverIn(moduleID: UUID, controlID: UUID) {
        if self.controlID == controlID && self.moduleID == moduleID && target == 1.0 { return }
        if self.controlID != controlID || self.moduleID != moduleID { brightness = 0.0 }
        self.moduleID = moduleID
        self.controlID = controlID
        target = 1.0
        ensureTimer()
    }

    func hoverOut() {
        guard target != 0.0 else { return }
        target = 0.0
        ensureTimer()
    }

    /// Brightness for a control of the given module, reading `brightness` only when that
    /// module is the hovered one so other modules don't re-render while it animates.
    func brightness(forModule moduleID: UUID) -> Double {
        self.moduleID == moduleID ? brightness : 0
    }

    private func ensureTimer() {
        guard !(timer?.isValid ?? false) else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop below
            MainActor.assumeIsolated {
                self?.step()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        let step = (target > brightness ? inSpeed : outSpeed) / 60.0
        if target > brightness {
            brightness = min(target, brightness + step)
        } else {
            brightness = max(target, brightness - step)
        }
        if brightness == target {
            timer?.invalidate()
            timer = nil
            if target == 0.0 { controlID = nil; moduleID = nil }
        }
    }
}

/// The cable under the cursor in Patches mode, and the fade used to highlight it
/// while the physics simulation is running.
@MainActor
@Observable
final class CableHoverState {
    /// Duration of the highlight fade while physics is running
    static let fadeDuration: TimeInterval = 1.0 / 6.0

    private(set) var cableID: UUID?
    /// Last cursor position in world coordinates, kept to re-test as ropes move
    @ObservationIgnored private var worldPoint: CGPoint?
    @ObservationIgnored private var fadeStart = Date.distantPast
    @ObservationIgnored private var fadingIn = false

    /// Records the cursor position and hit tests it against the cables.
    func update(worldPoint: CGPoint?, geometry: CableGeometry?) {
        self.worldPoint = worldPoint
        refresh(geometry: geometry)
    }

    /// Re-tests the last cursor position, e.g. after the ropes have moved.
    func refresh(geometry: CableGeometry?) {
        let id = worldPoint.flatMap { geometry?.cable(at: $0) }
        guard id != cableID else { return }
        let hovered = id != nil
        if hovered != fadingIn {
            // Continue from the current intensity rather than restarting the fade
            let now = Date()
            let current = intensity(at: now)
            let remaining = hovered ? current : 1 - current
            fadeStart = now.addingTimeInterval(-Double(remaining) * Self.fadeDuration)
            fadingIn = hovered
        }
        cableID = id
    }

    /// Highlight intensity (0...1) of the hovered cable at `date`, eased out.
    func intensity(at date: Date = Date()) -> CGFloat {
        let t = min(max(date.timeIntervalSince(fadeStart) / Self.fadeDuration, 0), 1)
        let eased = 1 - pow(1 - CGFloat(t), 3)
        return fadingIn ? eased : 1 - eased
    }
}
