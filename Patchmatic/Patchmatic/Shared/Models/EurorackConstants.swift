import Foundation

enum EurorackConstants {
    /// One HP in points at 1x zoom
    static let pointsPerHP: CGFloat = 10.0

    /// Standard Eurorack panel height (3U) in points
    static let panelHeight: CGFloat = 256.0

    /// 1U tile row height in points (proportional to mm: 39.65/128.5 × 256)
    static let panelHeight1U: CGFloat = 79.0

    /// Gap between rack rows in points
    static let rowSpacing: CGFloat = 12.0

    /// Converts HP width to points
    static func width(forHP hp: Int) -> CGFloat {
        CGFloat(hp) * pointsPerHP
    }

    /// Default knob radius in points
    static let knobRadius: CGFloat = 12.0

    /// Default patch point radius in points
    static let patchPointRadius: CGFloat = 5.0

    /// Default toggle switch radius in points
    static let toggleSwitchRadius: CGFloat = 6.0

    /// Default button radius in points
    static let buttonRadius: CGFloat = 5.0

    /// Default slider knob radius in points
    static let sliderRadius: CGFloat = 4.8

    /// Default slider track length in points
    static let defaultSliderTrackLength: Double = 24.0

    /// Default screen width in points when placing a new screen control
    static let defaultScreenWidth: Double = 30.0
    /// Default screen height in points when placing a new screen control
    static let defaultScreenHeight: Double = 30.0

    /// Minimum module width in HP
    static let minModuleHP: Int = 2

    /// Maximum module width in HP
    static let maxModuleHP: Int = 999
}
