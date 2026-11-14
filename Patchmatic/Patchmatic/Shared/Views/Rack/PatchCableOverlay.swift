import SwiftUI

// MARK: - Hover intensity during physics
//
// While ropes are animating, each frame's transaction overrides SwiftUI's `.animation()`,
// so the hovered cable's highlight uses the time-based fade in `CableHoverState`.
// When physics is settled, a separate SwiftUI overlay handles hover animation.

struct PatchCableOverlay: View {
    var rackVM: RackViewModel
    var patchVM: PatchViewModel
    var zoom: CGFloat = 1.0
    /// Cable under the cursor, updated by RackView as the mouse moves
    var cableHover: CableHoverState

    @Environment(\.colorScheme) var colorScheme
    var simulator: CableSimulator { patchVM.cableSimulator }

    static let dragRopeID = UUID()

    var body: some View {
        let isDark = colorScheme == .dark
        let hoveredID = hoveredCableID
        let hoverIntensity = cableHover.intensity()
        let selectedIDs = patchVM.selectedCableIDs

        ZStack(alignment: .topLeading) {
            cableLayer(isDark: isDark, hoveredID: hoveredID, hoverIntensity: hoverIntensity, selectedIDs: selectedIDs)
        }
        .scaleEffect(zoom, anchor: .topLeading)
        .allowsHitTesting(false)
        .overlay(alignment: .topLeading) {
            settledHoverLayer
        }
        .overlay(alignment: .topLeading) {
            patchNumbersLayer
        }
        .onAppear {
            rebuildAllRopes()
            // Ropes move under a still cursor, so re-test what it is over after each step
            simulator.onStep = { [weak patchVM = self.patchVM, weak rackVM = self.rackVM, cableHover = self.cableHover] in
                guard let patchVM, let rackVM else { return }
                cableHover.refresh(geometry: CableGeometry(rackVM: rackVM, patchVM: patchVM))
            }
        }
        .onDisappear {
            simulator.onStep = nil
        }
        .onChange(of: patchVM.activePatch?.id) { _, _ in
            rebuildAllRopes()
        }
        .onChange(of: patchVM.activePatch?.cables.count) { oldValue, newValue in
            guard let newValue, let oldValue, newValue > oldValue else { return }
            cableGeometry?.addMissingRopes(adoptingDragRope: Self.dragRopeID)
        }
        .onChange(of: patchVM.dragCurrentPoint) { oldValue, newPoint in
            if oldValue == nil, newPoint != nil {
                startDragRope()
            } else if newPoint == nil {
                // Drag ended - if successful, cables.count onChange will convert the rope
                // If cancelled, rope will be cleaned up on next drag start
                return
            }

            guard let newPoint, let from = patchVM.dragFrom,
                  let patch = patchVM.activePatch,
                  let rack = rackVM.document.rack(for: patch.rackID),
                  let startPoint = rackVM.controlScreenPosition(in: rack, moduleID: from.moduleID, controlID: from.controlID)
            else { return }
            simulator.updateEndpoints(id: Self.dragRopeID, from: startPoint, to: newPoint)
        }
    }

    /// The highlighted cable: the one with a selected pin, otherwise the one under the
    /// cursor unless a new cable is being drawn.
    var hoveredCableID: UUID? {
        patchVM.selectedPinID?.cableID ?? (patchVM.dragFrom == nil ? cableHover.cableID : nil)
    }

