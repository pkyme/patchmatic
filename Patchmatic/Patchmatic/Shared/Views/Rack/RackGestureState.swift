import SwiftUI

/// Transient state of the rack canvas drag gesture, shared by its handlers in each mode.
struct RackGestureState {
    /// What a drag in Patches mode is doing. Cable, knob and slider drags are tracked
    /// by PatchViewModel while this is `.idle`.
    enum CableDrag: Equatable {
        case idle
        /// Second click of a double-click; deactivates the control on release
        case doubleClick
        case pin(cableID: UUID, pinID: UUID)
        case pan
        /// Shift-click awaiting release (toggles cable selection) or a drag (marquee)
        case shiftClick
        /// Shift-drag selecting cables, keeping those selected when it began
        case cableMarquee(start: CGPoint, baseSelection: Set<UUID>)
        /// Shift-drag selecting modules while groups are shown
        case groupMarquee(start: CGPoint)
        /// Click on a module body while groups are shown; selects on release, pans if dragged
        case groupSelecting
        /// Press on a toggle, button or screen, acted on at release
        case control(Control.Kind)
    }

    /// What a drag in Racks mode is doing
    enum RackDrag: Equatable {
        case idle
        case module
        case marquee(start: CGPoint)
        case caseDrag
        case pan
    }

    // Double-click detection
    var lastDragStartTime: Date?
    var lastDragStartLocation: CGPoint?

    var cableDrag: CableDrag = .idle
    var rackDrag: RackDrag = .idle
    /// Button drawn pressed while the pointer is down on it
    var pressedControlID: UUID?
    /// Panning in read-only Sets mode
    var isPanningInReadOnlyMode = false
}
