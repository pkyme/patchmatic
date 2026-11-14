import SwiftUI

// Holds zoom/pan state in a reference type so the scroll-wheel event monitor can mutate it.
@Observable
final class ModuleCanvasViewState {
    var zoom: CGFloat = 1.0
    var panOffset: CGSize = .zero
    var panStart: CGSize = .zero
    var zoomAtGestureStart: CGFloat = 1.0
    var panOffsetAtZoomStart: CGSize = .zero
    var zoomCursorInView: CGPoint = .zero
    var magnifyGestureActive: Bool = false
    var viewportFrame: CGRect = .zero
    var scrollMonitor: Any?

    deinit {
        if let m = scrollMonitor { NSEvent.removeMonitor(m) }
    }
}

struct ModulePreviewCanvas: View {
    var definition: ModuleDefinition
    var selectedControlIDs: Set<UUID>
    var knobValues: [UUID: Double]
    var isPlacementMode: Bool = false
    var backgroundImage: CGImage? = nil
    var backgroundOpacity: Double = 1.0
    var showGrid: Bool = false
    var gridDivisions: Int = 8
    var showControls: Bool = true
    var detections: [Detection] = []
    var highlightedDetectionID: UUID? = nil

    // Callbacks
    var onTap: ((NormalizedPoint) -> Void)?
    var onBeginDragControl: (() -> Void)?
    var onEndDragControl: (() -> Void)?
    var onDragControl: ((UUID, NormalizedPoint) -> Void)?
    var onSelectControl: ((UUID, Bool) -> Void)?
    var onClearSelection: (() -> Void)?
    var onMarqueeSelect: ((Set<UUID>) -> Void)?
    var onDragSelectedControls: ((Double, Double) -> Void)?
    var onDetectionClick: ((NormalizedPoint) -> Void)?
    var onNudge: ((Double, Double) -> Void)?
    var onBeginResizeControl: ((UUID) -> Void)?
    var onResizeScreen: ((UUID, CGFloat, CGFloat, NormalizedPoint) -> Void)?
    var onResizeSlider: ((UUID, CGFloat, NormalizedPoint) -> Void)?
    var onEndResizeControl: ((UUID) -> Void)?
    var zoom: Binding<CGFloat> = .constant(1.0)
    var frameModuleTrigger: Binding<Bool> = .constant(false)
    // MARK: - Drag mode tracking

    enum DragMode {
        case none
        case singleDrag(controlID: UUID)
        case multiDrag
        case marquee
        case pan
        case resize(controlID: UUID)
    }

    @Environment(\.colorScheme) var colorScheme
    @State var cs = ModuleCanvasViewState()
    @FocusState var isFocused: Bool
    @State var dragMode: DragMode = .none
    @State var dragOffset: CGSize = .zero

    // Marquee state
    @State var marqueeStart: CGPoint?
    @State var marqueeEnd: CGPoint?

    // Multi-drag state
    @State var lastDragNormalized: NormalizedPoint?
    @State var selectedAtDragStart: Bool = false

    // Resize state
    @State var resizeDragStartSize: CGSize = .zero
    @State var resizeDragStartLength: CGFloat = 0
    @State var resizeDragStartNormalizedPosition: NormalizedPoint = NormalizedPoint(x: 0, y: 0)

    let minZoom = ModuleEditorViewModel.zoomRange.lowerBound
    let maxZoom = ModuleEditorViewModel.zoomRange.upperBound

