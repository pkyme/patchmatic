import Foundation

struct Control: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: Kind
    var label: String
    /// Normalized position within the module panel (0...1 for both x and y)
    var position: NormalizedPoint
    var size: Size
    var orientation: Orientation
    /// Width of a screen control in points at 1x zoom. Only meaningful for `.screen` kind.
    var screenWidth: Double
    /// Height of a screen control in points at 1x zoom. Only meaningful for `.screen` kind.
    var screenHeight: Double
    /// Track length in points. Only meaningful for `.slider` kind.
    var sliderTrackLength: Double
    /// Named discrete states for a toggle switch or button
    var controlStates: [String]
    /// Display config for the control name label
    var controlLabel: LabelConfig
    /// Display config for the active state name label (meaningful for button/toggleSwitch)
    var stateLabel: LabelConfig

    /// Number of discrete states (always at least 2)
    var stateCount: Int { max(2, controlStates.count) }

    /// Convenience accessor; maps to controlLabel.position == .disabled
    var showLabel: Bool {
        get { controlLabel.position != .disabled }
        set {
            if newValue, controlLabel.position == .disabled { controlLabel.position = .below }
            else if !newValue { controlLabel.position = .disabled }
        }
    }

    init(id: UUID = UUID(), kind: Kind, label: String, position: NormalizedPoint, size: Size = .medium, orientation: Orientation = .vertical, screenWidth: Double = 0, screenHeight: Double = 0, sliderTrackLength: Double = EurorackConstants.defaultSliderTrackLength, controlStates: [String] = ["Off", "On"], controlLabel: LabelConfig = LabelConfig(), stateLabel: LabelConfig = LabelConfig(position: .disabled)) {
        self.id = id
        self.kind = kind
        self.label = label
        self.position = position
        self.size = kind == .patchPoint ? .medium : size
        self.orientation = orientation
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.sliderTrackLength = sliderTrackLength
        self.controlStates = controlStates
        self.controlLabel = controlLabel
        self.stateLabel = stateLabel
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, label, position, size, orientation
        case screenWidth, screenHeight, sliderTrackLength
        case controlStates
        case controlLabel, stateLabel
        // legacy decode-only keys
        case showLabel, stateLabelPosition, stateLabelFontSize, toggleStates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
        position = try container.decode(NormalizedPoint.self, forKey: .position)
        let decodedSize = try container.decode(Size.self, forKey: .size)
        size = kind == .patchPoint ? .medium : decodedSize
        orientation = try container.decodeIfPresent(Orientation.self, forKey: .orientation) ?? .vertical
        screenWidth = try container.decodeIfPresent(Double.self, forKey: .screenWidth) ?? 0
        screenHeight = try container.decodeIfPresent(Double.self, forKey: .screenHeight) ?? 0
        sliderTrackLength = try container.decodeIfPresent(Double.self, forKey: .sliderTrackLength) ?? EurorackConstants.defaultSliderTrackLength
        if let states = try container.decodeIfPresent([String].self, forKey: .controlStates) {
            controlStates = states
        } else {
            let n = max(2, (try? container.decodeIfPresent(Int.self, forKey: .toggleStates)) ?? 2)
            controlStates = (0..<n).map { i in
                switch i { case 0: return "Off"; case 1: return "On"; default: return "State \(i + 1)" }
            }
        }
        if let cl = try container.decodeIfPresent(LabelConfig.self, forKey: .controlLabel) {
            controlLabel = cl
        } else {
            let show = try container.decodeIfPresent(Bool.self, forKey: .showLabel) ?? true
            controlLabel = LabelConfig(position: show ? .below : .disabled)
        }
        if let sl = try container.decodeIfPresent(LabelConfig.self, forKey: .stateLabel) {
            stateLabel = sl
        } else {
            let posStr = try container.decodeIfPresent(String.self, forKey: .stateLabelPosition)
            let fontSize = try container.decodeIfPresent(Double.self, forKey: .stateLabelFontSize) ?? 5.0
            if let posStr {
                let pos: LabelPosition = posStr == "Above" ? .above : .below
                stateLabel = LabelConfig(position: pos, fontSize: fontSize)
            } else {
                stateLabel = LabelConfig(position: .disabled, fontSize: fontSize)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(label, forKey: .label)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(screenWidth, forKey: .screenWidth)
        try container.encode(screenHeight, forKey: .screenHeight)
        try container.encode(sliderTrackLength, forKey: .sliderTrackLength)
        try container.encode(controlStates, forKey: .controlStates)
        try container.encode(controlLabel, forKey: .controlLabel)
        try container.encode(stateLabel, forKey: .stateLabel)
    }

    enum Kind: String, Codable, Hashable, CaseIterable {
        case knob
        case patchPoint
        case toggleSwitch
        case button
        case slider
        case screen

        var displayName: String {
            switch self {
            case .knob: "Knob"
            case .patchPoint: "Patch Point"
            case .toggleSwitch: "Toggle Switch"
            case .button: "Button"
            case .slider: "Slider"
            case .screen: "Screen"
            }
        }

        var defaultLabel: String {
            switch self {
            case .knob: "Knob"
            case .patchPoint: "Patch"
            case .toggleSwitch: "Switch"
            case .button: "Button"
            case .slider: "Slider"
            case .screen: "Screen"
            }
        }

        var iconName: String {
            switch self {
            case .knob: "circle"
            case .patchPoint: "circle.fill"
            case .toggleSwitch: "switch.2"
            case .button: "square.fill"
            case .slider: "slider.vertical.3"
            case .screen: "display"
            }
        }
    }

    enum Orientation: String, Codable, Hashable, CaseIterable {
        case vertical = "Vertical"
        case horizontal = "Horizontal"
    }

    enum LabelPosition: String, Codable, Hashable, CaseIterable {
        case above = "Above"
        case below = "Below"
        case left = "Left"
        case right = "Right"
        case disabled = "Off"
    }

    struct LabelConfig: Codable, Hashable {
        var position: LabelPosition
        var fontSize: Double
        var offset: Double

        init(position: LabelPosition = .below, fontSize: Double = 5.0, offset: Double = 0) {
            self.position = position
            self.fontSize = fontSize
            self.offset = offset
        }

        enum CodingKeys: String, CodingKey {
            case position, fontSize, offset
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            position = try container.decodeIfPresent(LabelPosition.self, forKey: .position) ?? .below
            fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 5.0
            offset = try container.decodeIfPresent(Double.self, forKey: .offset) ?? 0
        }
    }

    enum Size: String, Codable, Hashable, CaseIterable {
        case small = "S"
        case medium = "M"
        case large = "L"
        case xlarge = "XL"

        var scale: CGFloat {
            switch self {
            case .small:  return 0.6
            case .medium: return 1.0
            case .large:  return 1.5
            case .xlarge: return 2.2
            }
        }

    }

    /// Effective radius in points at 1x zoom
    var effectiveRadius: CGFloat {
        if kind == .patchPoint { return EurorackConstants.patchPointRadius }
        let base: CGFloat = switch kind {
        case .knob: EurorackConstants.knobRadius
        case .toggleSwitch: EurorackConstants.toggleSwitchRadius
        case .button: EurorackConstants.buttonRadius
        case .slider: EurorackConstants.sliderRadius
        case .screen: CGFloat((screenWidth + screenHeight) / 4)
        case .patchPoint: EurorackConstants.patchPointRadius
        }
        return base * size.scale
    }

    /// Returns the screen rectangle in point coordinates for a given panel size.
    /// `screenWidth`/`screenHeight` are in absolute points; `zoom` scales them for display.
    func screenRect(in panelSize: CGSize, zoom: CGFloat = 1.0) -> CGRect {
        let w = screenWidth * zoom
        let h = screenHeight * zoom
        let center = position.toPoint(in: panelSize)
        return CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
    }
}

struct NormalizedPoint: Codable, Hashable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x.clamped(to: 0...1)
        self.y = y.clamped(to: 0...1)
    }

    func toPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    static func from(point: CGPoint, in size: CGSize) -> NormalizedPoint {
        NormalizedPoint(
            x: size.width > 0 ? point.x / size.width : 0.5,
            y: size.height > 0 ? point.y / size.height : 0.5
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
