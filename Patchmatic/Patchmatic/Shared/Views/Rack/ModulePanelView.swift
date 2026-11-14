import SwiftUI

struct ModulePanelView: View {
    var definition: ModuleDefinition
    var panelHeight: CGFloat = EurorackConstants.panelHeight
    var knobValues: [UUID: Double]
    var patchPointColors: [UUID: Color] = [:]
    var activatedControlIDs: Set<UUID>?
    var backgroundImage: CGImage?
    var backgroundImageOpacity: Double = 0.5
    var showLabels: Bool = true
    var labelsIgnoreActivation: Bool = false
    var zoom: CGFloat = 1.0
    var screenImages: [UUID: Image] = [:]
    var pressedControlID: UUID? = nil
    var hoveredControlID: UUID? = nil
    var hoveredControlBrightness: Double = 0.0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.drawsShadows) private var drawsShadows

    var body: some View {
        let panelWidth = EurorackConstants.width(forHP: definition.widthHP)

        Canvas { context, size in
            ModuleRenderer.draw(
                in: context,
                definition: definition,
                size: size,
                knobValues: knobValues,
                patchPointColors: patchPointColors,
                activatedControlIDs: activatedControlIDs,
                backgroundImage: backgroundImage,
                backgroundImageOpacity: backgroundImageOpacity,
                showLabels: showLabels,
                labelsIgnoreActivation: labelsIgnoreActivation,
                isDarkMode: colorScheme == .dark,
                zoom: zoom,
                screenImages: screenImages,
                pressedControlID: pressedControlID,
                hoveredControlID: hoveredControlID,
                hoveredControlBrightness: hoveredControlBrightness,
                drawsShadows: drawsShadows
            )
        }
        .frame(width: panelWidth * zoom, height: panelHeight * zoom)
    }
}
