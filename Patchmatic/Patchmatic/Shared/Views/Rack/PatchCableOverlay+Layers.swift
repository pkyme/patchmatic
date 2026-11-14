import SwiftUI

// The layers drawn by PatchCableOverlay
extension PatchCableOverlay {
    /// Selection outlines, cables with their shadows, patch point circles and the hovered cable's pins
    @ViewBuilder func cableLayer(isDark: Bool, hoveredID: UUID?, hoverIntensity: CGFloat, selectedIDs: Set<UUID>) -> some View {
        // Selection outlines (rendered behind cables)
        if let patch = patchVM.activePatch {
            ForEach(patch.cables) { cable in
                if selectedIDs.contains(cable.id) {
                    ForEach(0..<cable.segmentCount, id: \.self) { seg in
                        if let path = simulator.pathForRope(id: cable.segmentRopeID(seg)) {
                            path.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        }
                    }
                }
            }
        }

        // Cables: two passes per cable so segment shadows don't overlap segment strokes.
        let physicsActive = simulator.hasActiveRopes
        if let patch = patchVM.activePatch,
           let rack = rackVM.document.rack(for: patch.rackID) {
            let controlCache = buildControlCache(rack: rack, patch: patch)

            ForEach(patch.cables) { cable in
                let color = CableRenderer.color(for: cable, isDarkMode: isDark)
                let intensity = (physicsActive && cable.id == hoveredID) ? hoverIntensity : 0.0
                let lineWidth = 2.5 + intensity * 0.5
                let fixedPoints: [CGPoint] = {
                    guard let s = controlCache[ControlKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID)],
                          let e = controlCache[ControlKey(moduleID: cable.toModuleID, controlID: cable.toControlID)]
                    else { return [] }
                    return segmentFixedPoints(cable: cable, rack: rack, startPoint: s.pos, endPoint: e.pos)
                }()
                // Pass 1: shadows
                ForEach(0..<cable.segmentCount, id: \.self) { seg in
                    let path: Path? = simulator.pathForRope(id: cable.segmentRopeID(seg))
                        ?? (fixedPoints.count > seg + 1 ? CableRenderer.catenaryPath(from: fixedPoints[seg], to: fixedPoints[seg + 1]) : nil)
                    if let path {
                        cableShadow(path: path, lineWidth: lineWidth)
                    }
                }
                // Pass 2: strokes
                ForEach(0..<cable.segmentCount, id: \.self) { seg in
                    let path: Path? = simulator.pathForRope(id: cable.segmentRopeID(seg))
                        ?? (fixedPoints.count > seg + 1 ? CableRenderer.catenaryPath(from: fixedPoints[seg], to: fixedPoints[seg + 1]) : nil)
                    if let path {
                        path.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            .brightness(Double(intensity) * 0.1)
                    }
                }
            }

            if patchVM.dragFrom != nil, let dragPath = simulator.pathForRope(id: Self.dragRopeID) {
                let nextIndex = patch.nextCableColorIndex
                let color = CableRenderer.color(forIndex: nextIndex, isDarkMode: isDark)
                shadowedCable(path: dragPath, color: color.opacity(0.7), lineWidth: 2.0)
            } else if let from = patchVM.dragFrom,
                      let dragPoint = patchVM.dragCurrentPoint,
                      let startPoint = controlCache[ControlKey(moduleID: from.moduleID, controlID: from.controlID)]?.pos {
                let nextIndex = patch.nextCableColorIndex
                let color = CableRenderer.color(forIndex: nextIndex, isDarkMode: isDark)
                cableView(from: startPoint, to: dragPoint, color: color.opacity(0.7), lineWidth: 2.0)
            }

            // Redraw connection circles on top of cables and their shadows
            Canvas { ctx, _ in
                func drawCircle(key: ControlKey, color: Color, selected: Bool = false, intensity: CGFloat = 0) {
                    guard let entry = controlCache[key] else { return }
                    let pos = entry.pos
                    let radius = entry.radius

                    if selected {
                        ctx.fill(Path(circleAt: pos, radius: radius + 2), with: .color(Color.accentColor))
                    }

                    let drawRadius = radius * (1.0 + intensity * 0.1)
                    var circleCtx = ctx
                    if intensity > 0.001 {
                        circleCtx.addFilter(.brightness(intensity * 0.1))
                    }
                    circleCtx.fill(Path(circleAt: pos, radius: drawRadius), with: .color(color))
                    let innerRadius = drawRadius * 0.65
                    var innerCtx = ctx
                    innerCtx.blendMode = .multiply
                    if intensity > 0.001 { innerCtx.addFilter(.brightness(intensity * 0.1)) }
                    innerCtx.fill(Path(circleAt: pos, radius: innerRadius), with: .color(.init(white: 0.55 + intensity * 0.05)))
                }

                for cable in patch.cables {
                    let color = CableRenderer.color(for: cable, isDarkMode: isDark)
                    let selected = selectedIDs.contains(cable.id)
                    let intensity = (physicsActive && cable.id == hoveredID) ? hoverIntensity : 0.0
                    drawCircle(key: ControlKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID), color: color, selected: selected, intensity: intensity)
                    drawCircle(key: ControlKey(moduleID: cable.toModuleID, controlID: cable.toControlID), color: color, selected: selected, intensity: intensity)
                }

                if let from = patchVM.dragFrom {
                    let nextIndex = patch.nextCableColorIndex
                    let color = CableRenderer.color(forIndex: nextIndex, isDarkMode: isDark)
                    drawCircle(key: ControlKey(moduleID: from.moduleID, controlID: from.controlID), color: color)
                }

            }

