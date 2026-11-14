import SwiftUI

struct PatchNotesOverlay: View {
    let patch: Patch
    @Bindable var patchVM: PatchViewModel
    let readOnly: Bool
    var onEdit: () -> Void

    @State private var isHovering = false

    private var audioPlayer: AudioPlayer { patchVM.audioPlayer }

    private static let maxTextWidth: CGFloat = 250

    /// Touch devices have no hover, so the play control stays visible there.
    private var showsAudioControl: Bool {
        #if os(iOS)
        true
        #else
        isHovering
        #endif
    }

    var body: some View {
        PatchNotesPill(text: patch.patchNotes, maxTextWidth: Self.maxTextWidth)
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.primary.opacity(0.1), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
            .overlay {
                if patch.audioPreviewFilename != nil {
                    HoverScreenToolbar(externalHover: showsAudioControl) {
                        Button {
                            if let filename = patch.audioPreviewFilename {
                                if audioPlayer.isPlaying {
                                    audioPlayer.stop()
                                } else {
                                    audioPlayer.play(filename: filename)
                                }
                            }
                        } label: {
                            Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.5))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture {
                audioPlayer.stop()
                onEdit()
            }
            .onDisappear {
                audioPlayer.stop()
            }
    }
}

/// Sizes to the text's natural width for short text, wraps at maxTextWidth for long text.
private struct PatchNotesPill: View {
    let text: String
    let maxTextWidth: CGFloat

    var body: some View {
        if text.isEmpty {
            Color.clear.frame(width: 10, height: 10)
        } else {
            let textView = Text(text).font(.system(size: 11))
            // Try the text at its natural single-line width first.
            // If it exceeds maxTextWidth, constrain to maxTextWidth.
            ViewThatFits(in: .horizontal) {
                textView.fixedSize()
                textView.frame(width: maxTextWidth, alignment: .leading)
            }
        }
    }
}
