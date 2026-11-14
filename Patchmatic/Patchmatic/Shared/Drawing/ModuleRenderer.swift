import SwiftUI

// MARK: - Control shape helpers

extension Control {
    /// Padding in points added around a control's body when hit testing clicks and hovers.
    static let hitPadding: CGFloat = 4

    /// The outline of a control's body as drawn by its renderer.
    enum BodyShape {
        case circle(center: CGPoint, radius: CGFloat)
        case roundedRect(CGRect, cornerRadius: CGFloat)

        /// Smallest rectangle containing the shape
        var bounds: CGRect {
            switch self {
            case .circle(let c, let r): CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            case .roundedRect(let rect, _): rect
            }
        }
    }

    /// The body shape of this control in panel coordinates. This is the single source
    /// of control geometry for highlighting, hit testing and label placement.
    func bodyShape(in panelSize: CGSize, zoom: CGFloat = 1.0) -> BodyShape {
        let center = position.toPoint(in: panelSize)
        let r = effectiveRadius * zoom

        func centered(_ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        }

        switch kind {
        case .knob, .patchPoint:
            return .circle(center: center, radius: r)
        case .button:
            let side = ButtonRenderer.side(radius: r)
            return .roundedRect(centered(side, side), cornerRadius: ButtonRenderer.cornerRadius(zoom: zoom))
        case .toggleSwitch:
            let short = ToggleSwitchRenderer.shortAxis(radius: r)
            let long = ToggleSwitchRenderer.longAxis(radius: r, stateCount: stateCount, zoom: zoom)
            let isHorizontal = orientation == .horizontal
            return .roundedRect(centered(isHorizontal ? long : short, isHorizontal ? short : long),
                                cornerRadius: ToggleSwitchRenderer.cornerRadius(zoom: zoom))
        case .slider:
            let track = CGFloat(sliderTrackLength) * zoom
            let knob = SliderRenderer.knobSide(radius: r)
            let isVertical = orientation == .vertical
            return .roundedRect(centered(isVertical ? knob : track, isVertical ? track : knob),
                                cornerRadius: SliderRenderer.trackCornerRadius(zoom: zoom))
        case .screen:
            return .roundedRect(screenRect(in: panelSize, zoom: zoom), cornerRadius: ScreenRenderer.cornerRadius(zoom: zoom))
        }
    }

    /// Width and height of the body, which don't depend on its position on the panel.
    func bodySize(zoom: CGFloat = 1.0) -> CGSize {
        bodyShape(in: .zero, zoom: zoom).bounds.size
    }

    /// The body outline grown by `padding`, used for selection highlighting and background clipping.
    func highlightPath(in panelSize: CGSize, zoom: CGFloat = 1.0, padding: CGFloat = 0) -> Path {
        switch bodyShape(in: panelSize, zoom: zoom) {
        case .circle(let center, let radius):
            return Path(circleAt: center, radius: radius + padding)
        case .roundedRect(let rect, let cornerRadius):
            return Path(roundedRect: rect.insetBy(dx: -padding, dy: -padding), cornerRadius: cornerRadius + padding)
        }
    }

    /// Whether `point` (in panel coordinates) lies within the body grown by `padding`.
    func hitTest(point: CGPoint, in panelSize: CGSize, zoom: CGFloat = 1.0, padding: CGFloat = 0) -> Bool {
        switch bodyShape(in: panelSize, zoom: zoom) {
        case .circle(let center, let radius):
            let dx = point.x - center.x, dy = point.y - center.y
            let r = radius + padding
            return dx * dx + dy * dy <= r * r
        case .roundedRect(let rect, _):
            return rect.insetBy(dx: -padding, dy: -padding).contains(point)
        }
    }
}

// MARK: - Shared label helper

enum LabelDrawing {
    /// Draws `text` centered at `point` with a semi-transparent capsule background for readability.
    /// Capsule padding around the text, in points at 1x zoom
    static let horizontalPadding: CGFloat = 3
    static let verticalPadding: CGFloat = 1.5