            // Pin markers (Path-based, not Canvas, to avoid frame clipping)
            // Only shown for the hovered cable, matching the settled-mode behaviour.
            if let hoveredCableID = hoveredID,
               let cable = patch.cables.first(where: { $0.id == hoveredCableID }) {
                pinMarkers(cable: cable, rack: rack, isDark: isDark, brightness: 0)
            }

        }
    }

    /// Hover highlight drawn over the cables once the physics has settled, animated by SwiftUI
    @ViewBuilder var settledHoverLayer: some View {
        if !simulator.hasActiveRopes,
           let patch = patchVM.activePatch,
           let rack = rackVM.document.rack(for: patch.rackID) {
            let isDark = colorScheme == .dark
            let activeID = hoveredCableID
            let hoverCache = buildControlCache(rack: rack, patch: patch)
            ZStack(alignment: .topLeading) {
                ForEach(patch.cables) { cable in
                    let isActive = cable.id == activeID
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<cable.segmentCount, id: \.self) { seg in
                            if let path = simulator.pathForRope(id: cable.segmentRopeID(seg)) {
                                let color = CableRenderer.color(for: cable, isDarkMode: isDark)
                                path.stroke(color, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                                    .brightness(0.1)
                            }
                        }
                        Canvas { ctx, _ in
                            let color = CableRenderer.color(for: cable, isDarkMode: isDark)
                            for key in [ControlKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID),
                                        ControlKey(moduleID: cable.toModuleID, controlID: cable.toControlID)] {
                                guard let entry = hoverCache[key] else { continue }
                                let pos = entry.pos
                                let radius = entry.radius * 1.1
                                ctx.fill(Path(circleAt: pos, radius: radius), with: .color(color))
                                let innerRadius = radius * 0.65
                                var innerCtx = ctx
                                innerCtx.blendMode = .multiply
                                innerCtx.fill(Path(circleAt: pos, radius: innerRadius), with: .color(.init(white: 0.6)))
                            }
                        }
                        .brightness(0.1)
                        // Pin markers on top of hovered cable
                        pinMarkers(cable: cable, rack: rack, isDark: isDark)
                    }
                    .compositingGroup()
                    .opacity(isActive ? 1 : 0)
                }
            }
            .scaleEffect(zoom, anchor: .topLeading)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.08), value: activeID)
        }
    }

    /// Patch point number badges, when shown
    @ViewBuilder var patchNumbersLayer: some View {
        if rackVM.showPatchNumbers,
           let patch = patchVM.activePatch,
           let rack = rackVM.document.rack(for: patch.rackID) {
            PatchPointNumberCanvasOverlay(
                rack: rack,
                patch: patch,
                rackVM: rackVM,
                patchVM: patchVM,
                hoveredCableID: hoveredCableID,
                isDarkMode: colorScheme == .dark,
                zoom: zoom
            )
            .allowsHitTesting(false)
        }
    }
}
