import SwiftUI

struct HorizontalSplitOrStack<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        #if os(macOS)
        HSplitView { content }
        #else
        HStack { content }
        #endif
    }
}

