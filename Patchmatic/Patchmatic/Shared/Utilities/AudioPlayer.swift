import AVFoundation
import os

@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var isPlaying: Bool = false
    private(set) var currentFilename: String?

    func play(filename: String) {
        stop()
        guard let url = AudioStore.playableURL(for: filename) else { return }
        let p: AVAudioPlayer
        do {
            p = try AVAudioPlayer(contentsOf: url)
        } catch {
            Logger(subsystem: "com.patchmatic.app", category: "Audio")
                .error("Couldn't play \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        p.delegate = self
        player = p
        currentFilename = filename
        p.play()
        isPlaying = true
    }

    /// Whether `filename` is the file currently playing.
    func isPlaying(_ filename: String) -> Bool {
        isPlaying && currentFilename == filename
    }

    /// Stops `filename` if it is playing, otherwise plays it.
    func toggle(_ filename: String) {
        if isPlaying(filename) { stop() } else { play(filename: filename) }
    }

    func stop() {
        player?.stop()
        player = nil
        currentFilename = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        self.player = nil
        currentFilename = nil
    }
}