    @ViewBuilder
    func pinMarkers(cable: PatchCable, rack: Rack, isDark: Bool, brightness: Double = 0.1) -> some View {
        let color = CableRenderer.color(for: cable, isDarkMode: isDark)
        let pinRadius: CGFloat = 4.0
        ForEach(cable.pins) { pin in
            let pos = GeometryHelpers.pinWorldPosition(pin, rack: rack)
            let isSelectedPin = patchVM.selectedPinID?.cableID == cable.id && patchVM.selectedPinID?.pinID == pin.id
            ZStack {
                if isSelectedPin {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: (pinRadius + 2) * 2, height: (pinRadius + 2) * 2)
                }
                Circle()
                    .fill(color)
                    .frame(width: pinRadius * 2, height: pinRadius * 2)
                Circle()
                    .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.0)
                    .frame(width: pinRadius * 2, height: pinRadius * 2)
            }
            .brightness(brightness)
            .position(pos)
        }
    }

    @ViewBuilder
    func cableView(from start: CGPoint, to end: CGPoint, color: some ShapeStyle, lineWidth: CGFloat) -> some View {
        let path = CableRenderer.catenaryPath(from: start, to: end)
        shadowedCable(path: path, color: color, lineWidth: lineWidth)
    }

    @ViewBuilder
    func cableShadow(path: Path, lineWidth: CGFloat) -> some View {
        path.stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: lineWidth + 1.5, lineCap: .round))
            .blur(radius: 2)
            .offset(x: 0, y: 2)
    }

    @ViewBuilder
    func shadowedCable(path: Path, color: some ShapeStyle, lineWidth: CGFloat) -> some View {
        ZStack {
            cableShadow(path: path, lineWidth: lineWidth)
            path.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }

    var cableGeometry: CableGeometry? {
        CableGeometry(rackVM: rackVM, patchVM: patchVM)
    }

    func rebuildAllRopes() {
        if let cableGeometry { cableGeometry.rebuildAllRopes() } else { simulator.removeAll() }
    }

    func startDragRope() {
        // Clean up any orphaned drag rope from previous cancelled drag
        simulator.removeRope(id: Self.dragRopeID)

        guard let from = patchVM.dragFrom,
              let dragPoint = patchVM.dragCurrentPoint,
              let patch = patchVM.activePatch,
              let rack = rackVM.document.rack(for: patch.rackID),
              let startPoint = rackVM.controlScreenPosition(in: rack, moduleID: from.moduleID, controlID: from.controlID)
        else { return }
        simulator.addRope(id: Self.dragRopeID, from: startPoint, to: dragPoint, perturbed: true, neverSettle: true)
    }

    // MARK: - Pin helpers

    /// Returns the ordered fixed-point chain for a cable: [startControl, pin0, pin1, ..., endControl]
    func segmentFixedPoints(cable: PatchCable, rack: Rack, startPoint: CGPoint, endPoint: CGPoint) -> [CGPoint] {
        var points = [startPoint]
        for pin in cable.orderedPins {
            points.append(GeometryHelpers.pinWorldPosition(pin, rack: rack))
        }
        points.append(endPoint)
        return points
    }

    struct ControlKey: Hashable {
        let moduleID: UUID
        let controlID: UUID
    }

    /// Pre-computes screen positions and radii for all cable endpoints in the active patch.
    func buildControlCache(rack: Rack, patch: Patch) -> [ControlKey: (pos: CGPoint, radius: CGFloat)] {
        var cache: [ControlKey: (pos: CGPoint, radius: CGFloat)] = [:]
        var moduleCache: [UUID: (origin: CGPoint, size: CGSize, definition: ModuleDefinition)] = [:]

        func resolveModule(_ moduleID: UUID) -> (origin: CGPoint, size: CGSize, definition: ModuleDefinition)? {
            if let cached = moduleCache[moduleID] { return cached }
            guard let placed = rack.placedModule(moduleID),
                  let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID),
                  let moduleSize = rackVM.moduleSize(for: placed)
            else { return nil }
            let origin = rackVM.moduleOrigin(for: placed)
            let entry = (origin: origin, size: moduleSize, definition: definition)
            moduleCache[moduleID] = entry
            return entry
        }

        var seen: Set<ControlKey> = []
        for cable in patch.cables {
            for (moduleID, controlID) in [(cable.fromModuleID, cable.fromControlID),
                                          (cable.toModuleID, cable.toControlID)] {
                let key = ControlKey(moduleID: moduleID, controlID: controlID)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                guard let mod = resolveModule(moduleID),
                      let control = mod.definition.controls.first(where: { $0.id == controlID })
                else { continue }
                let pos = GeometryHelpers.controlScreenPosition(
                    control: control, moduleOrigin: mod.origin, moduleSize: mod.size
                )
                cache[key] = (pos: pos, radius: control.effectiveRadius)
            }
        }

        if let from = patchVM.dragFrom {
            let key = ControlKey(moduleID: from.moduleID, controlID: from.controlID)
            if !seen.contains(key) {
                if let mod = resolveModule(from.moduleID),
                   let control = mod.definition.controls.first(where: { $0.id == from.controlID }) {
                    let pos = GeometryHelpers.controlScreenPosition(
                        control: control, moduleOrigin: mod.origin, moduleSize: mod.size
                    )
                    cache[key] = (pos: pos, radius: control.effectiveRadius)
                }
            }
        }

        return cache
    }
}
