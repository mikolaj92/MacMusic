import MiniMaxMusic3MLX
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Bindable var model: ComposerModel

    var body: some View {
        HSplitView {
            lyricsPane
            controlsPane
        }
        .frame(minWidth: 980, minHeight: 640)
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $model.showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            folderImportFinished(result)
        }
        .task {
            await model.task()
        }
    }

    private var lyricsPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lyrics")
                .font(.headline)
            Text("Keep tags such as [verse] and [chorus] on their own line.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $model.lyrics)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(20)
        .frame(minWidth: 420)
    }

    private var controlsPane: some View {
        Form {
            Section("Caption") {
                TextEditor(text: $model.caption)
                    .font(.body)
                    .frame(minHeight: 88)
            }
            Section("Generation") {
                HStack {
                    Text("Duration")
                    Slider(value: $model.durationSeconds, in: 4...90, step: 1)
                    TextField(
                        "s",
                        value: $model.durationSeconds,
                        format: .number.precision(.fractionLength(0))
                    )
                    .frame(width: 44)
                    Text("s")
                        .foregroundStyle(.secondary)
                }
                TextField("Seed", value: $model.seed, format: .number)
            }
            Section("MiniMax-Music3 weights") {
                TextField("Converted MLX folder", text: $model.weightsPath)
                HStack {
                    Button("Choose Folder…") { model.showingFolderPicker = true }
                    Button("Load") { Task { await model.loadWeightsButtonTapped() } }
                        .disabled(model.isWorking || model.weightsPath.isEmpty)
                    Button("Download 4-bit") { Task { await model.downloadWeightsButtonTapped() } }
                        .disabled(model.isWorking)
                }
                Text(model.engineReady ? "MiniMax-Music3 ready" : "Engine not loaded")
                    .foregroundStyle(model.engineReady ? .green : .secondary)
            }
            Section("Progress") {
                if let progress = model.downloadProgress {
                    labeledBar("Download", value: progress, detail: "\(Int(progress * 100))%")
                }
                if let progress = model.pipelineProgress {
                    labeledBar(
                        progress.label,
                        value: progress.fraction,
                        detail: "\(progress.completed)/\(progress.total)"
                    )
                }
                if !model.isWorking, model.downloadProgress == nil, model.pipelineProgress == nil {
                    Text("Idle")
                        .foregroundStyle(.secondary)
                }
                Text(model.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Section {
                Button("Generate Song") { Task { await model.generateButtonTapped() } }
                    .disabled(model.isWorking || !model.engineReady)
            }
            Section("Library") {
                if model.songs.isEmpty {
                    Text("No songs yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.songs) { song in
                        songRow(song)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, idealWidth: 460)
    }

    private func songRow(_ song: GeneratedSong) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.headline)
                    Text("\(Int(song.duration)) s · seed \(song.seed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(song.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            HStack {
                Button("Play") { model.playButtonTapped(song) }
                ShareLink(item: song.fileURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button("Reuse") { model.reuseButtonTapped(song) }
                Spacer()
                Button("Delete", role: .destructive) { model.deleteButtonTapped(song) }
            }
            .disabled(model.isWorking)
        }
        .padding(.vertical, 4)
    }

    private func labeledBar(_ title: String, value: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(detail)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1))
        }
    }

    private func folderImportFinished(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            model.folderPicked(url)
            Task {
                await model.loadWeightsButtonTapped()
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            model.status = error.localizedDescription
        }
    }
}
