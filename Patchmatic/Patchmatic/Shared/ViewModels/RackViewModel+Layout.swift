import SwiftUI

extension RackViewModel {
    // MARK: - Layout calculations

    func moduleOrigin(for placed: PlacedModule, in rackCase: Case) -> CGPoint {
        let x = CGFloat(placed.positionInRow) * EurorackConstants.pointsPerHP + rackCase.positionX
        let y = rackCase.positionY + rackCase.rowYOffset(placed.rowIndex)
        return CGPoint(x: x, y: y)
    }

    func moduleOrigin(for placed: PlacedModule) -> CGPoint {
        guard let rack, let rackCase = rack.caseForModule(placed.id) else { return .zero }
        return moduleOrigin(for: placed, in: rackCase)
    }

    func moduleSize(for placed: PlacedModule) -> CGSize? {
        guard let definition = document.moduleDefinition(for: placed.moduleDefinitionID)
        else { return nil }
        return CGSize(
            width: EurorackConstants.width(forHP: definition.widthHP),
            height: definition.panelHeight
        )
    }

    /// Resolves a control's absolute screen position within the rack
    func controlScreenPosition(in rack: Rack, moduleID: UUID, controlID: UUID) -> CGPoint? {
        guard let placed = rack.placedModule(moduleID),
              let definition = document.moduleDefinition(for: placed.moduleDefinitionID),
              let control = definition.controls.first(where: { $0.id == controlID }),
              let moduleSize = moduleSize(for: placed)
        else { return nil }
        let origin = moduleOrigin(for: placed)
        return GeometryHelpers.controlScreenPosition(
            control: control, moduleOrigin: origin, moduleSize: moduleSize
        )
    }

    /// Canvas size encompassing all cases plus padding
    func canvasSize() -> CGSize {
        guard let rack else { return CGSize(width: 800, height: 600) }
        let bb = rack.boundingBox()
        let padding: CGFloat = 400
        return CGSize(
            width: max(800, bb.maxX + padding),
            height: max(600, bb.maxY + caseHeaderHeight + padding)
        )
    }

    /// Content frame of a case (rows only, no header)
    func caseContentFrame(_ rackCase: Case) -> CGRect {
        CGRect(
            x: rackCase.positionX,
            y: rackCase.positionY,
            width: EurorackConstants.width(forHP: rackCase.rowWidthHP),
            height: rackCase.totalHeight()
        )
    }
    // MARK: - Hit testing

    /// Returns (case, local point within that case content) for a point in rack coordinates
    func caseAtPoint(_ point: CGPoint) -> (Case, CGPoint)? {
        guard let rack else { return nil }
        for rackCase in rack.cases {
            let frame = caseContentFrame(rackCase)
            if frame.contains(point) {
                let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
                return (rackCase, local)
            }
        }
        return nil
    }

    /// Returns the case whose title bar (header) contains the point.
    /// The header has a fixed screen size, so `zoom` is needed to compute its extent in rack coordinates.
    func caseHeaderAtPoint(_ point: CGPoint, zoom: CGFloat) -> Case? {
        guard let rack, caseHeaderHeight > 0 else { return nil }
        // The header is fixed-size in screen space, so in rack coordinates it occupies caseHeaderHeight / zoom
        let headerInRackCoords = caseHeaderHeight / zoom
        for rackCase in rack.cases {
            let headerRect = CGRect(
                x: rackCase.positionX,
                y: rackCase.positionY - headerInRackCoords,
                width: EurorackConstants.width(forHP: rackCase.rowWidthHP),
                height: headerInRackCoords
            )
            if headerRect.contains(point) {
                return rackCase
            }
        }
        return nil
    }

    /// Hit tests including the header area above the case content.
    /// The header is fixed-size in screen space, so `zoom` is needed.
    func caseAtPointForSelection(_ point: CGPoint, zoom: CGFloat = 1.0) -> Case? {
        guard let rack else { return nil }
        let headerInRackCoords = caseHeaderHeight / zoom
        for rackCase in rack.cases {
            var frame = caseContentFrame(rackCase)
            frame.origin.y -= headerInRackCoords
            frame.size.height += headerInRackCoords
            if frame.contains(point) {
                return rackCase
            }
        }
        return nil
    }

    func placedModule(at point: CGPoint) -> PlacedModule? {
        guard let rack else { return nil }
        for rackCase in rack.cases {
            for placed in rackCase.placedModules {
                let origin = moduleOrigin(for: placed, in: rackCase)
                guard let size = moduleSize(for: placed) else { continue }
                let rect = CGRect(origin: origin, size: size)
                if rect.contains(point) {
                    return placed
                }
            }
        }
        return nil
    }

    func controlAtPoint(_ point: CGPoint, in placed: PlacedModule) -> Control? {
        guard let definition = document.moduleDefinition(for: placed.moduleDefinitionID),
              let size = moduleSize(for: placed) else { return nil }
        let origin = moduleOrigin(for: placed)
        let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        return definition.controls.first {
            $0.hitTest(point: local, in: size, padding: Control.hitPadding)
        }
    }
}