    var body: some View {
        let panelWidth = EurorackConstants.width(forHP: definition.widthHP)
        let panelHeight = definition.panelHeight

        GeometryReader { geo in
                let totalScale = fitScale(viewSize: geo.size, panelWidth: panelWidth, panelHeight: panelHeight) * cs.zoom
                let scaledWidth = panelWidth * totalScale
                let scaledHeight = panelHeight * totalScale

                ZStack {
                    // Rendering layer
                    Canvas { context, size in
                        // Module panel (background image handled inside renderer for correct masking)
                        ModuleRenderer.draw(
                            in: context,
                            definition: definition,
                            size: size,
                            knobValues: knobValues,
                            backgroundImage: backgroundImage,
                            backgroundImageOpacity: backgroundOpacity,
                            showControls: showControls,
                            isDarkMode: colorScheme == .dark,
                            zoom: totalScale
                        )

                        // Grid
                        if showGrid && gridDivisions >= 2 {
                            let cellSize = min(panelWidth, panelHeight) / CGFloat(gridDivisions) * totalScale
                            var gridPath = Path()
                            var x = cellSize
                            while x < size.width {
                                gridPath.move(to: CGPoint(x: x, y: 0))
                                gridPath.addLine(to: CGPoint(x: x, y: size.height))
                                x += cellSize
                            }
                            var y = cellSize
                            while y < size.height {
                                gridPath.move(to: CGPoint(x: 0, y: y))
                                gridPath.addLine(to: CGPoint(x: size.width, y: y))
                                y += cellSize
                            }
                            context.stroke(gridPath, with: .color(.primary.opacity(0.15)), lineWidth: 0.5 * totalScale)
                        }

                        // Detection boxes
                        for detection in detections {
                            let rect = CGRect(
                                x: detection.boundingBox.origin.x * size.width,
                                y: detection.boundingBox.origin.y * size.height,
                                width: detection.boundingBox.width * size.width,
                                height: detection.boundingBox.height * size.height
                            )
                            let isHighlighted = detection.id == highlightedDetectionID
                            let color = detection.detectedClass.overlayColor

                            if isHighlighted {
                                context.fill(Path(rect), with: .color(color.opacity(0.25)))
                            }
                            context.stroke(Path(rect), with: .color(color), lineWidth: 1.5 * totalScale)

                            let confText = String(format: "%@ %.0f%%", detection.detectedClass.label, detection.confidence * 100)
                            let confLabel = Text(confText).font(.system(size: 5 * totalScale)).foregroundColor(color)
                            context.draw(confLabel, at: CGPoint(x: rect.midX, y: rect.minY - 4 * totalScale), anchor: .center)
                        }

                        // Selection highlights
                        guard showControls else { return }
                        for control in definition.controls where selectedControlIDs.contains(control.id) {
                            let highlightPath = control.highlightPath(in: size, zoom: totalScale, padding: 4 * totalScale)
                            context.fill(highlightPath, with: .color(Color.accentColor.opacity(0.2)))

                            // Resize fill indicator drawn before stroke so border sits on top
                            if control.kind == .screen || control.kind == .slider {
                                let hr = highlightPath.boundingRect
                                let baseCR: CGFloat = control.kind == .screen ? 3 : 4
                                let cr = min((baseCR + 4) * totalScale, hr.width / 2, hr.height / 2)
                                var fill = Path()

                                if control.kind == .screen {
                                    // Bottom-right corner segment: arc + diagonal chord
                                    fill.move(to: CGPoint(x: hr.maxX, y: hr.maxY - cr))
                                    fill.addArc(center: CGPoint(x: hr.maxX - cr, y: hr.maxY - cr),
                                                radius: cr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                                    fill.closeSubpath()
                                } else {
                                    // Partial cap using the actual highlight corner radius so the curve matches.
                                    // d = depth of the fill from the end edge; α/γ = partial arc sweep angle.
                                    let d = cr * 0.35
                                    let cosA = (cr - d) / cr
                                    let sinA = sqrt(max(0, 1 - cosA * cosA))
                                    let αRad = Double(acos(Double(cosA)))
                                    let γRad = Double(asin(Double(cosA)))  // complementary angle for vertical

                                    if control.orientation == .vertical {
                                        // Partial bottom cap: two arcs (radius cr) from chord at y = maxY-d to bottom edge
                                        let rightChordX = hr.maxX - cr + cr * sinA
                                        fill.move(to: CGPoint(x: rightChordX, y: hr.maxY - d))
                                        fill.addArc(center: CGPoint(x: hr.maxX - cr, y: hr.maxY - cr),
                                                    radius: cr, startAngle: .init(radians: γRad), endAngle: .degrees(90), clockwise: false)
                                        fill.addLine(to: CGPoint(x: hr.minX + cr, y: hr.maxY))
                                        fill.addArc(center: CGPoint(x: hr.minX + cr, y: hr.maxY - cr),
                                                    radius: cr, startAngle: .degrees(90), endAngle: .init(radians: .pi - γRad), clockwise: false)
                                        fill.closeSubpath()
                                    } else {
                                        // Partial right cap: two arcs (radius cr) from chord at x = maxX-d to right edge
                                        let topChordY = hr.minY + cr - cr * sinA
                                        fill.move(to: CGPoint(x: hr.maxX - d, y: topChordY))
                                        fill.addArc(center: CGPoint(x: hr.maxX - cr, y: hr.minY + cr),
                                                    radius: cr, startAngle: .init(radians: -αRad), endAngle: .degrees(0), clockwise: false)
                                        fill.addLine(to: CGPoint(x: hr.maxX, y: hr.maxY - cr))
                                        fill.addArc(center: CGPoint(x: hr.maxX - cr, y: hr.maxY - cr),
                                                    radius: cr, startAngle: .degrees(0), endAngle: .init(radians: αRad), clockwise: false)
                                        fill.closeSubpath()
                                    }
                                }
                                context.fill(fill, with: .color(.accentColor))
                            }

                            context.stroke(highlightPath, with: .color(Color.accentColor), lineWidth: 2 * totalScale)
                        }
                    }
                    .frame(width: scaledWidth, height: scaledHeight)
                    .position(
                        x: geo.size.width / 2 + cs.panOffset.width,
                        y: geo.size.height / 2 + cs.panOffset.height
                    )
                    .allowsHitTesting(false)

                    // Marquee overlay
                    if let start = marqueeStart, let end = marqueeEnd {
                        let rect = CGRect(
                            x: min(start.x, end.x),
                            y: min(start.y, end.y),
                            width: abs(end.x - start.x),
                            height: abs(end.y - start.y)
                        )
                        Rectangle()
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }

                    // Interaction layer
                    Color.clear
                        .contentShape(Rectangle())
                        .focusable()
                        .focused($isFocused)
                        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
                            guard onNudge != nil else { return .ignored }
                            let large = press.modifiers.contains(.shift)
                            let step = large ? 5.0 : 0.5
                            let dx: Double
                            let dy: Double
                            switch press.key {
                            case .leftArrow:  dx = -step / Double(panelWidth);  dy = 0
                            case .rightArrow: dx =  step / Double(panelWidth);  dy = 0
                            case .upArrow:    dx = 0; dy = -step / Double(panelHeight)
                            case .downArrow:  dx = 0; dy =  step / Double(panelHeight)
                            default: return .ignored
                            }
                            onNudge?(dx, dy)
                            return .handled
                        }
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .modifiers(.option)
                                .onChanged { value in
                                    if case .pan = dragMode {
                                    } else {
                                        dragMode = .pan
                                        cs.panStart = cs.panOffset
                                    }
                                    cs.panOffset = CGSize(
                                        width: cs.panStart.width + value.translation.width,
                                        height: cs.panStart.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    cs.panStart = cs.panOffset
                                    dragMode = .none
                                }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDragChanged(value, viewSize: geo.size, panelWidth: panelWidth, panelHeight: panelHeight)
                                }
                                .onEnded { value in
                                    handleDragEnded(value, viewSize: geo.size, panelWidth: panelWidth, panelHeight: panelHeight)
                                }
                        )
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    if !cs.magnifyGestureActive {
                                        cs.magnifyGestureActive = true
                                        cs.panOffsetAtZoomStart = cs.panOffset
                                        cs.zoomCursorInView = cursorInView()
                                    }
                                    let newZoom = min(maxZoom, max(minZoom, cs.zoomAtGestureStart * value.magnification))
                                    applyZoomTowardCursor(newZoom: newZoom,
                                                          cursor: cs.zoomCursorInView,
                                                          panOffsetAtStart: cs.panOffsetAtZoomStart,
                                                          zoomAtStart: cs.zoomAtGestureStart)
                                }
                                .onEnded { value in
                                    cs.magnifyGestureActive = false
                                    cs.zoomAtGestureStart = cs.zoom
                                }
                        )
                }
                .clipped()
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { cs.viewportFrame = proxy.frame(in: .global) }
                            .onChange(of: proxy.size) { _, _ in cs.viewportFrame = proxy.frame(in: .global) }
                    }
                }
                .onChange(of: cs.zoom) { _, newVal in
                    if zoom.wrappedValue != newVal { zoom.wrappedValue = newVal }
                }
                .onChange(of: zoom.wrappedValue) { _, newVal in
                    if cs.zoom != newVal { cs.zoom = newVal; cs.zoomAtGestureStart = newVal }
                }
                .onChange(of: frameModuleTrigger.wrappedValue) { _, _ in
                    guard frameModuleTrigger.wrappedValue else { return }
                    cs.zoom = 1.0
                    cs.zoomAtGestureStart = 1.0
                    cs.panOffset = .zero
                    cs.panStart = .zero
                    zoom.wrappedValue = 1.0
                    frameModuleTrigger.wrappedValue = false
                }
                .onAppear {
                    cs.zoom = zoom.wrappedValue
                    cs.zoomAtGestureStart = cs.zoom
                    guard cs.scrollMonitor == nil else { return }
                    cs.scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                        guard let contentView = event.window?.contentView else { return event }
                        let mouse = event.locationInWindow
                        let flipped = CGPoint(x: mouse.x, y: contentView.bounds.height - mouse.y)
                        guard cs.viewportFrame.contains(flipped) else { return event }
                        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
                        guard abs(delta) > 0.001 else { return event }
                        let factor = 1.0 + delta * 0.015
                        let newZoom = min(maxZoom, max(minZoom, cs.zoom * factor))
                        let cursor = CGPoint(x: flipped.x - cs.viewportFrame.minX,
                                            y: flipped.y - cs.viewportFrame.minY)
                        applyZoomTowardCursor(newZoom: newZoom,
                                              cursor: cursor,
                                              panOffsetAtStart: cs.panOffset,
                                              zoomAtStart: cs.zoom)
                        cs.zoomAtGestureStart = cs.zoom
                        return event
                    }
                }
                .onDisappear {
                    if let m = cs.scrollMonitor { NSEvent.removeMonitor(m); cs.scrollMonitor = nil }
                }
        }
    }
}
