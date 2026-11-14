import SwiftUI
import UniformTypeIdentifiers

// Canvas drag handling in Patches mode
extension RackView {
    func isDoubleClickStart(at location: CGPoint) -> Bool {
        let now = Date()
        defer {
            gesture.lastDragStartTime = now
            gesture.lastDragStartLocation = location
        }
        guard let lastTime = gesture.lastDragStartTime,
              let lastLocation = gesture.lastDragStartLocation else { return false }

        let interval: TimeInterval
        #if canImport(AppKit)
        interval = min(NSEvent.doubleClickInterval, 0.3)
        #else
        interval = 0.3
        #endif

        let elapsed = now.timeIntervalSince(lastTime)
        let distance = hypot(location.x - lastLocation.x, location.y - lastLocation.y)
        return elapsed <= interval && distance < 20
    }

    func handleCableDragChanged(_ value: DragGesture.Value) {
        // A shift-click turns into a marquee once dragged far enough
        if gesture.cableDrag == .shiftClick, !readOnly,
           hypot(value.translation.width, value.translation.height) > 4 {
            let startPoint = scaledPoint(value.startLocation)
            if patchVM.showGroups {
                // In group mode only a drag from empty space selects modules
                if rackVM.placedModule(at: startPoint) == nil {
                    gesture.cableDrag = .groupMarquee(start: startPoint)
                }
            } else {
                gesture.cableDrag = .cableMarquee(start: startPoint, baseSelection: patchVM.selectedCableIDs)
            }
        }

        switch gesture.cableDrag {
        case .pin(let cableID, let pinID):
            let point = scaledPoint(value.location)
            patchVM.moveCablePin(cableID: cableID, pinID: pinID, to: point, caseID: nil)
            cableGeometry?.syncSegmentRopes(for: cableID)
            return
        case .pan:
            panOffset = CGSize(
                width: lastPanOffset.width + value.translation.width,
                height: lastPanOffset.height + value.translation.height
            )
            return
        case .cableMarquee(let start, let baseSelection):
            let rect = Self.rect(from: start, to: scaledPoint(value.location))
            rackVM.marqueeRect = rect
            let selection = baseSelection.union(cableGeometry?.cables(intersecting: rect) ?? [])
            if selection != patchVM.selectedCableIDs {
                patchVM.selectedCableIDs = selection
            }
            return
        case .groupMarquee(let start):
            let rect = Self.rect(from: start, to: scaledPoint(value.location))
            rackVM.marqueeRect = rect
            rackVM.selectItemsInRect(rect)
            return
        case .groupSelecting:
            // Dragging a module body pans instead of selecting
            if hypot(value.translation.width, value.translation.height) > 4 {
                gesture.cableDrag = .pan
                lastPanOffset = panOffset
            }
            return
        case .shiftClick, .doubleClick, .control:
            return
        case .idle:
            break
        }

        let point = scaledPoint(value.location)

        if patchVM.dragFrom == nil && patchVM.knobDragInfo == nil && patchVM.sliderDragInfo == nil {
            if isDoubleClickStart(at: value.startLocation) {
                gesture.cableDrag = .doubleClick
                // Dismiss magnifier on double-click
                magnifiedScreen = nil
                magnifierInfo = nil
                return
            }

            let startPoint = scaledPoint(value.startLocation)

            // Check for shift key — cable selection mode
            #if canImport(AppKit)
            let isShiftClick = NSEvent.modifierFlags.contains(.shift)
            #else
            let isShiftClick = false
            #endif

            if isShiftClick {
                if patchVM.showGroups && !readOnly {
                    let shiftStart = scaledPoint(value.startLocation)
                    // Check for cable first — cables render on top of modules
                    if cableGeometry?.cable(at: shiftStart) == nil {
                        if let placed = rackVM.placedModule(at: shiftStart),
                           rackVM.controlAtPoint(shiftStart, in: placed) == nil {
                            // Shift+click on module body (no cable on top) — extend selection
                            gesture.cableDrag = .groupSelecting
                            return
                        }
                    }
                    // On a cable, control, or empty space — cable selection
                    // (if empty space drag detected later, converts to marquee)
                }
                gesture.cableDrag = .shiftClick
                return
            }

            // Command-click on cable — insert pin
            #if canImport(AppKit)
            let isCommandClick = NSEvent.modifierFlags.contains(.command)
            #else
            let isCommandClick = false
            #endif
            if isCommandClick, !readOnly,
               let cableID = cableGeometry?.cable(at: startPoint),
               let cable = patchVM.activePatch?.cables.first(where: { $0.id == cableID }) {
                patchVM.selectedCableIDs = [cableID]
                let simulator = patchVM.cableSimulator
                let orderedPins = cable.orderedPins
                var bestSeg = orderedPins.count
                var bestDist = CGFloat.greatestFiniteMagnitude
                for seg in 0..<cable.segmentCount {
                    let ropeID = cable.segmentRopeID(seg)
                    guard let points = simulator.pointsForRope(id: ropeID) else { continue }
                    let dist = GeometryHelpers.distanceToPolyline(point: startPoint, polyline: points)
                    if dist < bestDist {
                        bestDist = dist
                        bestSeg = seg
                    }
                }
                let pin = CablePin(x: startPoint.x, y: startPoint.y, caseID: nil, sortIndex: bestSeg)
                patchVM.addCablePin(cableID: cableID, pin: pin)
                return
            }

            // Non-shift interaction clears cable selection
            if !patchVM.selectedCableIDs.isEmpty {
                patchVM.clearCableSelection()
            }

            // Pin drag detection — check before controls
            if !readOnly {
                if let pinHit = cableGeometry?.pin(at: startPoint) {
                    gesture.cableDrag = .pin(cableID: pinHit.cableID, pinID: pinHit.pinID)
                    patchVM.selectedPinID = pinHit
                    patchVM.beginPinDrag(cableID: pinHit.cableID, pinID: pinHit.pinID)
                    return
                }
            }
            patchVM.selectedPinID = nil

            // If not on a control, pan the canvas (or select module in group mode)
            guard let placed = rackVM.placedModule(at: startPoint),
                  let control = rackVM.controlAtPoint(startPoint, in: placed) else {
                if rackVM.placedModule(at: startPoint) != nil {
                    if patchVM.showGroups && !readOnly && cableGeometry?.cable(at: startPoint) == nil {
                        gesture.cableDrag = .groupSelecting
                        return
                    }
                } else {
                    if patchVM.showGroups && !readOnly {
                        rackVM.selectedPlacedModuleIDs.removeAll()
                    }
                }
                gesture.cableDrag = .pan
                lastPanOffset = panOffset
                magnifiedScreen = nil
                magnifierInfo = nil
                return
            }

            switch control.kind {
            case .patchPoint:
                // Dismiss magnifier when starting cable drag
                magnifiedScreen = nil
                magnifierInfo = nil
                patchVM.beginDrag(moduleID: placed.id, controlID: control.id, point: point)
            case .knob:
                // Dismiss magnifier when starting knob drag
                magnifiedScreen = nil
                magnifierInfo = nil
                patchVM.beginKnobDrag(moduleID: placed.id, controlID: control.id, startY: value.startLocation.y / currentZoom)
            case .slider:
                magnifiedScreen = nil
                magnifierInfo = nil
                let origin = rackVM.moduleOrigin(for: placed)
                if let size = rackVM.moduleSize(for: placed) {
                    let ctrlCenter = GeometryHelpers.controlScreenPosition(control: control, moduleOrigin: origin, moduleSize: size)
                    let travelHalf = SliderRenderer.travelHalf(
                        radius: control.effectiveRadius, trackLength: CGFloat(control.sliderTrackLength),
                        isVertical: control.orientation == .vertical, zoom: 1)
                    patchVM.beginSliderDrag(moduleID: placed.id, controlID: control.id, center: ctrlCenter, trackHalf: travelHalf, isVertical: control.orientation == .vertical)
                    patchVM.updateSliderDrag(point: scaledPoint(value.startLocation))
                }
            case .toggleSwitch, .button:
                // Dismiss magnifier when interacting with toggle/button
                magnifiedScreen = nil
                magnifierInfo = nil
                gesture.cableDrag = .control(control.kind)
                if control.kind == .button {
                    gesture.pressedControlID = control.id
                }
            case .screen:
                // Don't dismiss for screen - handle in dragEnded for click detection
                gesture.cableDrag = .control(control.kind)
            }
            return
        }

        if patchVM.dragFrom != nil {
            patchVM.updateDrag(point: point)
            if let placed = rackVM.placedModule(at: point),
               let control = rackVM.controlAtPoint(point, in: placed),
               control.kind == .patchPoint {
                hoverAnimator.hoverIn(moduleID: placed.id, controlID: control.id)
            } else {
                hoverAnimator.hoverOut()
            }
        } else if patchVM.knobDragInfo != nil {
            patchVM.updateKnobDrag(currentY: value.location.y / currentZoom)
        } else if patchVM.sliderDragInfo != nil {
            patchVM.updateSliderDrag(point: scaledPoint(value.location))
        }
    }

