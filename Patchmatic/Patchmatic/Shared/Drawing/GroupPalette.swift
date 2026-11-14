import SwiftUI

enum GroupPalette {
    static let colors: [Color] = [
        // Row 1: Saturated primaries and secondaries
        Color(hue: 0.00, saturation: 0.50, brightness: 0.85),  // Red
        Color(hue: 0.08, saturation: 0.55, brightness: 0.90),  // Vermilion
        Color(hue: 0.12, saturation: 0.50, brightness: 0.90),  // Amber
        Color(hue: 0.17, saturation: 0.55, brightness: 0.88),  // Gold
        Color(hue: 0.22, saturation: 0.50, brightness: 0.85),  // Lime
        Color(hue: 0.30, saturation: 0.50, brightness: 0.78),  // Green
        Color(hue: 0.38, saturation: 0.45, brightness: 0.75),  // Sage
        Color(hue: 0.45, saturation: 0.45, brightness: 0.78),  // Emerald
        Color(hue: 0.50, saturation: 0.40, brightness: 0.80),  // Teal
        Color(hue: 0.55, saturation: 0.40, brightness: 0.85),  // Sky
        Color(hue: 0.60, saturation: 0.45, brightness: 0.85),  // Azure
        Color(hue: 0.65, saturation: 0.45, brightness: 0.82),  // Blue
        Color(hue: 0.72, saturation: 0.40, brightness: 0.80),  // Indigo
        Color(hue: 0.78, saturation: 0.35, brightness: 0.82),  // Lavender
        Color(hue: 0.83, saturation: 0.40, brightness: 0.80),  // Purple
        Color(hue: 0.90, saturation: 0.40, brightness: 0.82),  // Magenta

        // Row 2: Muted/shifted variants for contrast with row 1
        Color(hue: 0.02, saturation: 0.35, brightness: 0.92),  // Salmon
        Color(hue: 0.06, saturation: 0.40, brightness: 0.95),  // Peach
        Color(hue: 0.13, saturation: 0.35, brightness: 0.95),  // Cream
        Color(hue: 0.19, saturation: 0.40, brightness: 0.92),  // Chartreuse
        Color(hue: 0.26, saturation: 0.35, brightness: 0.88),  // Mint
        Color(hue: 0.34, saturation: 0.30, brightness: 0.85),  // Seafoam
        Color(hue: 0.42, saturation: 0.30, brightness: 0.82),  // Jade
        Color(hue: 0.48, saturation: 0.30, brightness: 0.88),  // Aqua
        Color(hue: 0.53, saturation: 0.25, brightness: 0.92),  // Ice
        Color(hue: 0.58, saturation: 0.30, brightness: 0.90),  // Steel
        Color(hue: 0.63, saturation: 0.30, brightness: 0.88),  // Periwinkle
        Color(hue: 0.70, saturation: 0.25, brightness: 0.88),  // Slate
        Color(hue: 0.76, saturation: 0.25, brightness: 0.90),  // Lilac
        Color(hue: 0.82, saturation: 0.25, brightness: 0.88),  // Wisteria
        Color(hue: 0.88, saturation: 0.30, brightness: 0.88),  // Orchid
        Color(hue: 0.95, saturation: 0.30, brightness: 0.90),  // Blush
    ]

    static func color(forIndex index: Int) -> Color {
        colors[index % colors.count]
    }

    /// Returns the palette index used the fewest times, preferring unused indices first.
    static func leastUsedIndex(excluding usedIndices: [Int]) -> Int {
        var counts = Array(repeating: 0, count: colors.count)
        for idx in usedIndices {
            counts[idx % colors.count] += 1
        }
        let minCount = counts.min() ?? 0
        let candidates = counts.enumerated().filter { $0.element == minCount }.map(\.offset)
        // Among least-used, pick the one most distant from existing indices
        if candidates.count == 1 || usedIndices.isEmpty { return candidates[0] }
        let usedSet = Set(usedIndices.map { $0 % colors.count })
        var bestIndex = candidates[0]
        var bestDistance = 0
        for candidate in candidates {
            let minDist = usedSet.map { abs(candidate - $0) }.map { min($0, colors.count - $0) }.min() ?? colors.count
            if minDist > bestDistance {
                bestDistance = minDist
                bestIndex = candidate
            }
        }
        return bestIndex
    }
}
