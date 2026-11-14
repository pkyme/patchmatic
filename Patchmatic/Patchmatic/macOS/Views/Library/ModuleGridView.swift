import SwiftUI

enum ModuleGridAxis {
    case vertical
    case horizontal
}

struct ModuleGridView: View {
    var modules: [ModuleDefinition]
    @Binding var selectedModuleIDs: Set<UUID>
    var axis: ModuleGridAxis = .vertical
    var thumbnailHeight: CGFloat = 120
    var draggable: Bool = false
    var onDragStart: ((ModuleDefinition) -> Void)?
    var contextMenu: ((ModuleDefinition) -> AnyView)?

    private let spacing: CGFloat = 12
    @State private var lastClickedID: UUID?

    var body: some View {
        switch axis {
        case .vertical:
            verticalGrid
        case .horizontal:
            horizontalGrid
        }
    }

    private var verticalGrid: some View {
        GeometryReader { geo in
            let columns = max(1, Int(geo.size.width / 100))
            let gridItems = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)

            ScrollView {
                LazyVGrid(columns: gridItems, spacing: spacing) {
                    ForEach(modules) { module in
                        cell(for: module)
                    }
                }
                .padding(spacing)
            }
        }
    }

    private var horizontalGrid: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                ForEach(modules) { module in
                    cell(for: module)
                        .frame(width: thumbnailHeight * 0.6)
                }
            }
            .padding(spacing)
        }
    }

    private func cell(for module: ModuleDefinition) -> some View {
        ModuleGridCell(
            module: module,
            isSelected: selectedModuleIDs.contains(module.id),
            thumbnailHeight: thumbnailHeight
        )
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.shift), let anchorID = lastClickedID,
               let anchorIndex = modules.firstIndex(where: { $0.id == anchorID }),
               let clickIndex = modules.firstIndex(where: { $0.id == module.id }) {
                let range = min(anchorIndex, clickIndex)...max(anchorIndex, clickIndex)
                let rangeIDs = Set(modules[range].map(\.id))
                if flags.contains(.command) {
                    selectedModuleIDs.formUnion(rangeIDs)
                } else {
                    selectedModuleIDs = rangeIDs
                }
            } else if flags.contains(.command) {
                if selectedModuleIDs.contains(module.id) {
                    selectedModuleIDs.remove(module.id)
                } else {
                    selectedModuleIDs.insert(module.id)
                }
            } else {
                selectedModuleIDs = [module.id]
            }
            lastClickedID = module.id
        }
        .if(draggable) { view in
            view.onDrag {
                onDragStart?(module)
                return NSItemProvider(object: module.id.uuidString as NSString)
            } preview: {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .if(contextMenu != nil) { view in
            view.contextMenu {
                contextMenu?(module)
            }
        }
    }
}

struct ModuleGridCell: View {
    var module: ModuleDefinition
    var isSelected: Bool
    var thumbnailHeight: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var isHovered = false
    /// Thumbnail loaded in the background on a cache miss, with the request it was loaded for
    @State private var loadedThumbnail: (key: String, image: CGImage)?

    private var thumbnailPixelHeight: CGFloat { thumbnailHeight * displayScale }

    /// Identifies the thumbnail request; changes when the image file is replaced
    private var thumbnailKey: String {
        "\(module.imageFileName ?? "")-\(Int(thumbnailPixelHeight))-\(ImageStoreChanges.shared.version)"
    }

    private var thumbnail: CGImage? {
        guard let filename = module.imageFileName else { return nil }
        if let cached = ImageStore.cachedThumbnail(filename, maxHeight: thumbnailPixelHeight)?.platformCGImage {
            return cached
        }
        return loadedThumbnail?.key == thumbnailKey ? loadedThumbnail?.image : nil
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let cgImage = thumbnail {
                    Image(decorative: cgImage, scale: displayScale)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .modifier(ModuleThumbnailEmboss())
                } else {
                    let panelWidth = EurorackConstants.width(forHP: module.widthHP)
                    let panelHeight = module.panelHeight
                    let aspect = panelWidth / panelHeight
                    Canvas { context, size in
                        let zoom = size.height / panelHeight
                        ModuleRenderer.draw(
                            in: context,
                            definition: module,
                            size: size,
                            zoom: zoom
                        )
                    }
                    .aspectRatio(aspect, contentMode: .fit)
                    .modifier(ModuleThumbnailEmboss())
                }
            }
            .frame(height: thumbnailHeight)
            .task(id: thumbnailKey) {
                guard let filename = module.imageFileName,
                      ImageStore.cachedThumbnail(filename, maxHeight: thumbnailPixelHeight) == nil else { return }
                let key = thumbnailKey
                let height = thumbnailPixelHeight
                let image = await Task.detached(priority: .userInitiated) {
                    ImageStore.loadThumbnail(filename, maxHeight: height)?.platformCGImage
                }.value
                if let image { loadedThumbnail = (key, image) }
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }

            Text(module.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct ModuleThumbnailEmboss: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        content
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .black.opacity(isDark ? 0.4 : 0.25),
                                .white.opacity(isDark ? 0.12 : 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(isDark ? 0.5 : 0.3), radius: 3, x: 0, y: 1.5)
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
