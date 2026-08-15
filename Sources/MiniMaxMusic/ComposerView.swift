import MiniMaxMusic3MLX
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Bindable var model: ComposerModel

    var body: some View {
        ZStack {
            Theme.backdrop
            HStack(alignment: .top, spacing: 16) {
                libraryColumn
                lyricsColumn
                inspectorColumn
            }
            .padding(20)
        }
        .background(WindowChrome())
        .frame(minWidth: 1080, minHeight: 680)
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

    private var libraryColumn: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                columnLabel("Library", systemImage: "music.note.list")
                if model.songs.isEmpty {
                    Spacer(minLength: 24)
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.ultramarine.opacity(0.8))
                        Text("Nothing here yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.songs) { song in
                                songRow(song)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)
    }

    private var lyricsColumn: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                columnLabel("Lyrics", systemImage: "text.quote")
                Text("Keep [verse] and [chorus] on their own line.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $model.lyrics)
                    .font(.system(.title3, design: .serif))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Theme.mist)
                    .lineSpacing(6)
            }
        }
        .frame(minWidth: 380)
    }

    private var inspectorColumn: some View {
        VStack(spacing: 16) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    columnLabel("Caption", systemImage: "sparkles")
                    TextEditor(text: $model.caption)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Theme.mist)
                        .frame(minHeight: 92)
                }
            }
            .frame(minHeight: 180)

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    columnLabel("Generate", systemImage: "waveform.circle")
                    HStack(spacing: 12) {
                        Text("\(Int(model.durationSeconds)) s")
                            .font(.system(.title2, design: .rounded).weight(.medium))
                            .monospacedDigit()
                            .frame(width: 64, alignment: .leading)
                        Slider(value: $model.durationSeconds, in: 4...90, step: 1)
                            .tint(Theme.ultramarine)
                    }
                    HStack {
                        Text("Seed")
                            .foregroundStyle(.secondary)
                        TextField("Seed", value: $model.seed, format: .number)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .rect(cornerRadius: 10, style: .continuous))
                    }
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
                    Text(model.status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button {
                        Task { await model.generateButtonTapped() }
                    } label: {
                        Label("Generate Song", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Theme.ultramarine)
                    .disabled(model.isWorking || !model.engineReady)
                }
            }

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        columnLabel("Weights", systemImage: "externaldrive")
                        Spacer()
                        Text(model.engineReady ? "Ready" : "Not loaded")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(model.engineReady ? Theme.ultramarine : .secondary)
                            .glassEffect(.regular, in: .capsule)
                    }
                    TextField("Converted MLX folder", text: $model.weightsPath)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .padding(10)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12, style: .continuous))
                    HStack(spacing: 8) {
                        Button("Choose…") { model.showingFolderPicker = true }
                        Button("Load") { Task { await model.loadWeightsButtonTapped() } }
                            .disabled(model.isWorking || model.weightsPath.isEmpty)
                        Button("Download 4-bit") { Task { await model.downloadWeightsButtonTapped() } }
                            .disabled(model.isWorking)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
    }

    private func songRow(_ song: GeneratedSong) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(song.title)
                .font(.headline)
                .lineLimit(2)
            Text("\(Int(song.duration)) s · \(song.createdAt, format: .dateTime.month().day().hour().minute())")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Button("Play") { model.playButtonTapped(song) }
                ShareLink(item: song.fileURL) {
                    Text("Share")
                }
                Button("Reuse") { model.reuseButtonTapped(song) }
                Spacer()
                Button("Delete", role: .destructive) { model.deleteButtonTapped(song) }
            }
            .buttonStyle(.glass)
            .controlSize(.mini)
            .disabled(model.isWorking)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(model.lastSongID == song.id ? Theme.ultramarine : .clear),
            in: .rect(cornerRadius: 16, style: .continuous)
        )
    }

    private func columnLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    private func labeledBar(_ title: String, value: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(Theme.ultramarine)
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
