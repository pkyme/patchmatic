import CoreGraphics
import SwiftUI
import OnnxRuntimeBindings
import os

/// Classes the detection model outputs, in the model's class order. The order must
/// match the class order the model was trained with.
enum DetectedClass: Int, CaseIterable, Sendable {
    case knob, jack, toggleSwitch, button, slider

    /// Class name used in training
    var label: String {
        switch self {
        case .knob: "rotary knob"
        case .jack: "3.5mm audio jack"
        case .toggleSwitch: "toggle switch"
        case .button: "button"
        case .slider: "slider"
        }
    }

    var controlKind: Control.Kind {
        switch self {
        case .knob: .knob
        case .jack: .patchPoint
        case .toggleSwitch: .toggleSwitch
        case .button: .button
        case .slider: .slider
        }
    }

    /// Outline colour in the module editor's detection overlay
    var overlayColor: Color {
        switch self {
        case .knob: .blue
        case .jack: .green
        case .toggleSwitch: .orange
        case .button: .purple
        case .slider: .teal
        }
    }
}

struct Detection: Identifiable, Sendable {
    let id = UUID()
    var detectedClass: DetectedClass
    var confidence: Float
    var boundingBox: CGRect
}

struct ImageGeometry {
    var suggestedFormat: RowSize
    var suggestedWidthHP: Int
}

private let detectionLog = Logger(subsystem: "com.patchmatic", category: "detection")

enum ImageAnalyzer {

