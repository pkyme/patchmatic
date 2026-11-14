import SwiftUI

// MARK: - Extracted overlay views

struct ModuleDragGhost: View {
    let rackVM: RackViewModel
    let showCables: Bool
    let zoom: CGFloat

    var body: some View {
        if !showCables,
           let dragID = rackVM.moduleDragID,
           let dragOrigin = rackVM.moduleDragOrigin,
           let rack = rackVM.rack,
           let placed = rack.placedModule(dragID),
           let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID),
           let size = rackVM.moduleSize(for: placed) {
            // Primary drag ghost
            ModulePanelView(
                definition: definition,
                panelHeight: size.height,
                knobValues: [:],
                zoom: zoom
            )
            .opacity(0.5)
            .offset(x: dragOrigin.x * zoom, y: dragOrigin.y * zoom)
            .allowsHitTesting(false)

            // Companion module ghosts (multi-drag)
            ForEach(Array(rackVM.multiDragIDs), id: \.self) { companionID in
                if let companion = rack.placedModule(companionID),
                   let compDef = rackVM.document.moduleDefinition(for: companion.moduleDefinitionID),
                   let compSize = rackVM.moduleSize(for: companion),
                   let compOrigin = rackVM.moduleOriginForCompanionDrag(companionID) {
                    ModulePanelView(
                        definition: compDef,
                        panelHeight: compSize.height,
                        knobValues: [:],
                        zoom: zoom
                    )
                    .opacity(0.5)
                    .offset(x: compOrigin.x * zoom, y: compOrigin.y * zoom)
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

struct MarqueeOverlay: View {
    let rect: CGRect?
    let zoom: CGFloat

    var body: some View {
        if let marquee = rect {
            Rectangle()
                .fill(Color.accentColor.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 1)
                )
                .frame(width: marquee.width * zoom, height: marquee.height * zoom)
                .offset(x: marquee.minX * zoom, y: marquee.minY * zoom)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Background grid

struct RackGridBackground: View {
    let panOffset: CGSize
    let zoom: CGFloat

    var body: some View {
        Canvas { context, size in
            drawLines(&context, size: size, step: 80 * zoom, opacity: 0.07, lineWidth: 0.5)
        }
    }

    private func drawLines(_ context: inout GraphicsContext, size: CGSize, step: CGFloat, opacity: Double, lineWidth: CGFloat) {
        guard step > 3 else { return }
        var path = Path()
        let xPhase = panOffset.width.truncatingRemainder(dividingBy: step)
        var x = xPhase <= 0 ? xPhase + step : xPhase
        while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
        let yPhase = panOffset.height.truncatingRemainder(dividingBy: step)
        var y = yPhase <= 0 ? yPhase + step : yPhase
        while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
        context.stroke(path, with: .color(.primary.opacity(opacity)), lineWidth: lineWidth)
    }
}
