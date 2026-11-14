import SwiftUI

extension ModulePreviewCanvas {
    // MARK: - Control drag

    /// Selects, moves, resizes or marquee-selects controls depending on where the drag began.
    func handleDragChanged(_ value: DragGesture.Value, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) {
        isFocused = true

        if case .none = dragMode {
            // Resize handle takes priority over normal control hit-testing
            var resizeHitID: UUID? = nil
            for control in definition.controls where selectedControlIDs.contains(control.id) {
                guard control.kind == .screen || control.kind == .slider else { continue }
                if isOnResizeHandle(at: value.startLocation, control: control, viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight) {
                    resizeHitID = control.id
                    break
                }
            }
            if let hitID = resizeHitID,
               let c = definition.controls.first(where: { $0.id == hitID }) {
                resizeDragStartSize = CGSize(width: CGFloat(c.screenWidth), height: CGFloat(c.screenHeight))
                resizeDragStartLength = CGFloat(c.sliderTrackLength)
                resizeDragStartNormalizedPosition = c.position
                dragMode = .resize(controlID: hitID)
                onBeginResizeControl?(hitID)
            }

            let hitID = resizeHitID == nil ? hitTestForDrag(
                at: value.startLocation,
                viewSize: viewSize,
                panelWidth: panelWidth,
                panelHeight: panelHeight
            ) : nil

            let isShiftAtStart = NSEvent.modifierFlags.contains(.shift)

            if resizeHitID != nil {
                // Resize mode already set above; skip control drag logic
            } else if let hitID, selectedControlIDs.contains(hitID) {
                // Already selected — drag all selected items
                selectedAtDragStart = true
                dragMode = .multiDrag
                onBeginDragControl?()
                lastDragNormalized = viewPointToNormalized(
                    value.startLocation, viewSize: viewSize,
                    panelWidth: panelWidth, panelHeight: panelHeight
                )
            } else if let hitID {
                if isShiftAtStart {
                    // Shift on unselected — add to selection, drag all
                    selectedAtDragStart = false
                    onSelectControl?(hitID, true)
                    dragMode = .multiDrag
                    onBeginDragControl?()
                    lastDragNormalized = viewPointToNormalized(
                        value.startLocation, viewSize: viewSize,
                        panelWidth: panelWidth, panelHeight: panelHeight
                    )
                } else {
                    // No shift on unselected — select just this, drag it alone
                    onSelectControl?(hitID, false)
                    dragMode = .singleDrag(controlID: hitID)
                    onBeginDragControl?()
                    if let control = definition.controls.first(where: { $0.id == hitID }) {
                        let (scale, offsetX, offsetY) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
                        let center = control.position.toPoint(in: CGSize(width: panelWidth, height: panelHeight))
                        let screenCenter = CGPoint(x: center.x * scale + offsetX, y: center.y * scale + offsetY)
                        dragOffset = CGSize(
                            width: screenCenter.x - value.startLocation.x,
                            height: screenCenter.y - value.startLocation.y
                        )
                    }
                }
            } else if !isPlacementMode {
                let dx = value.location.x - value.startLocation.x
                let dy = value.location.y - value.startLocation.y
                if dx * dx + dy * dy >= 16 {
                    if isShiftAtStart {
                        dragMode = .marquee
                        marqueeStart = value.startLocation
                        marqueeEnd = value.location
                    } else {
                        dragMode = .pan
                        cs.panStart = cs.panOffset
                    }
                }
            }
        }

        switch dragMode {
        case .multiDrag:
            let currentNorm = viewPointToNormalized(
                value.location, viewSize: viewSize,
                panelWidth: panelWidth, panelHeight: panelHeight
            )
            if let last = lastDragNormalized {
                let dx = currentNorm.x - last.x
                let dy = currentNorm.y - last.y
                onDragSelectedControls?(dx, dy)
            }
            lastDragNormalized = currentNorm

        case .singleDrag(let controlID):
            let adjustedLocation = CGPoint(
                x: value.location.x + dragOffset.width,
                y: value.location.y + dragOffset.height
            )
            let normalized = viewPointToNormalized(
                adjustedLocation, viewSize: viewSize,
                panelWidth: panelWidth, panelHeight: panelHeight
            )
            onDragControl?(controlID, normalized)

        case .marquee:
            marqueeEnd = value.location

        case .pan:
            cs.panOffset = CGSize(
                width: cs.panStart.width + value.translation.width,
                height: cs.panStart.height + value.translation.height
            )

        case .resize(let controlID):
            guard let control = definition.controls.first(where: { $0.id == controlID }) else { break }
            let (scale, _, _) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
            let dx = value.translation.width / scale
            let dy = value.translation.height / scale
            let startCX = resizeDragStartNormalizedPosition.x * Double(panelWidth)
            let startCY = resizeDragStartNormalizedPosition.y * Double(panelHeight)
            if control.kind == .screen {
                let newWidth = max(5, resizeDragStartSize.width + dx)
                let newHeight = max(5, resizeDragStartSize.height + dy)
                // Fixed corner is top-left; new center moves with bottom-right
                let topLeftX = startCX - Double(resizeDragStartSize.width) / 2
                let topLeftY = startCY - Double(resizeDragStartSize.height) / 2
                let newCenter = NormalizedPoint(
                    x: (topLeftX + Double(newWidth) / 2) / Double(panelWidth),
                    y: (topLeftY + Double(newHeight) / 2) / Double(panelHeight)
                )
                onResizeScreen?(controlID, newWidth, newHeight, newCenter)
            } else if control.kind == .slider {
                if control.orientation == .vertical {
                    let newLength = max(10, resizeDragStartLength + dy)
                    let topY = startCY - Double(resizeDragStartLength) / 2
                    let newCenter = NormalizedPoint(
                        x: resizeDragStartNormalizedPosition.x,
                        y: (topY + Double(newLength) / 2) / Double(panelHeight)
                    )
                    onResizeSlider?(controlID, newLength, newCenter)
                } else {
                    let newLength = max(10, resizeDragStartLength + dx)
                    let leftX = startCX - Double(resizeDragStartLength) / 2
                    let newCenter = NormalizedPoint(
                        x: (leftX + Double(newLength) / 2) / Double(panelWidth),
                        y: resizeDragStartNormalizedPosition.y
                    )
                    onResizeSlider?(controlID, newLength, newCenter)
                }
            }

        case .none:
            break
        }
    
    }

