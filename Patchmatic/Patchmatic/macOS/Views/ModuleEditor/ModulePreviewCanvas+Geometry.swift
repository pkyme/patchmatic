import SwiftUI

extension ModulePreviewCanvas {
    // MARK: - Zoom Helpers

    /// Returns the cursor position in view-local coordinates (top-left origin).
    func cursorInView() -> CGPoint {
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else { return .zero }
        let screen = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: screen)
        let flipped = CGPoint(x: windowPoint.x, y: contentView.bounds.height - windowPoint.y)
        return CGPoint(x: flipped.x - cs.viewportFrame.minX,
                       y: flipped.y - cs.viewportFrame.minY)
    }

    /// Adjusts panOffset so that `cursor` (in view-local coordinates) stays fixed as zoom changes.
    func applyZoomTowardCursor(newZoom: CGFloat, cursor: CGPoint,
                                       panOffsetAtStart: CGSize, zoomAtStart: CGFloat) {
        let r = newZoom / zoomAtStart
        let vw = cs.viewportFrame.width
        let vh = cs.viewportFrame.height
        cs.panOffset = CGSize(
            width:  (cursor.x - vw / 2) * (1 - r) + panOffsetAtStart.width  * r,
            height: (cursor.y - vh / 2) * (1 - r) + panOffsetAtStart.height * r
        )
        cs.zoom = newZoom
    }
    // MARK: - Layout

    func fitScale(viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> CGFloat {
        min(viewSize.width / panelWidth, viewSize.height / panelHeight)
    }
    // MARK: - Hit Testing

    /// Returns all control IDs under the point, in definition order (first = bottom, last = top).
    func hitTestAllControls(at viewPoint: CGPoint, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> [UUID] {
        let (scale, offsetX, offsetY) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        let panelPoint = CGPoint(
            x: (viewPoint.x - offsetX) / scale,
            y: (viewPoint.y - offsetY) / scale
        )
        let panelSize = CGSize(width: panelWidth, height: panelHeight)

        return definition.controls
            .filter { $0.hitTest(point: panelPoint, in: panelSize, padding: Control.hitPadding) }
            .map(\.id)
    }

    /// Returns the topmost control under the point.
    func hitTestControl(at viewPoint: CGPoint, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> UUID? {
        hitTestAllControls(at: viewPoint, viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight).last
    }

    /// For clicks on overlapping controls: cycles to the next control after the currently selected one.
    /// If none of the hits are selected, returns the topmost.
    func hitTestCycling(at viewPoint: CGPoint, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> UUID? {
        let hits = hitTestAllControls(at: viewPoint, viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        guard !hits.isEmpty else { return nil }
        // Find the selected item in the hit list
        if let selectedIdx = hits.lastIndex(where: { selectedControlIDs.contains($0) }) {
            // Cycle to the next one (wrapping around)
            let nextIdx = (selectedIdx + 1) % hits.count
            return hits[nextIdx]
        }
        return hits.last
    }

    /// For drags on overlapping controls: prefer the already-selected item, otherwise topmost.
    func hitTestForDrag(at viewPoint: CGPoint, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> UUID? {
        let hits = hitTestAllControls(at: viewPoint, viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        guard !hits.isEmpty else { return nil }
        // Prefer a hit that's already selected
        if let selected = hits.last(where: { selectedControlIDs.contains($0) }) {
            return selected
        }
        return hits.last
    }
    // MARK: - Resize Handle Hit Testing

    func isOnResizeHandle(at viewPoint: CGPoint, control: Control, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> Bool {
        let (scale, offsetX, offsetY) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        let panelSize = CGSize(width: panelWidth, height: panelHeight)
        let center = control.position.toPoint(in: panelSize)
        let handlePanelPoint: CGPoint
        switch control.kind {
        case .screen:
            handlePanelPoint = CGPoint(x: center.x + CGFloat(control.screenWidth) / 2,
                                       y: center.y + CGFloat(control.screenHeight) / 2)
        case .slider:
            let half = CGFloat(control.sliderTrackLength) / 2
            handlePanelPoint = control.orientation == .vertical
                ? CGPoint(x: center.x, y: center.y + half)
                : CGPoint(x: center.x + half, y: center.y)
        default:
            return false
        }
        let handleViewX = handlePanelPoint.x * scale + offsetX
        let handleViewY = handlePanelPoint.y * scale + offsetY
        return GeometryHelpers.distance(from: viewPoint, to: CGPoint(x: handleViewX, y: handleViewY)) <= 12
    }
    // MARK: - Marquee

    func controlsInMarquee(start: CGPoint, end: CGPoint, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> Set<UUID> {
        let (scale, offsetX, offsetY) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        let panelSize = CGSize(width: panelWidth, height: panelHeight)

        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)

        var ids = Set<UUID>()
        for control in definition.controls {
            let center = control.position.toPoint(in: panelSize)
            let screenX = center.x * scale + offsetX
            let screenY = center.y * scale + offsetY
            if screenX >= minX && screenX <= maxX && screenY >= minY && screenY <= maxY {
                ids.insert(control.id)
            }
        }
        return ids
    }
    // MARK: - Coordinate Transforms

    func zoomedTransform(viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> (scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let baseScale = fitScale(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        let scale = baseScale * cs.zoom
        let offsetX = viewSize.width / 2 + cs.panOffset.width - panelWidth * scale / 2
        let offsetY = viewSize.height / 2 + cs.panOffset.height - panelHeight * scale / 2
        return (scale, offsetX, offsetY)
    }

    func viewPointToNormalized(_ point: CGPoint, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) -> NormalizedPoint {
        let (scale, offsetX, offsetY) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
        let panelX = (point.x - offsetX) / scale
        let panelY = (point.y - offsetY) / scale
        return NormalizedPoint(
            x: panelX / panelWidth,
            y: panelY / panelHeight
        )
    }
}
