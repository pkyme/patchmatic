import SwiftUI

struct PatchPrintView: View {
    let rack: Rack
    let patch: Patch
    let rackVM: RackViewModel
    let patchVM: PatchViewModel
    let isDarkMode: Bool
    let showPatchNumbers: Bool

    var body: some View {
        let bb = rack.boundingBox()
        let contentWidth = bb.width
        let contentHeight = bb.height

        VStack(alignment: .leading, spacing: 8) {
            Text(patch.name)
                .font(.title2.bold())
            Text(rack.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !patch.patchNotes.isEmpty {
                Text(patch.patchNotes)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: contentWidth, alignment: .leading)
            }

            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: contentWidth, height: contentHeight)

                ForEach(rack.cases) { rackCase in
                    CaseView(
                        rackCase: rackCase,
                        rackVM: rackVM,
                        patchVM: patchVM,
                        showKnobValues: true,
                        labelsIgnoreActivation: true,
                        isDarkMode: isDarkMode,
                        zoom: 1.0
                    )
                    .offset(
                        x: rackCase.positionX - bb.minX,
                        y: rackCase.positionY - bb.minY
                    )
                }

                PatchPrintCableLayer(
                    rack: rack,
                    patch: patch,
                    rackVM: rackVM,
                    patchVM: patchVM,
                    isDarkMode: isDarkMode,
                    offset: CGPoint(x: -bb.minX, y: -bb.minY)
                )
                .frame(width: contentWidth, height: contentHeight)

                if showPatchNumbers {
                    PatchPointNumberOverlay(
                        rack: rack,
                        patch: patch,
                        rackVM: rackVM,
                        patchVM: patchVM,
                        hoveredCableID: nil,
                        isDarkMode: isDarkMode,
                        zoom: 1.0
                    )
                    .offset(x: -bb.minX, y: -bb.minY)
                }
            }
            .frame(width: contentWidth, height: contentHeight)
        }
        .padding(20)
    }
}

// MARK: - Static cable layer for print output

private struct PatchPrintCableLayer: View {
    let rack: Rack
    let patch: Patch
    let rackVM: RackViewModel
    let patchVM: PatchViewModel
    let isDarkMode: Bool
    let offset: CGPoint

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Cable paths — use physics rest state when available, fall back to catenary
            ForEach(patch.cables) { cable in
                cablePath(cable)
                    .stroke(CableRenderer.color(for: cable, isDarkMode: isDarkMode),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // Connection circles on top
            ForEach(connectionCircles(), id: \.id) { info in
                Circle()
                    .fill(info.color)
                    .frame(width: info.radius * 2, height: info.radius * 2)
                    .overlay {
                        Circle()
                            .fill(info.color.opacity(0.45))
                            .frame(width: info.radius * 0.65 * 2, height: info.radius * 0.65 * 2)
                    }
                    .position(x: info.pos.x, y: info.pos.y)
            }
        }
        .offset(x: offset.x, y: offset.y)
    }

    private struct CircleInfo: Identifiable {
        let id: String
        let pos: CGPoint
        let radius: CGFloat
        let color: Color
    }

    private func connectionCircles() -> [CircleInfo] {
        var result: [CircleInfo] = []
        var seen = Set<String>()
        for cable in patch.cables {
            let color = CableRenderer.color(for: cable, isDarkMode: isDarkMode)
            for (moduleID, controlID) in [(cable.fromModuleID, cable.fromControlID),
                                          (cable.toModuleID, cable.toControlID)] {
                let key = "\(moduleID)-\(controlID)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                guard let pos = controlPosition(moduleID: moduleID, controlID: controlID),
                      let placed = rack.placedModule(moduleID),
                      let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID),
                      let control = definition.controls.first(where: { $0.id == controlID })
                else { continue }
                result.append(CircleInfo(id: key, pos: pos, radius: control.effectiveRadius, color: color))
            }
        }
        return result
    }

    /// The cable's path through its pins, from the physics rest state of each segment
    /// when available, otherwise a catenary per segment.
    private func cablePath(_ cable: PatchCable) -> Path {
        var path = Path()
        guard let start = controlPosition(moduleID: cable.fromModuleID, controlID: cable.fromControlID),
              let end = controlPosition(moduleID: cable.toModuleID, controlID: cable.toControlID)
        else { return path }
        let points = [start] + cable.orderedPins.map { GeometryHelpers.pinWorldPosition($0, rack: rack) } + [end]
        for segment in 0..<cable.segmentCount {
            if let simulated = patchVM.cableSimulator.pathForRope(id: cable.segmentRopeID(segment)) {
                path.addPath(simulated)
            } else {
                path.addPath(CableRenderer.catenaryPath(from: points[segment], to: points[segment + 1]))
            }
        }
        return path
    }

    private func controlPosition(moduleID: UUID, controlID: UUID) -> CGPoint? {
        guard let placed = rack.placedModule(moduleID),
              let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID),
              let control = definition.controls.first(where: { $0.id == controlID }),
              let moduleSize = rackVM.moduleSize(for: placed)
        else { return nil }

        let origin = rackVM.moduleOrigin(for: placed)
        return GeometryHelpers.controlScreenPosition(
            control: control, moduleOrigin: origin, moduleSize: moduleSize
        )
    }
}