    func handleDragEnded(_ value: DragGesture.Value, viewSize: CGSize, panelWidth: CGFloat, panelHeight: CGFloat) {
        let viewSize = viewSize
        let isShift = NSEvent.modifierFlags.contains(.shift)
        let distance = GeometryHelpers.distance(from: value.startLocation, to: value.location)

        switch dragMode {
        case .multiDrag:
            onEndDragControl?()
            // Click (no drag) on item that was already selected before drag start:
            // narrow, toggle, or cycle through overlapping controls
            if distance < 3, selectedAtDragStart {
                if isShift {
                    if let hitID = hitTestControl(
                        at: value.startLocation, viewSize: viewSize,
                        panelWidth: panelWidth, panelHeight: panelHeight
                    ) {
                        onSelectControl?(hitID, true)
                    }
                } else {
                    if let hitID = hitTestCycling(
                        at: value.startLocation, viewSize: viewSize,
                        panelWidth: panelWidth, panelHeight: panelHeight
                    ) {
                        onSelectControl?(hitID, false)
                    }
                }
            }

        case .singleDrag:
            onEndDragControl?()
            // Click (no drag): cycle through overlapping controls
            if distance < 3, !isShift {
                if let cycled = hitTestCycling(
                    at: value.startLocation, viewSize: viewSize,
                    panelWidth: panelWidth, panelHeight: panelHeight
                ) {
                    onSelectControl?(cycled, false)
                }
            }

        case .marquee:
            if let start = marqueeStart, let end = marqueeEnd {
                let ids = controlsInMarquee(
                    start: start, end: end,
                    viewSize: viewSize,
                    panelWidth: panelWidth, panelHeight: panelHeight
                )
                if isShift {
                    onMarqueeSelect?(selectedControlIDs.union(ids))
                } else {
                    onMarqueeSelect?(ids)
                }
            }

        case .pan:
            cs.panStart = cs.panOffset

        case .resize(let controlID):
            onEndResizeControl?(controlID)

        case .none:
            let hitID = hitTestControl(
                at: value.startLocation, viewSize: viewSize,
                panelWidth: panelWidth, panelHeight: panelHeight
            )
            if hitID == nil {
                if isPlacementMode {
                    let (scale, oX, oY) = zoomedTransform(viewSize: viewSize, panelWidth: panelWidth, panelHeight: panelHeight)
                    let rawX = (value.location.x - oX) / scale / panelWidth
                    let rawY = (value.location.y - oY) / scale / panelHeight
                    guard (0...1).contains(rawX) && (0...1).contains(rawY) else { break }
                    let normalized = NormalizedPoint(x: rawX, y: rawY)
                    onTap?(normalized)
                } else if !detections.isEmpty {
                    let normalized = viewPointToNormalized(
                        value.location, viewSize: viewSize,
                        panelWidth: panelWidth, panelHeight: panelHeight
                    )
                    onDetectionClick?(normalized)
                } else {
                    onClearSelection?()
                }
            }
        }

        dragMode = .none
        dragOffset = .zero
        marqueeStart = nil
        marqueeEnd = nil
        lastDragNormalized = nil
        selectedAtDragStart = false
    
    }
}
