import AVFoundation
import Foundation
import MiniMaxMusic3MLX
import Observation

@MainActor
@Observable
final class ComposerModel {
    var projects: [Project] = ProjectLibrary.load()
    var selectedID: Project.ID?
    var weightsPath = ComposerModel.defaultWeightsPath()
    var status = "Load MiniMax-Music3 weights, then generate."
    var isWorking = false
    var engineReady = false
    var downloadProgress: Double?
    var pipelineProgress: PipelineProgress?
    var showingFolderPicker = false
    var projectPendingDeletion: Project.ID?

    @ObservationIgnored private var modules: Music3Modules?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    var selectedProject: Project? {
        guard let selectedID else { return nil }
        return projects.first { $0.id == selectedID }
    }

    func persist() {
        persistTask?.cancel()
        ProjectLibrary.save(projects)
    }

    func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            ProjectLibrary.save(projects)
        }
    }

    func task() async {
        if selectedID == nil {
            selectedID = projects.first?.id
        }
        let root = URL(fileURLWithPath: weightsPath)
        guard ModelDownload.isReady(at: root) else { return }
        await loadWeightsButtonTapped()
    }

    func newProjectButtonTapped() {
        let project = Project.blank()
        projects.insert(project, at: 0)
        selectedID = project.id
        persist()
        status = "New project"
    }

    func cloneProjectButtonTapped() {
        guard let selected = selectedProject else { return }
        let copy = selected.cloned()
        if let index = projects.firstIndex(where: { $0.id == selected.id }) {
            projects.insert(copy, at: index + 1)
        } else {
            projects.insert(copy, at: 0)
        }
        selectedID = copy.id
        persist()
        status = "Duplicated \(copy.displayTitle)"
    }

    func deleteProjectButtonTapped() {
        projectPendingDeletion = selectedID
    }

    func deleteConfirmationButtonTapped() {
        guard let id = projectPendingDeletion,
            let index = projects.firstIndex(where: { $0.id == id })
        else {
            projectPendingDeletion = nil
            return
        }
        let project = projects[index]
        let nextID =
            projects.indices.contains(index + 1)
            ? projects[index + 1].id
            : projects.dropLast().last?.id
        if selectedID == id {
            player?.stop()
        }
        selectedID = nextID
        projectPendingDeletion = nil
        ProjectLibrary.deleteFiles(for: project)
        projects.remove(at: index)
        persist()
        status = "Deleted \(project.displayTitle)"
    }

    func symbolPicked(_ symbol: String) {
        guard let project = selectedProject else { return }
        project.symbol = symbol
        project.updatedAt = Date()
        persist()
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
        guard let project = selectedProject else {
            status = "Pick a project first."
            return
        }
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
            let temp = FileManager.default.temporaryDirectory.appending(
                path: "minimax-\(Int(Date().timeIntervalSince1970)).wav")
            let out = try await generate(
                modules: modules,
                lyrics: project.lyrics,
                caption: project.caption,
                duration: Float(project.duration),
                steps: 30,
                seed: UInt64(max(0, project.seed)),
                output: temp
            ) { progress in
                Task { @MainActor in
                    self.pipelineProgress = progress
                    self.status = "\(progress.label) \(progress.completed)/\(progress.total)"
                }
            }
            try project.attach(wav: out)
            if project.title == "Untitled" {
                project.title = ProjectLibrary.title(from: project.lyrics)
            }
            persist()
            if let url = project.fileURL {
                try play(url: url)
            }
            status = "Saved \(project.displayTitle)"
        } catch {
            status = error.localizedDescription
        }
    }

    func folderPicked(_ url: URL) {
        weightsPath = url.path
        showingFolderPicker = false
        UserDefaults.standard.set(weightsPath, forKey: "weightsPath")
    }

    func playButtonTapped() {
        guard let project = selectedProject else {
            status = "This project has no audio yet."
            return
        }
        playButtonTapped(project)
    }

    func playButtonTapped(_ project: Project) {
        selectedID = project.id
        guard let url = project.fileURL, project.hasAudio else {
            status = "This project has no audio yet."
            return
        }
        do {
            try play(url: url)
            status = "Playing \(project.displayTitle)"
        } catch {
            status = error.localizedDescription
        }
    }

    func projectTapped(_ project: Project) {
        selectedID = project.id
    }

    private func play(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        player?.play()
    }

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
                let here = url.appending(path: "weights/\(name)")
                if ModelDownload.isReady(at: here) { return here.path }
                let sibling = url.appending(path: "minimusic/weights/\(name)")
                if ModelDownload.isReady(at: sibling) { return sibling.path }
            }
        }
        return ModelDownload.defaultDirectory
            .appending(path: "models/\(ModelDownload.repoID)")
            .path
    }
}