    static func analyzeGeometry(_ image: PlatformImage) -> ImageGeometry {
        guard let cgImage = image.platformCGImage else {
            return ImageGeometry(suggestedFormat: .threeU, suggestedWidthHP: 8)
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Assume 3U: panel height is 128.5mm, 1 HP = 5.08mm
        let widthMM = imageWidth / imageHeight * 128.5
        let hp = Int((widthMM / 5.08).rounded())
        let clampedHP = max(EurorackConstants.minModuleHP, min(EurorackConstants.maxModuleHP, hp))

        return ImageGeometry(suggestedFormat: .threeU, suggestedWidthHP: clampedHP)
    }

    // MARK: - Object Detection

    private static let confidenceThreshold: Float = 0.25
    private static let inputSize = 704

    // ImageNet normalisation (matches RF-DETR training preprocessing)
    private static let mean: [Float] = [0.485, 0.456, 0.406]
    private static let std:  [Float] = [0.229, 0.224, 0.225]

    /// Serial queue for all inference, so the lazily created session is never raced
    private static let inferenceQueue = DispatchQueue(label: "ImageAnalyzer.inference", qos: .userInitiated)
    /// Only accessed on `inferenceQueue`
    nonisolated(unsafe) private static var _session: ORTSession?

    private static func session() throws -> ORTSession {
        if let s = _session { return s }
        guard let modelURL = Bundle.main.url(forResource: "eurorack-controls", withExtension: "onnx") else {
            throw NSError(domain: "ImageAnalyzer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "ONNX model not found in bundle"])
        }
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        let s = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
        _session = s
        return s
    }

    static func runDetection(on image: PlatformImage, completion: @escaping @MainActor @Sendable ([Detection]) -> Void) {
        guard let cgImage = image.platformCGImage else {
            detectionLog.error("Failed to get CGImage from PlatformImage")
            Task { @MainActor in completion([]) }
            return
        }
        detectionLog.info("CGImage: \(cgImage.width)x\(cgImage.height)")

        inferenceQueue.async {
            do {
                let detections = try runORT(cgImage: cgImage)
                detectionLog.info("Detections: \(detections.count)")
                Task { @MainActor in completion(detections) }
            } catch {
                detectionLog.error("ORT inference failed: \(error.localizedDescription)")
                Task { @MainActor in completion([]) }
            }
        }
    }

    private static func runORT(cgImage: CGImage) throws -> [Detection] {
        let size = inputSize
        let floats = preprocessImage(cgImage, targetSize: size)

        let inputData = floats.withUnsafeBytes { NSMutableData(bytes: $0.baseAddress!, length: $0.count) }
        let inputShape: [NSNumber] = [1, 3, NSNumber(value: size), NSNumber(value: size)]
        let inputValue = try ORTValue(tensorData: inputData, elementType: .float, shape: inputShape)

        let outputs = try session().run(
            withInputs: ["input": inputValue],
            outputNames: ["dets", "labels"],
            runOptions: nil
        )

        guard let detsValue = outputs["dets"], let labelsValue = outputs["labels"] else { return [] }

        let boxesData  = try detsValue.tensorData()   as Data
        let logitsData = try labelsValue.tensorData() as Data

        let boxes:  [Float] = boxesData.withUnsafeBytes  { Array($0.bindMemory(to: Float.self)) }
        let logits: [Float] = logitsData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }

        // boxes:  [300, 4] — normalised cx, cy, w, h
        // logits: [300, 6] — raw BCE logits; use first 5 columns (5 classes)
        let numDets       = boxes.count / 4
        let numLogitCols  = logits.count / max(numDets, 1)
        if numLogitCols < DetectedClass.allCases.count {
            detectionLog.error("Model outputs \(numLogitCols) classes; expected at least \(DetectedClass.allCases.count)")
        }
        let relevantClasses = min(numLogitCols, DetectedClass.allCases.count)

        var detections: [Detection] = []

        for i in 0..<numDets {
            var bestClass = -1
            var bestConf: Float = 0

            for c in 0..<relevantClasses {
                let conf = sigmoid(logits[i * numLogitCols + c])
                if conf > bestConf { bestConf = conf; bestClass = c }
            }

            guard bestConf >= confidenceThreshold,
                  let detectedClass = DetectedClass(rawValue: bestClass) else { continue }

            let cx = boxes[i * 4 + 0]
            let cy = boxes[i * 4 + 1]
            let w  = boxes[i * 4 + 2]
            let h  = boxes[i * 4 + 3]

            detections.append(Detection(
                detectedClass: detectedClass,
                confidence: bestConf,
                boundingBox: CGRect(
                    x: CGFloat(cx - w / 2),
                    y: CGFloat(cy - h / 2),
                    width: CGFloat(w),
                    height: CGFloat(h)
                )
            ))
        }

        return nonMaxSuppression(detections)
    }

    // Resize to targetSize×targetSize (squeezing, matching Python training) and return
    // a CHW float array with ImageNet normalisation applied.
    private static func preprocessImage(_ cgImage: CGImage, targetSize: Int) -> [Float] {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: targetSize * targetSize * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        let pixelCount = targetSize * targetSize
        var result = [Float](repeating: 0, count: 3 * pixelCount)

        for i in 0..<pixelCount {
            result[0 * pixelCount + i] = (Float(pixelData[i * 4 + 0]) / 255.0 - mean[0]) / std[0]
            result[1 * pixelCount + i] = (Float(pixelData[i * 4 + 1]) / 255.0 - mean[1]) / std[1]
            result[2 * pixelCount + i] = (Float(pixelData[i * 4 + 2]) / 255.0 - mean[2]) / std[2]
        }

        return result
    }

    @inline(__always)
    private static func sigmoid(_ x: Float) -> Float {
        1.0 / (1.0 + exp(-x))
    }

    private static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = Float(intersection.width * intersection.height)
        let unionArea = Float(a.width * a.height + b.width * b.height) - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }

    private static func nonMaxSuppression(_ detections: [Detection], iouThreshold: Float = 0.5) -> [Detection] {
        let sorted = detections.sorted { $0.confidence > $1.confidence }
        var kept: [Detection] = []
        for det in sorted {
            if !kept.contains(where: { iou(det.boundingBox, $0.boundingBox) > iouThreshold }) {
                kept.append(det)
            }
        }
        return kept
    }
}
