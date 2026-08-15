import AVFoundation
import Foundation
import MiniMaxMusic3MLX
import Observation

@MainActor
@Observable
final class ComposerModel {
    var lyrics = ComposerModel.defaultLyrics
    var caption = ComposerModel.defaultCaption
    var durationSeconds = 30.0
    var seed = 42
    var weightsPath = ComposerModel.defaultWeightsPath()
    var status = "Load MiniMax-Music3 weights, then generate."
    var isWorking = false
    var engineReady = false
    var downloadProgress: Double?
    var pipelineProgress: PipelineProgress?
    var songs: [GeneratedSong] = SongLibrary.load()
    var lastSongID: GeneratedSong.ID?
    var showingFolderPicker = false

    @ObservationIgnored private var modules: Music3Modules?
    @ObservationIgnored private var player: AVAudioPlayer?

    var lastSong: GeneratedSong? {
        songs.first { $0.id == lastSongID } ?? songs.first
    }

    func task() async {
        let root = URL(fileURLWithPath: weightsPath)
        guard ModelDownload.isReady(at: root) else { return }
        await loadWeightsButtonTapped()
    }

    func loadWeightsButtonTapped() async {
        isWorking = true
        pipelineProgress = PipelineProgress(label: "Load", completed: 0, total: 5)
        defer {
            isWorking = false
            pipelineProgress = nil
        }
        do {
            let root = URL(fileURLWithPath: weightsPath, isDirectory: true)
            status = "Loading MiniMax-Music3…"
            let loaded = try Music3Modules.loadConverted(root: root) { progress in
                Task { @MainActor in
                    self.pipelineProgress = progress
                    self.status = "Loading \(progress.label)… \(progress.completed)/\(progress.total)"
                }
            }
            modules = loaded
            engineReady = true
            UserDefaults.standard.set(weightsPath, forKey: "weightsPath")
            status = "MiniMax-Music3 ready."
        } catch {
            modules = nil
            engineReady = false
            status = error.localizedDescription
        }
    }

    func downloadWeightsButtonTapped() async {
        isWorking = true
        downloadProgress = 0
        defer {
            isWorking = false
            downloadProgress = nil
        }
        do {
            status = "Downloading MiniMax-Music3 4-bit…"
            let root = try await ModelDownload.download { progress in
                Task { @MainActor in
                    self.downloadProgress = progress
                    self.status = "Downloading MiniMax-Music3 4-bit… \(Int(progress * 100))%"
                }
            }
            weightsPath = root.path
            UserDefaults.standard.set(weightsPath, forKey: "weightsPath")
            status = "Download finished. Loading…"
            await loadWeightsButtonTapped()
        } catch {
            status = error.localizedDescription
        }
    }

    func generateButtonTapped() async {
        guard let modules else {
            status = "Load weights first."
            return
        }
        isWorking = true
        pipelineProgress = PipelineProgress(label: "AR", completed: 0, total: 1)
        defer {
            isWorking = false
            pipelineProgress = nil
        }
        do {
            status = "Generating…"
            let loaded = modules
            let lyrics = lyrics
            let caption = caption
            let duration = durationSeconds
            let seed = seed
            let temp = FileManager.default.temporaryDirectory.appending(
                path: "minimax-\(Int(Date().timeIntervalSince1970)).wav")
            let out = try await generate(
                modules: loaded,
                lyrics: lyrics,
                caption: caption,
                duration: Float(duration),
                steps: 30,
                seed: UInt64(max(0, seed)),
                output: temp
            ) { progress in
                Task { @MainActor in
                    self.pipelineProgress = progress
                    self.status = "\(progress.label) \(progress.completed)/\(progress.total)"
                }
            }
            let song = try SongLibrary.add(
                wav: out,
                lyrics: lyrics,
                caption: caption,
                duration: duration,
                seed: seed
            )
            songs = SongLibrary.load()
            lastSongID = song.id
            try play(url: song.fileURL)
            status = "Saved \(song.title)"
        } catch {
            status = error.localizedDescription
        }
    }

    func folderPicked(_ url: URL) {
        weightsPath = url.path
        showingFolderPicker = false
        UserDefaults.standard.set(weightsPath, forKey: "weightsPath")
    }

    func playButtonTapped(_ song: GeneratedSong) {
        do {
            try play(url: song.fileURL)
            lastSongID = song.id
            status = "Playing \(song.title)"
        } catch {
            status = error.localizedDescription
        }
    }

    func deleteButtonTapped(_ song: GeneratedSong) {
        if lastSongID == song.id {
            lastSongID = nil
            player?.stop()
        }
        SongLibrary.delete(song)
        songs = SongLibrary.load()
        status = "Deleted \(song.title)"
    }

    func reuseButtonTapped(_ song: GeneratedSong) {
        lyrics = song.lyrics
        caption = song.caption
        durationSeconds = song.duration
        seed = song.seed
        status = "Loaded \(song.title) into editor"
    }

    private func play(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        player?.play()
    }

    static let defaultLyrics = """
        [verse]
        MiniMax na Maku, lokalnie, bez chmury
        MLX kręci beat, metalowe tony

        [chorus]
        Śpiewam z Macintosha, ram w unified
        Piosenka z wag, nie z serwera, tylko z nas
        """

    static let defaultCaption =
        "Genre: light energetic funk. BPM: 112. Key: E major. Language: Polish. Warm male vocal, chicken-scratch guitar, tight bass, no accordion."

    static func defaultWeightsPath() -> String {
        if let last = UserDefaults.standard.string(forKey: "weightsPath"),
            FileManager.default.fileExists(atPath: last)
        {
            return last
        }
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<10 {
            url.deleteLastPathComponent()
            for name in ["mlx-4bit", "mlx-8bit", "mlx"] {
                let candidate = url.appending(path: "weights/\(name)")
                if ModelDownload.isReady(at: candidate) {
                    return candidate.path
                }
            }
        }
        return ModelDownload.defaultDirectory
            .appending(path: "models/\(ModelDownload.repoID)")
            .path
    }
}
