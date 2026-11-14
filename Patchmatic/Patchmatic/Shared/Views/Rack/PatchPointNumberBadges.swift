import SwiftUI

// MARK: - Patch point number badges (native SwiftUI for crisp text at any zoom)

/// Size and colours of patch point number badges, shared by the view and canvas versions.
enum PatchPointBadgeStyle {
    /// Badge radius for a patch point of `controlRadius` (in display points)
    static func radius(controlRadius: CGFloat, highlighted: Bool) -> CGFloat {
        max(controlRadius * 0.6875, highlighted ? 11.25 : 8.75)
    }

    static func fontSize(badgeRadius: CGFloat) -> CGFloat {
        max(badgeRadius * 1.2, 6)
    }

    static func font(badgeRadius: CGFloat) -> Font {
        .system(size: fontSize(badgeRadius: badgeRadius), weight: .bold, design: .rounded)
    }

    static func foreground(isDarkMode: Bool) -> Color {
        isDarkMode ? .black : .white
    }

    static func background(isDarkMode: Bool, highlighted: Bool) -> Color {
        isDarkMode ? Color(white: highlighted ? 1.0 : 0.85) : .black
    }

    static let shadowColor = Color.black.opacity(0.5)
}

struct PatchPointNumberBadge: View {
    let number: Int
    let radius: CGFloat
    let isDarkMode: Bool
    let highlighted: Bool
    @Environment(\.drawsShadows) private var drawsShadows

    var body: some View {
        let badgeR = PatchPointBadgeStyle.radius(controlRadius: radius, highlighted: highlighted)

        Text("\(number)")
            .font(PatchPointBadgeStyle.font(badgeRadius: badgeR))
            .foregroundStyle(PatchPointBadgeStyle.foreground(isDarkMode: isDarkMode))
            .frame(width: badgeR * 2, height: badgeR * 2)
            .background {
                Circle()
                    .fill(PatchPointBadgeStyle.background(isDarkMode: isDarkMode, highlighted: highlighted))
                    .shadow(color: drawsShadows ? PatchPointBadgeStyle.shadowColor : .clear, radius: 1.5, y: 0.5)
            }
    }
}

// MARK: - Shared badge building

struct PatchPointBadgeInfo {
    let key: PatchPointKey
    let number: Int
    let pos: CGPoint
    let radius: CGFloat
}

@MainActor
func buildPatchPointBadges(
    rack: Rack, patch: Patch, rackVM: RackViewModel, patchVM: PatchViewModel
) -> [PatchPointBadgeInfo] {
    var result: [PatchPointBadgeInfo] = []
    var drawn = Set<PatchPointKey>()
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

    for cable in patch.cables {
        for (moduleID, controlID) in [(cable.fromModuleID, cable.fromControlID),
                                      (cable.toModuleID, cable.toControlID)] {
            let key = PatchPointKey(moduleID: moduleID, controlID: controlID)
            guard !drawn.contains(key) else { continue }
            drawn.insert(key)
            guard let number = patchVM.patchPointNumber(moduleID: moduleID, controlID: controlID),
                  let mod = resolveModule(moduleID),
                  let control = mod.definition.controls.first(where: { $0.id == controlID })
            else { continue }
            let pos = GeometryHelpers.controlScreenPosition(
                control: control, moduleOrigin: mod.origin, moduleSize: mod.size
            )
            result.append(PatchPointBadgeInfo(key: key, number: number, pos: pos, radius: control.effectiveRadius))
        }
    }
    return result
}

func hoveredPatchPoints(hoveredCableID: UUID?, patch: Patch) -> Set<PatchPointKey> {
    guard let hoveredCableID,
          let cable = patch.cables.first(where: { $0.id == hoveredCableID })
    else { return [] }
    return [
        PatchPointKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID),
        PatchPointKey(moduleID: cable.toModuleID, controlID: cable.toControlID)
    ]
}

// MARK: - SwiftUI badge overlay

struct PatchPointNumberOverlay: View {
    let rack: Rack
    let patch: Patch
    let rackVM: RackViewModel
    let patchVM: PatchViewModel
    let hoveredCableID: UUID?
    let isDarkMode: Bool
    let zoom: CGFloat

    var body: some View {
        let hoveredPoints = hoveredPatchPoints(hoveredCableID: hoveredCableID, patch: patch)
        let badges = buildPatchPointBadges(rack: rack, patch: patch, rackVM: rackVM, patchVM: patchVM)

        ForEach(badges, id: \.key) { badge in
            PatchPointNumberBadge(
                number: badge.number,
                radius: badge.radius * zoom,
                isDarkMode: isDarkMode,
                highlighted: hoveredPoints.contains(badge.key)
            )
            .position(x: badge.pos.x * zoom, y: badge.pos.y * zoom)
        }
    }
}

// MARK: - Canvas-based badge overlay (single draw call, no per-badge views)

struct PatchPointNumberCanvasOverlay: View {
    let rack: Rack
    let patch: Patch
    let rackVM: RackViewModel
    let patchVM: PatchViewModel
    let hoveredCableID: UUID?
    let isDarkMode: Bool
    let zoom: CGFloat

    var body: some View {
        let hoveredPoints = hoveredPatchPoints(hoveredCableID: hoveredCableID, patch: patch)
        let badges = buildPatchPointBadges(rack: rack, patch: patch, rackVM: rackVM, patchVM: patchVM)

        Canvas { ctx, _ in
            let fg = PatchPointBadgeStyle.foreground(isDarkMode: isDarkMode)

            for badge in badges {
                let highlighted = hoveredPoints.contains(badge.key)
                let badgeR = PatchPointBadgeStyle.radius(controlRadius: badge.radius * zoom, highlighted: highlighted)
                let x = badge.pos.x * zoom
                let y = badge.pos.y * zoom

                // Shadow circle
                let badgeCenter = CGPoint(x: x, y: y)
                var shadowCtx = ctx
                shadowCtx.addFilter(.blur(radius: 1.5))
                shadowCtx.fill(Path(circleAt: CGPoint(x: x, y: y + 0.5), radius: badgeR), with: .color(PatchPointBadgeStyle.shadowColor))

                // Background circle
                let badgeBg = PatchPointBadgeStyle.background(isDarkMode: isDarkMode, highlighted: highlighted)
                ctx.fill(Path(circleAt: badgeCenter, radius: badgeR), with: .color(badgeBg))

                // Number text
                let text = Text("\(badge.number)")
                    .font(PatchPointBadgeStyle.font(badgeRadius: badgeR))
                    .foregroundStyle(fg)
                let resolved = ctx.resolve(text)
                ctx.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
            }
        }
        .allowsHitTesting(false)
    }
}
