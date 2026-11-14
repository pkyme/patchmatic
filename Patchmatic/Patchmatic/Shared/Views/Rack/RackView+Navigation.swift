import SwiftUI
import UniformTypeIdentifiers

// Zooming, panning and framing the canvas
extension RackView {
    /// Multiplies the zoom by `factor` around the centre of the viewport, for toolbar
    /// and menu zooming where the cursor isn't over the canvas.
    func zoom(by factor: CGFloat) {
        let newZoom = RackViewModel.clampedZoom(currentZoom * factor)
        adjustPanForZoom(newZoom: newZoom, anchor: CGPoint(x: viewportFrame.width / 2, y: viewportFrame.height / 2))
        currentZoom = newZoom
        lastZoom = newZoom
    }

    /// Adjusts panOffset so the point at `anchor` (in viewport coordinates) stays fixed
    /// when zoom changes. Without an anchor, the point under the cursor stays fixed.
    func adjustPanForZoom(newZoom: CGFloat, anchor explicitAnchor: CGPoint? = nil) {
        let anchor = explicitAnchor ?? cursorInViewport ?? CGPoint(x: viewportFrame.width / 2, y: viewportFrame.height / 2)

        // The world point under the anchor: worldPt = (anchor - panOffset) / currentZoom
        // After zoom change we want: anchor = worldPt * newZoom + newPanOffset
        // So: newPanOffset = anchor - worldPt * newZoom
        let worldX = (anchor.x - panOffset.width) / currentZoom
        let worldY = (anchor.y - panOffset.height) / currentZoom
        panOffset = CGSize(
            width: anchor.x - worldX * newZoom,
            height: anchor.y - worldY * newZoom
        )
        lastPanOffset = panOffset
    }

    /// The cursor position in viewport coordinates, if known
    private var cursorInViewport: CGPoint? {
        #if canImport(AppKit)
        guard let window = NSApp.keyWindow, let contentView = window.contentView else { return nil }
        let mouseInWindow = window.mouseLocationOutsideOfEventStream
        let flipped = CGPoint(x: mouseInWindow.x, y: contentView.bounds.height - mouseInWindow.y)
        return CGPoint(x: flipped.x - viewportFrame.minX, y: flipped.y - viewportFrame.minY)
        #else
        return nil
        #endif
    }

    func frameRack(animated: Bool = true) {
        guard let rack = rackVM.rack, !rack.cases.isEmpty, viewportFrame.size.width > 0 else { return }
        let bb = rack.boundingBox()
        focusOnRect(bb, animated: animated)
    }

    func focusOnRect(_ rect: CGRect, animated: Bool = true) {
        guard viewportFrame.size.width > 0, rect.width > 0, rect.height > 0 else { return }

        let padding: CGFloat = 40
        let boundsWidth = rect.width + padding * 2
        let boundsHeight = rect.height + padding * 2
        let viewWidth = viewportFrame.size.width
        let viewHeight = viewportFrame.size.height

        let zoomX = viewWidth / boundsWidth
        let zoomY = viewHeight / boundsHeight
        let newZoom = min(min(zoomX, zoomY), 2.0)

        let centerX = rect.midX
        let centerY = rect.midY

        let newPan = CGSize(
            width: viewWidth / 2 - centerX * newZoom,
            height: viewHeight / 2 - centerY * newZoom
        )
        // Starting transform that renders the new framing at the old one's position
        let startScale = currentZoom / newZoom
        let startOffset = CGSize(
            width: panOffset.width - startScale * newPan.width,
            height: panOffset.height - startScale * newPan.height
        )

        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            currentZoom = newZoom
            lastZoom = newZoom
            panOffset = newPan
            lastPanOffset = newPan
            framingScale = animated ? startScale : 1
            framingOffset = animated ? startOffset : .zero
        }
        guard animated else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            framingScale = 1
            framingOffset = .zero
        }
    }

    func focusOnModules(_ moduleIDs: [UUID]) {
        guard !moduleIDs.isEmpty else { return }

        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

        for id in moduleIDs {
            guard let placed = rackVM.rack?.placedModule(id) else { continue }
            let origin = rackVM.moduleOrigin(for: placed)
            guard let size = rackVM.moduleSize(for: placed) else { continue }
            minX = min(minX, origin.x)
            minY = min(minY, origin.y)
            maxX = max(maxX, origin.x + size.width)
            maxY = max(maxY, origin.y + size.height)
        }

        guard minX < maxX, minY < maxY else { return }
        focusOnRect(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }

    func scaledPoint(_ location: CGPoint) -> CGPoint {
        CGPoint(
            x: (location.x - panOffset.width) / currentZoom,
            y: (location.y - panOffset.height) / currentZoom
        )
    }
}
