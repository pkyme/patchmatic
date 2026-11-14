import SwiftUI

struct ScreenImageCropView: View {
    let sourceImage: PlatformImage
    let aspectRatio: Double
    let onCrop: (PlatformImage) -> Void

    @Environment(\.dismiss) private var dismiss
    /// Crop origin and size stored as fractions of the source image (0...1)
    @State private var normCropX: CGFloat = 0
    @State private var normCropY: CGFloat = 0
    @State private var normCropW: CGFloat = 0
    @State private var normCropH: CGFloat = 0
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var initialized = false
    @State private var scrollOffset: CGPoint = .zero
    @State private var lockAspectRatio = true
    @State private var cropEnabled = false

    private enum DragMode {
        case move
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
    }

    @State private var dragMode: DragMode?
    @State private var dragStartX: CGFloat = 0
    @State private var dragStartY: CGFloat = 0
    @State private var dragStartW: CGFloat = 0
    @State private var dragStartH: CGFloat = 0

    private let handleSize: CGFloat = 10
    private let minNormDimension: CGFloat = 0.02

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("Crop Image", isOn: $cropEnabled)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                Toggle("Lock Aspect Ratio", isOn: $lockAspectRatio)
                    .toggleStyle(.checkbox)
                    .fixedSize()
                    .disabled(!cropEnabled)
                    .onChange(of: lockAspectRatio) { _, locked in
                        if locked { applyLockedAspectRatio() }
                    }
                Spacer()
                Text("\(Int(zoom * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                Slider(value: $zoom, in: 1...5)
                    .frame(width: 120)
                Button {
                    zoom = 1.0
                    lastZoom = 1.0
                } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                .buttonStyle(.borderless)
            }

