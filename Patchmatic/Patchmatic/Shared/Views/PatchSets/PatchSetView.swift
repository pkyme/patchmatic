import SwiftUI

struct PatchSetView: View {
    @Bindable var rackVM: RackViewModel
    @Bindable var patchVM: PatchViewModel
    @Bindable var setVM: PatchSetViewModel
    /// Enables swiping in from the screen edges to change patch (iOS).
    var edgeSwipeEnabled = false

    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        if let set = setVM.activeSet {
            VStack(spacing: 0) {
                if set.patchIDs.isEmpty {
                    ContentUnavailableView("Empty Set",
                                          systemImage: "list.number",
                                          description: Text("Add patches to this set from the sidebar."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RackView(rackVM: rackVM, patchVM: patchVM, showCables: true, readOnly: true)
                        #if os(iOS)
                        .offset(x: swipeOffset)
                        .clipped()
                        .overlay {
                            if edgeSwipeEnabled {
                                EdgeSwipeNavigation(
                                    offset: $swipeOffset,
                                    canGoBack: setVM.canGoBack,
                                    canGoForward: setVM.canGoForward,
                                    onPrevious: setVM.goToPrevious,
                                    onNext: setVM.goToNext
                                )
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if edgeSwipeEnabled, set.patchIDs.count > 1 {
                                PageIndicator(count: set.patchIDs.count, index: setVM.currentIndex)
                                    .padding(.bottom, 16)
                            }
                        }
                        #endif
                }

                #if os(macOS)
                Divider()

                HStack {
                    Button {
                        setVM.goToPrevious()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!setVM.canGoBack)
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    if let index = setVM.currentIndex, let patch = setVM.currentPatch {
                        Text("\(index + 1) / \(set.patchIDs.count)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text("—")
                            .foregroundStyle(.quaternary)
                        Text(patch.name)
                            .fontWeight(.medium)
                    }

                    Button {
                        setVM.goToNext()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!setVM.canGoForward)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                #endif
            }
        } else {
            ContentUnavailableView("No Set Selected",
                                   systemImage: "list.number",
                                   description: Text("Select or create a set from the sidebar."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#if os(iOS)
/// Transparent strips along the left and right edges. Swiping inward from the left
/// edge slides to the previous patch, from the right edge to the next.
private struct EdgeSwipeNavigation: View {
    @Binding var offset: CGFloat
    let canGoBack: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    private static let edgeWidth: CGFloat = 24
    /// Resistance applied when there is no patch in the swipe direction.
    private static let rubberBand: CGFloat = 0.25

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                edge(direction: 1, enabled: canGoBack, width: proxy.size.width, action: onPrevious)
                Spacer()
                edge(direction: -1, enabled: canGoForward, width: proxy.size.width, action: onNext)
            }
        }
    }

    /// `direction` is +1 for the left edge (dragging right) and -1 for the right edge (dragging left).
    private func edge(direction: CGFloat, enabled: Bool, width: CGFloat, action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: Self.edgeWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let travel = max(value.translation.width * direction, 0)
                        offset = direction * (enabled ? travel : travel * Self.rubberBand)
                    }
                    .onEnded { value in
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                        let travel = value.predictedEndTranslation.width * direction
                        guard enabled, isHorizontal, travel > width / 3 else {
                            withAnimation(.spring(duration: 0.3)) { offset = 0 }
                            return
                        }
                        withAnimation(.easeIn(duration: 0.15)) {
                            offset = direction * width
                        } completion: {
                            action()
                            offset = -direction * width
                            withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                        }
                    }
            )
    }
}

/// Dots showing the current position in a sequence. Dimmed at rest,
/// brightening briefly whenever the position changes.
struct PageIndicator: View {
    let count: Int
    let index: Int?
    /// Also brightens briefly when first shown.
    var highlightOnAppear = false

    @State private var isHighlighted = false
    @State private var fadeTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.gray : Color.clear)
                    .strokeBorder(Color.gray, lineWidth: 2)
                    .frame(width: 14, height: 14)
            }
        }
        .opacity(isHighlighted ? 1 : 0.3)
        .allowsHitTesting(false)
        .onAppear {
            if highlightOnAppear { highlight() }
        }
        .onChange(of: index) { _, _ in highlight() }
    }

    private func highlight() {
        fadeTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { isHighlighted = true }
        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.6)) { isHighlighted = false }
        }
    }
}
#endif
