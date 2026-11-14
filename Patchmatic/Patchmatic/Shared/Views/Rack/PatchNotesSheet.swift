import SwiftUI
import UniformTypeIdentifiers

struct PatchNotesSheet: View {
    @Bindable var patchVM: PatchViewModel
    let readOnly: Bool
    let onDismiss: () -> Void

    @State private var text: String
    @State private var showingAudioImporter = false

    private var audioPlayer: AudioPlayer { patchVM.audioPlayer }

    init(patchVM: PatchViewModel, readOnly: Bool, onDismiss: @escaping () -> Void) {
        self.patchVM = patchVM
        self.readOnly = readOnly
        self.onDismiss = onDismiss
        _text = State(initialValue: patchVM.activePatch?.patchNotes ?? "")
    }

    private var patch: Patch? { patchVM.activePatch }

    var body: some View {
        VStack(spacing: 16) {
            Text("Patch Notes")
                .font(.headline)

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 100, maxHeight: 200)
                .disabled(readOnly)

            // Audio section
            if let filename = patch?.audioPreviewFilename {
                HStack {
                    Button {
                        if audioPlayer.isPlaying {
                            audioPlayer.stop()
                        } else {
                            audioPlayer.play(filename: filename)
                        }
                    } label: {
                        Label(
                            audioPlayer.isPlaying ? "Stop" : "Play",
                            systemImage: audioPlayer.isPlaying ? "stop.fill" : "play.fill"
                        )
                    }

                    Text(filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if !readOnly {
                        Button("Remove", role: .destructive) {
                            audioPlayer.stop()
                            patchVM.removeAudioPreview()
                        }
                    }
                }
            } else if !readOnly {
                Button {
                    showingAudioImporter = true
                } label: {
                    Label("Attach Audio Preview", systemImage: "waveform")
                }
            }

            if readOnly {
                Button("Close") {
                    audioPlayer.stop()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                HStack {
                    Button("Cancel") {
                        audioPlayer.stop()
                        onDismiss()
                    }

                    Spacer()

                    if !text.isEmpty || patch?.audioPreviewFilename != nil {
                        Button("Clear All", role: .destructive) {
                            audioPlayer.stop()
                            text = ""
                            patchVM.updatePatchNotes("")
                            if patch?.audioPreviewFilename != nil {
                                patchVM.removeAudioPreview()
                            }
                            onDismiss()
                        }
                    }

                    Button("Save") {
                        audioPlayer.stop()
                        if text != patch?.patchNotes {
                            patchVM.updatePatchNotes(text)
                        }
                        onDismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 400)
        .fileImporter(isPresented: $showingAudioImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            patchVM.attachAudioPreview(from: url)
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
}