    func handleCableDragEnded(_ value: DragGesture.Value) {
        let drag = gesture.cableDrag
        gesture.cableDrag = .idle

        switch drag {
        case .pin:
            patchVM.endPinDrag()
            return
        case .pan:
            lastPanOffset = panOffset
            return
        case .cableMarquee, .groupMarquee:
            // Selection was applied while dragging
            rackVM.marqueeRect = nil
            return
        case .shiftClick:
            let startPoint = scaledPoint(value.startLocation)
            // Check cable body first — cables render on top of patch points
            if let cableID = cableGeometry?.cable(at: startPoint) {
                patchVM.toggleCableSelection(cableID)
            } else if let placed = rackVM.placedModule(at: startPoint),
                      let control = rackVM.controlAtPoint(startPoint, in: placed),
                      control.kind == .patchPoint {
                // Shift-clicking a patch point — select cables connected to it
                for id in patchVM.cablesForPatchPoint(moduleID: placed.id, controlID: control.id) {
                    patchVM.toggleCableSelection(id)
                }
            }
            return
        case .groupSelecting:
            // Click completed without enough drag to become pan
            let startPoint = scaledPoint(value.startLocation)
            let extending: Bool
            #if canImport(AppKit)
            extending = NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)
            #else
            extending = false
            #endif
            if let placed = rackVM.placedModule(at: startPoint) {
                if extending {
                    if rackVM.selectedPlacedModuleIDs.contains(placed.id) {
                        rackVM.selectedPlacedModuleIDs.remove(placed.id)
                    } else {
                        rackVM.selectedPlacedModuleIDs.insert(placed.id)
                    }
                } else {
                    rackVM.selectedPlacedModuleIDs = [placed.id]
                }
            }
            return
        case .doubleClick:
            let point = scaledPoint(value.startLocation)
            if let placed = rackVM.placedModule(at: point),
               let control = rackVM.controlAtPoint(point, in: placed) {
                patchVM.deactivateControl(moduleID: placed.id, controlID: control.id)
            }
            return
        case .control(let kind):
            endControlPress(kind: kind, value: value)
            return
        case .idle:
            break
        }

