import SwiftUI

extension ModuleEditorViewModel {
    // MARK: - Analysis

    func analyseImage() {
        guard let image = backgroundImage, let module = selectedModule,
              let cgImage = image.platformCGImage else { return }
        let imageWidth = Double(cgImage.width)
        let imageHeight = Double(cgImage.height)

        ImageAnalyzer.runDetection(on: image) { [weak self] detections in
            // Results are dropped if the user has moved on to another module
            guard let self, self.selectedModuleID == module.id, !detections.isEmpty else { return }
            self.prepareEdit()

            // Use patch point bounding boxes to determine 1U vs 3U format.
            // Jacks are ~9mm diameter; comparing that to the image height gives us the panel height in mm.
            let jackDetections = detections.filter { $0.detectedClass == .jack }
            if !jackDetections.isEmpty {
                let jackPixelSizes = jackDetections.map {
                    ($0.boundingBox.width * imageWidth + $0.boundingBox.height * imageHeight) / 2
                }.sorted()
                let medianBboxPixels = jackPixelSizes[jackPixelSizes.count / 2]

                let pixelsPerMM = medianBboxPixels / Self.jackDiameterMM
                let panelHeightMM = imageHeight / pixelsPerMM

                let format: RowSize = panelHeightMM > Self.formatThresholdMM ? .threeU : .oneU
                module.format = format
            }

            // HP is derived from the image aspect ratio and the known panel height
            let panelWidthMM = imageWidth / imageHeight * module.format.heightMM
            let hp = Int((panelWidthMM / 5.08).rounded())
            module.widthHP = max(EurorackConstants.minModuleHP, min(EurorackConstants.maxModuleHP, hp))

            let panelWidth = Double(EurorackConstants.width(forHP: module.widthHP))
            let panelHeight = Double(module.panelHeight)

            for detection in detections {
                let centerX = detection.boundingBox.origin.x + detection.boundingBox.width / 2
                let centerY = detection.boundingBox.origin.y + detection.boundingBox.height / 2
                let position = NormalizedPoint(x: centerX, y: centerY)
                let kind = detection.detectedClass.controlKind
                let label = kind.defaultLabel
                let bboxW = detection.boundingBox.width * panelWidth
                let bboxH = detection.boundingBox.height * panelHeight
                let orientation: Control.Orientation = bboxH >= bboxW ? .vertical : .horizontal
                let size: Control.Size
                if kind == .patchPoint {
                    size = .medium
                } else if kind == .slider {
                    let knobDim = min(bboxW, bboxH)
                    size = Self.sizeForDetection(kind: kind, bboxPoints: knobDim)
                } else {
                    let bboxPts = max(bboxW, bboxH)
                    size = Self.sizeForDetection(kind: kind, bboxPoints: bboxPts)
                }
                let sliderTrackLength: Double = kind == .slider ? max(bboxW, bboxH) : EurorackConstants.defaultSliderTrackLength
                let control = Control(kind: kind, label: label, position: position, size: size,
                                      orientation: (kind == .slider || kind == .toggleSwitch) ? orientation : .vertical,
                                      sliderTrackLength: sliderTrackLength)
                module.controls.append(control)
            }
            self.selectedControlIDs = []
        }
    }

    static func sizeForDetection(kind: Control.Kind, bboxPoints: Double) -> Control.Size {
        let baseRadius: Double = switch kind {
        case .knob: Double(EurorackConstants.knobRadius)
        case .patchPoint: Double(EurorackConstants.patchPointRadius)
        case .toggleSwitch: Double(EurorackConstants.toggleSwitchRadius)
        case .button: Double(EurorackConstants.buttonRadius)
        case .slider: Double(EurorackConstants.sliderRadius)
        case .screen: Double(EurorackConstants.buttonRadius)
        }
        let detectedRadius = bboxPoints / 2
        let scale = detectedRadius / baseRadius
        if scale < 0.8 { return .small }
        if scale < 1.25 { return .medium }
        if scale < 1.8 { return .large }
        return .xlarge
    }
    // MARK: - Detection

    func toggleDetections() {
        if showDetections, let image = backgroundImage {
            ImageAnalyzer.runDetection(on: image) { [weak self] results in
                self?.detections = results
            }
        } else {
            detections = []
            highlightedDetectionID = nil
        }
    }

    func highlightDetection(at point: NormalizedPoint) {
        highlightedDetectionID = detections.first {
            $0.boundingBox.contains(CGPoint(x: point.x, y: point.y))
        }?.id
    }
}
