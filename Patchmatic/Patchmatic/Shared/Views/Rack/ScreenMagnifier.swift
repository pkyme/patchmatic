import SwiftUI

// MARK: - Screen magnifier

struct ScreenMagnifierInfo {
    let image: PlatformImage
    let controlViewportRect: CGRect
    let moduleID: UUID
    let controlID: UUID
    let hasImages: Bool
    let canCycle: Bool
}

struct ScreenMagnifierView: View {
    let info: ScreenMagnifierInfo
    let onAddScreenImage: ((UUID, UUID) -> Void)?
    let onRemoveScreenImage: ((UUID, UUID) -> Void)?
    let onDismiss: () -> Void
    let patchVM: PatchViewModel

    @State private var isHovering = false
    @State private var isToolbarHovering = false

    var body: some View {
        // Fetch current state dynamically so updates are reflected
        let screenImage = patchVM.activePatch?.screenImage(forModule: info.moduleID, control: info.controlID)
        let currentImage = screenImage.flatMap { $0.activeFilename.flatMap { ImageStore.load($0) } } ?? info.image
        let hasImages = screenImage != nil && !screenImage!.imageFilenames.isEmpty
        let canCycle = screenImage?.imageFilenames.count ?? 0 > 1
        #if os(iOS)
        // Sized from the image shown on open so the frame stays fixed while paging
        let imgSize = info.image.size
        #else
        let imgSize = currentImage.size
        #endif
        let aspect = imgSize.width > 0 ? imgSize.width / imgSize.height : 1.5
        let w: CGFloat = 320
        let h = w / aspect

        #if os(iOS)
        ScreenImagePager(
            filenames: screenImage?.imageFilenames ?? [],
            initialIndex: screenImage?.activeIndex ?? 0,
            size: CGSize(width: w, height: h)
        ) { index in
            patchVM.selectScreenImage(moduleID: info.moduleID, controlID: info.controlID, at: index)
        }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .onTapGesture {
                onDismiss()
            }
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 4)
            .position(x: info.controlViewportRect.midX, y: info.controlViewportRect.midY)
        #else
        Image(platformImage: currentImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            .onTapGesture {
                onDismiss()
            }
            .onHover { isHovering = $0 }
            .overlay {
                // Screen toolbar at bottom
                VStack {
                    Spacer()
                    HoverScreenToolbar(externalHover: isHovering || isToolbarHovering) {
                        ScreenToolbarView(
                            screenWidth: w,
                            zoom: 4.0,
                            hasImages: hasImages,
                            canCycle: canCycle,
                            zoomIconName: "minus.magnifyingglass",
                            readOnly: onAddScreenImage == nil,
                            onAddImage: {
                                onAddScreenImage?(info.moduleID, info.controlID)
                            },
                            onDeleteImage: {
                                onRemoveScreenImage?(info.moduleID, info.controlID)
                            },
                            onZoomImage: {
                                onDismiss()
                            },
                            onCycleImage: {
                                patchVM.cycleScreenImage(moduleID: info.moduleID, controlID: info.controlID)
                            }
                        )
                    }
                    .onHover { isToolbarHovering = $0 }
                    .padding(.bottom, 8)
                }
                .padding(12)
            }
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 4)
            .position(x: info.controlViewportRect.midX, y: info.controlViewportRect.midY)
            .id(screenImage?.activeIndex ?? 0)
        #endif
    }
}

#if os(iOS)
/// Swipeable screen images with a page indicator along the bottom.
struct ScreenImagePager: View {
    let filenames: [String]
    let size: CGSize
    let onSelect: (Int) -> Void

    @State private var scrolledIndex: Int?

    init(filenames: [String], initialIndex: Int, size: CGSize, onSelect: @escaping (Int) -> Void) {
        self.filenames = filenames
        self.size = size
        self.onSelect = onSelect
        _scrolledIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(filenames.indices, id: \.self) { index in
                    Group {
                        if let image = ImageStore.load(filenames[index]) {
                            Image(platformImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.black
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .clipped()
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrolledIndex)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottom) {
            if filenames.count > 1 {
                PageIndicator(count: filenames.count, index: scrolledIndex, highlightOnAppear: true)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: scrolledIndex) { _, index in
            if let index { onSelect(index) }
        }
    }
}
#endif