        if patchVM.knobDragInfo != nil {
            patchVM.endKnobDrag()
            return
        }

        if patchVM.sliderDragInfo != nil {
            patchVM.endSliderDrag()
            return
        }

        let point = scaledPoint(value.location)
        var targetModule: UUID?
        var targetControl: UUID?

        if let placed = rackVM.placedModule(at: point),
           let control = rackVM.controlAtPoint(point, in: placed),
           control.kind == .patchPoint {
            targetModule = placed.id
            targetControl = control.id
        }

        patchVM.endDrag(moduleID: targetModule, controlID: targetControl)
        hoverAnimator.hoverOut()
    }

    /// Acts on a press of a toggle, button or screen when it is released.
    private func endControlPress(kind: Control.Kind, value: DragGesture.Value) {
        if kind == .toggleSwitch || kind == .button {
            let point = scaledPoint(value.location)
            if let placed = rackVM.placedModule(at: point),
               let control = rackVM.controlAtPoint(point, in: placed),
               control.kind == .toggleSwitch || control.kind == .button {
                patchVM.toggleControlValue(moduleID: placed.id, controlID: control.id, states: control.stateCount)
            }
            gesture.pressedControlID = nil
            return
        }

        if kind == .screen {
            let point = scaledPoint(value.startLocation)
            if let placed = rackVM.placedModule(at: point),
               let control = rackVM.controlAtPoint(point, in: placed),
               control.kind == .screen {
                // Toggle magnifier for this screen
                if magnifiedScreen?.moduleID == placed.id && magnifiedScreen?.controlID == control.id {
                    // Clicking same screen - dismiss magnifier
                    magnifiedScreen = nil
                    magnifierInfo = nil
                } else {
                    // Clicking new or no screen - show magnifier
                    showMagnifier(for: placed.id, controlID: control.id)
                }
            } else {
                // Clicked off screen - dismiss magnifier
                magnifiedScreen = nil
                magnifierInfo = nil
            }
            return
        }
    }

    static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}