            GeometryReader { geo in
                let imgW = sourceImage.size.width
                let imgH = sourceImage.size.height
                let fitScale = (imgW > 0 && imgH > 0)
                    ? min(geo.size.width / imgW, geo.size.height / imgH)
                    : 1.0
                let baseW = imgW * fitScale
                let baseH = imgH * fitScale
                let zoomedW = baseW * zoom
                let zoomedH = baseH * zoom

                // Crop rect in zoomed pixel coordinates
                let cropX = normCropX * zoomedW
                let cropY = normCropY * zoomedH
                let cropW = normCropW * zoomedW
                let cropH = normCropH * zoomedH

                CropScrollView(
                    contentSize: CGSize(width: zoomedW, height: zoomedH),
                    scrollOffset: scrollOffset,
                    content: {
                        AnyView(
                            ZStack(alignment: .topLeading) {
                                Image(platformImage: sourceImage)
                                    .resizable()
                                    .frame(width: zoomedW, height: zoomedH)

                                if cropEnabled {
                                    // Dimmed overlay outside crop
                                    Path { path in
                                        path.addRect(CGRect(x: 0, y: 0, width: zoomedW, height: zoomedH))
                                        path.addRect(CGRect(x: cropX, y: cropY, width: cropW, height: cropH))
                                    }
                                    .fill(style: FillStyle(eoFill: true))
                                    .foregroundStyle(.black.opacity(0.4))
                                    .allowsHitTesting(false)

                                    // Crop border
                                    Rectangle()
                                        .stroke(.white, lineWidth: 2)
                                        .frame(width: cropW, height: cropH)
                                        .offset(x: cropX, y: cropY)
                                        .allowsHitTesting(false)

                                    // Corner handles
                                    cornerHandle(at: CGPoint(x: cropX, y: cropY))
                                    cornerHandle(at: CGPoint(x: cropX + cropW, y: cropY))
                                    cornerHandle(at: CGPoint(x: cropX, y: cropY + cropH))
                                    cornerHandle(at: CGPoint(x: cropX + cropW, y: cropY + cropH))
                                }
                            }
                            .frame(width: zoomedW, height: zoomedH)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        let dx = value.translation.width / zoomedW
                                        let dy = value.translation.height / zoomedH

                                        // Lock drag mode once at the start of the gesture
                                        if dragMode == nil {
                                            dragStartX = normCropX
                                            dragStartY = normCropY
                                            dragStartW = normCropW
                                            dragStartH = normCropH
                                            let startNormX = value.startLocation.x / zoomedW
                                            let startNormY = value.startLocation.y / zoomedH
                                            dragMode = hitTestHandle(normX: startNormX, normY: startNormY)
                                        }

                                        switch dragMode {
                                        case .move:
                                            normCropX = clamp(dragStartX + dx, 0, 1 - normCropW)
                                            normCropY = clamp(dragStartY + dy, 0, 1 - normCropH)
                                        case .resizeBottomRight:
                                            resizeCorner(dx: dx, dy: dy, anchorX: dragStartX, anchorY: dragStartY,
                                                         growRight: true, growDown: true)
                                        case .resizeBottomLeft:
                                            resizeCorner(dx: dx, dy: dy, anchorX: dragStartX + dragStartW, anchorY: dragStartY,
                                                         growRight: false, growDown: true)
                                        case .resizeTopRight:
                                            resizeCorner(dx: dx, dy: dy, anchorX: dragStartX, anchorY: dragStartY + dragStartH,
                                                         growRight: true, growDown: false)
                                        case .resizeTopLeft:
                                            resizeCorner(dx: dx, dy: dy, anchorX: dragStartX + dragStartW, anchorY: dragStartY + dragStartH,
                                                         growRight: false, growDown: false)
                                        case nil:
                                            break
                                        }
                                    }
                                    .onEnded { _ in
                                        dragMode = nil
                                    },
                                including: cropEnabled ? .all : .none
                            )
                        )
                    }
                )
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            zoom = clamp(lastZoom * value.magnification, 1, 5)
                        }
                        .onEnded { _ in
                            lastZoom = zoom
                        }
                )
                .onAppear {
                    guard !initialized else { return }
                    initialized = true
                    initCrop()
                }
                .onChange(of: zoom) { _, newZoom in
                    let newZoomedW = baseW * newZoom
                    let newZoomedH = baseH * newZoom
                    let cx = (normCropX + normCropW / 2) * newZoomedW
                    let cy = (normCropY + normCropH / 2) * newZoomedH
                    scrollOffset = CGPoint(
                        x: max(0, cx - geo.size.width / 2),
                        y: max(0, cy - geo.size.height / 2)
                    )
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button(cropEnabled ? "Crop" : "Use Image") {
                    onCrop(cropEnabled ? performCrop() : sourceImage)
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(minWidth: 500, idealWidth: 600, minHeight: 420, idealHeight: 500)
    }

    // MARK: - Corner handles

    private func cornerHandle(at point: CGPoint) -> some View {
        Rectangle()
            .fill(.white)
            .frame(width: handleSize, height: handleSize)
            .position(x: point.x, y: point.y)
            .allowsHitTesting(false)
    }

    private func hitTestHandle(normX: CGFloat, normY: CGFloat) -> DragMode {
        let threshold: CGFloat = 0.03 / zoom
        let corners: [(CGFloat, CGFloat, DragMode)] = [
            (normCropX, normCropY, .resizeTopLeft),
            (normCropX + normCropW, normCropY, .resizeTopRight),
            (normCropX, normCropY + normCropH, .resizeBottomLeft),
            (normCropX + normCropW, normCropY + normCropH, .resizeBottomRight),
        ]
        for (cx, cy, mode) in corners {
            if abs(normX - cx) < threshold && abs(normY - cy) < threshold {
                return mode
            }
        }
        return .move
    }

    // MARK: - Resize logic

    private func resizeCorner(dx: CGFloat, dy: CGFloat, anchorX: CGFloat, anchorY: CGFloat,
                              growRight: Bool, growDown: Bool) {
        let rawDW = growRight ? dx : -dx
        let rawDH = growDown ? dy : -dy

        guard lockAspectRatio else {
            let maxW = growRight ? 1 - anchorX : anchorX
            let maxH = growDown ? 1 - anchorY : anchorY
            let finalW = clamp(dragStartW + rawDW, minNormDimension, maxW)
            let finalH = clamp(dragStartH + rawDH, minNormDimension, maxH)
            normCropW = finalW
            normCropH = finalH
            normCropX = growRight ? anchorX : anchorX - finalW
            normCropY = growDown ? anchorY : anchorY - finalH
            return
        }

        let imgAR = sourceImage.size.width / sourceImage.size.height
        let normAR = aspectRatio / imgAR

        // Use the average of both axes for smooth diagonal resizing
        let fromW = rawDW
        let fromH = rawDH * normAR
        let combined = (fromW + fromH) / 2

        let newW = max(minNormDimension, dragStartW + combined)

        let maxW = growRight ? 1 - anchorX : anchorX
        let maxH = growDown ? 1 - anchorY : anchorY
        let finalW = min(newW, maxW, maxH * normAR)
        let finalH = finalW / normAR

        guard finalW >= minNormDimension, finalH >= minNormDimension else { return }
        guard (growRight ? anchorX : anchorX - finalW) >= 0,
              (growDown ? anchorY : anchorY - finalH) >= 0 else { return }

        normCropW = finalW
        normCropH = finalH
        normCropX = growRight ? anchorX : anchorX - finalW
        normCropY = growDown ? anchorY : anchorY - finalH
    }

    private func clamp(_ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(value, lo), hi)
    }

    // MARK: - Layout

    private func initCrop() {
        let imgAR = sourceImage.size.width / sourceImage.size.height
        let normAR = aspectRatio / imgAR

        // Start with crop covering 60% of image height
        let h: CGFloat = 0.6
        let w = h * normAR
        let finalW = min(w, 1.0)
        let finalH = min(finalW / normAR, 1.0)

        normCropW = finalW
        normCropH = finalH
        normCropX = (1 - finalW) / 2
        normCropY = (1 - finalH) / 2
    }

    /// Reshapes the current crop to the screen's aspect ratio, keeping its center and fitting within the image.
    private func applyLockedAspectRatio() {
        let imgAR = sourceImage.size.width / sourceImage.size.height
        let normAR = aspectRatio / imgAR
        let cx = normCropX + normCropW / 2
        let cy = normCropY + normCropH / 2

        var w = sqrt(normCropW * normCropH * normAR)
        var h = w / normAR
        let maxW = 2 * min(cx, 1 - cx)
        let maxH = 2 * min(cy, 1 - cy)
        if w > maxW { w = maxW; h = w / normAR }
        if h > maxH { h = maxH; w = h * normAR }

        normCropW = w
        normCropH = h
        normCropX = cx - w / 2
        normCropY = cy - h / 2
    }

    // MARK: - Crop

    private func performCrop() -> PlatformImage {
        guard let cgImage = sourceImage.platformCGImage else { return sourceImage }
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        guard imgW > 0, imgH > 0, normCropW > 0, normCropH > 0 else { return sourceImage }

        let cropRect = CGRect(
            x: normCropX * imgW,
            y: normCropY * imgH,
            width: normCropW * imgW,
            height: normCropH * imgH
        )

        guard let croppedCG = cgImage.cropping(to: cropRect) else { return sourceImage }

        return NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))
    }
}

// MARK: - NSScrollView wrapper with programmatic scroll position control

private struct CropScrollView: NSViewRepresentable {
    let contentSize: CGSize
    let scrollOffset: CGPoint
    let content: () -> AnyView

    final class Coordinator: NSObject {
        var hostView: NSHostingView<AnyView>?
        var lastAppliedOffset: CGPoint = CGPoint(x: -1, y: -1)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = true
        sv.autohidesScrollers = true
        sv.drawsBackground = false
        sv.borderType = .noBorder

        let host = NSHostingView(rootView: content())
        host.frame.size = contentSize
        sv.documentView = host
        context.coordinator.hostView = host
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        context.coordinator.hostView?.rootView = content()
        context.coordinator.hostView?.frame.size = contentSize

        // Only apply scroll offset when it has changed (e.g. on zoom), not on every state update.
        // This avoids fighting the user's manual scroll via trackpad/wheel.
        if scrollOffset != context.coordinator.lastAppliedOffset {
            context.coordinator.lastAppliedOffset = scrollOffset
            sv.contentView.scroll(to: scrollOffset)
            sv.reflectScrolledClipView(sv.contentView)
        }
    }
}