    static func draw(_ text: Text, at point: CGPoint, in context: GraphicsContext, zoom: CGFloat, capsuleOpacity: Double, isDarkMode: Bool = true) {
        let resolved = context.resolve(text)
        draw(resolved, size: measure(resolved), at: point, in: context, zoom: zoom, capsuleOpacity: capsuleOpacity, isDarkMode: isDarkMode)
    }

    static func measure(_ resolved: GraphicsContext.ResolvedText) -> CGSize {
        resolved.measure(in: CGSize(width: 400, height: 100))
    }

    /// Size of the capsule drawn behind text of `textSize`
    static func capsuleSize(textSize: CGSize, zoom: CGFloat) -> CGSize {
        CGSize(width: textSize.width + horizontalPadding * zoom * 2,
               height: textSize.height + verticalPadding * zoom * 2)
    }

    /// Draws already resolved and measured text, so callers that measured it for
    /// layout don't measure it again.
    static func draw(_ resolved: GraphicsContext.ResolvedText, size textSize: CGSize, at point: CGPoint, in context: GraphicsContext, zoom: CGFloat, capsuleOpacity: Double, isDarkMode: Bool = true) {
        guard textSize.width > 0 else { return }
        let hPad = horizontalPadding * zoom
        let vPad = verticalPadding * zoom
        let bgRect = CGRect(
            x: point.x - textSize.width / 2 - hPad,
            y: point.y - textSize.height / 2 - vPad,
            width: textSize.width + hPad * 2,
            height: textSize.height + vPad * 2
        )
        if capsuleOpacity > 0 {
            let capsuleWhite: Double = isDarkMode ? 0.1 : 0.9
            context.fill(
                Path(roundedRect: bgRect, cornerRadius: bgRect.height / 2),
                with: .color(Color(white: capsuleWhite, opacity: capsuleOpacity))
            )
        }
        context.draw(resolved, at: point, anchor: .center)
    }
}

enum ModuleRenderer {
    /// Draws a complete module panel: outline, name, and all controls
    static func draw(
        in context: GraphicsContext,
        definition: ModuleDefinition,
        size: CGSize,
        knobValues: [UUID: Double] = [:],
        patchPointColors: [UUID: Color] = [:],
        activatedControlIDs: Set<UUID>? = nil,
        backgroundImage: CGImage? = nil,
        backgroundImageOpacity: Double = 0.5,
        showLabels: Bool = true,
        labelsIgnoreActivation: Bool = false,
        showControls: Bool = true,
        isDarkMode: Bool = true,
        zoom: CGFloat = 1.0,
        screenImages: [UUID: Image] = [:],
        pressedControlID: UUID? = nil,
        hoveredControlID: UUID? = nil,
        hoveredControlBrightness: Double = 0.0,
        drawsShadows: Bool = true
    ) {
        let rect = CGRect(origin: .zero, size: size)
        let strokeWidth = 2 * zoom
        let insetRect = rect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)

        // Background image
        if let backgroundImage {
            var imgContext = context
            imgContext.opacity = backgroundImageOpacity

            // Clip to the inner edge of the outline stroke so the image edge is fully
            // covered by the stroke and any visible panel border in the photo is hidden.
            let imageClipRect = insetRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
            let imageClipRadius = max(0, 6 * zoom - strokeWidth / 2)
            var clipPath = Path(roundedRect: imageClipRect, cornerRadius: imageClipRadius)
            if showControls {
                let padding: CGFloat = 2 * zoom
                for control in definition.controls {
                    let shape = control.highlightPath(in: size, zoom: zoom, padding: padding)
                    clipPath.addPath(shape)
                }
            }
            imgContext.clip(to: clipPath, style: FillStyle(eoFill: true))
            imgContext.withCGContext { cgCtx in
                cgCtx.interpolationQuality = .high
                cgCtx.translateBy(x: 0, y: insetRect.minY + insetRect.maxY)
                cgCtx.scaleBy(x: 1, y: -1)
                cgCtx.draw(backgroundImage, in: insetRect)
            }
        }

        // Module outline
        let roundedRect = Path(roundedRect: insetRect, cornerRadius: 6 * zoom)
        let graphicsOpacity = 0.5 + backgroundImageOpacity * 0.5
        let capsuleOpacity = 0.72 * sqrt(backgroundImageOpacity)
        var outlineContext = context
        outlineContext.opacity = activatedControlIDs != nil ? 0.2 : graphicsOpacity
        outlineContext.stroke(roundedRect, with: .foreground, lineWidth: strokeWidth)

        // Module name at top — drawn on the base context so it is always at full brightness,
        // unaffected by the patch-mode opacity dimming applied to outlineContext.
        if showControls && showLabels {
            let title = Text(definition.name)
                .font(.system(size: 8 * zoom, weight: .semibold))
            LabelDrawing.draw(title, at: CGPoint(x: size.width / 2, y: 8 * zoom), in: context, zoom: zoom, capsuleOpacity: capsuleOpacity, isDarkMode: isDarkMode)
        }

        guard showControls else { return }

        // Draw controls
        for control in definition.controls {
            let center = control.position.toPoint(in: size)
            let radius = control.effectiveRadius * zoom
            let value = knobValues[control.id] ?? 0

            let isActivated = activatedControlIDs?.contains(control.id) ?? true
            let dimmed = activatedControlIDs != nil && !isActivated

            var controlContext = context
            let isHovered = hoveredControlID == control.id
            if activatedControlIDs != nil {
                if dimmed {
                    let hoverBoost = isHovered ? hoveredControlBrightness * 0.4 : 0.0
                    controlContext.opacity = 0.2 + hoverBoost
                } else {
                    controlContext.opacity = 1.0
                    if isHovered {
                        controlContext.addFilter(.brightness(hoveredControlBrightness * 0.15))
                    }
                }
            } else {
                controlContext.opacity = graphicsOpacity
            }

            let showState = !dimmed
            switch control.kind {
            case .knob:
                KnobRenderer.draw(
                    in: controlContext,
                    center: center,
                    radius: radius,
                    value: knobValues[control.id] ?? 0.5,
                    zoom: zoom,
                    showState: showState
                )
            case .patchPoint:
                PatchPointRenderer.draw(
                    in: controlContext,
                    center: center,
                    radius: radius,
                    color: patchPointColors[control.id],
                    zoom: zoom,
                    showState: showState,
                    drawsShadow: drawsShadows
                )
            case .toggleSwitch:
                ToggleSwitchRenderer.draw(
                    in: controlContext,
                    center: center,
                    radius: radius,
                    value: value,
                    orientation: control.orientation,
                    zoom: zoom,
                    stateCount: control.stateCount,
                    showState: showState
                )
            case .button:
                ButtonRenderer.draw(
                    in: controlContext,
                    center: center,
                    radius: radius,
                    value: value,
                    zoom: zoom,
                    stateCount: control.stateCount,
                    isPressed: pressedControlID == control.id,
                    showState: showState
                )
            case .slider:
                SliderRenderer.draw(
                    in: controlContext,
                    center: center,
                    radius: radius,
                    trackLength: CGFloat(control.sliderTrackLength) * zoom,
                    isVertical: control.orientation == .vertical,
                    zoom: zoom,
                    value: knobValues[control.id] ?? 0.5,
                    showState: showState
                )
            case .screen:
                let screenRect = control.screenRect(in: size, zoom: zoom)
                ScreenRenderer.draw(
                    in: controlContext,
                    center: center,
                    width: screenRect.width,
                    height: screenRect.height,
                    image: screenImages[control.id],
                    zoom: zoom,
                    showState: showState
                )
            }

            drawLabels(
                for: control,
                center: center,
                radius: radius,
                zoom: zoom,
                value: value,
                context: controlContext,
                capsuleOpacity: capsuleOpacity,
                showGlobalLabels: showLabels,
                isActivated: isActivated,
                labelsIgnoreActivation: labelsIgnoreActivation,
                isDarkMode: isDarkMode
            )
        }
    }

    private static func drawLabels(
        for control: Control,
        center: CGPoint,
        radius: CGFloat,
        zoom: CGFloat,
        value: Double,
        context: GraphicsContext,
        capsuleOpacity: Double,
        showGlobalLabels: Bool,
        isActivated: Bool,
        labelsIgnoreActivation: Bool,
        isDarkMode: Bool
    ) {
        let controlEnabled = showGlobalLabels && (isActivated || labelsIgnoreActivation)
            && control.controlLabel.position != .disabled
            && !control.label.isEmpty

        let hasStates = control.kind == .button || control.kind == .toggleSwitch
        let stateName: String
        if hasStates {
            let n = control.stateCount
            let idx = min(Int((value * Double(n - 1)).rounded()), n - 1)
            stateName = idx >= 0 && idx < control.controlStates.count ? control.controlStates[idx] : ""
        } else {
            stateName = ""
        }
        let stateEnabled = isActivated
            && hasStates
            && control.stateLabel.position != .disabled
            && !stateName.isEmpty

        guard controlEnabled || stateEnabled else { return }

        struct LabelItem {
            let text: Text
            let config: Control.LabelConfig
            let isControlLabel: Bool
        }

        var items: [LabelItem] = []
        if controlEnabled {
            let t = Text(control.label.uppercased())
                .font(.system(size: control.controlLabel.fontSize * zoom, weight: .medium, design: .default).width(.condensed))
            items.append(LabelItem(text: t, config: control.controlLabel, isControlLabel: true))
        }
        if stateEnabled {
            let t = Text(stateName)
                .font(.system(size: control.stateLabel.fontSize * zoom, weight: .regular, design: .default).width(.condensed))
            items.append(LabelItem(text: t, config: control.stateLabel, isControlLabel: false))
        }

        // Group by position; control label always first (closer to body) within each group
        var grouped: [Control.LabelPosition: [LabelItem]] = [:]
        for item in items {
            grouped[item.config.position, default: []].append(item)
        }

        let body = control.bodySize(zoom: zoom)
        let halfW = body.width / 2, halfH = body.height / 2
        let bodyGap: CGFloat = 3.0 * zoom
        let labelGap: CGFloat = 2.0 * zoom

        for (position, group) in grouped {
            // Unit vector pointing away from the body towards the labels
            let direction: CGVector
            switch position {
            case .disabled: continue
            case .below: direction = CGVector(dx: 0, dy: 1)
            case .above: direction = CGVector(dx: 0, dy: -1)
            case .left: direction = CGVector(dx: -1, dy: 0)
            case .right: direction = CGVector(dx: 1, dy: 0)
            }
            let isVertical = direction.dx == 0
            // Distance from the control centre along `direction`, advanced past each label
            var distance = (isVertical ? halfH : halfW) + bodyGap
            for item in group.sorted(by: { a, b in a.isControlLabel && !b.isControlLabel }) {
                let resolved = context.resolve(item.text)
                let textSize = LabelDrawing.measure(resolved)
                guard textSize.width > 0 else { continue }
                let capsule = LabelDrawing.capsuleSize(textSize: textSize, zoom: zoom)
                let capsuleHalf = (isVertical ? capsule.height : capsule.width) / 2
                let labelDistance = distance + item.config.offset * zoom + capsuleHalf
                let point = CGPoint(x: center.x + direction.dx * labelDistance,
                                    y: center.y + direction.dy * labelDistance)
                LabelDrawing.draw(resolved, size: textSize, at: point, in: context, zoom: zoom,
                                  capsuleOpacity: capsuleOpacity, isDarkMode: isDarkMode)
                distance = labelDistance + capsuleHalf + labelGap
            }
        }
    }
}
