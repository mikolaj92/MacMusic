import MiniMaxMusic3MLX
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Bindable var model: ComposerModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.ultramarine)
        .frame(minWidth: 980, minHeight: 640)
        .confirmationDialog(
            "Delete this project?",
            isPresented: $model.projectPendingDeletion.isPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                model.deleteConfirmationButtonTapped()
            }
        } message: {
            Text("The lyrics stay gone. Audio is removed if it exists.")
        }
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

    private var sidebar: some View {
        List {
            ForEach(model.projects) { project in
                Button {
                    model.projectTapped(project)
                } label: {
                    ProjectRow(project: project)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    model.selectedID == project.id
                        ? Theme.ultramarine.opacity(0.14)
                        : Color.clear
                )
                .contextMenu {
                    Button("Play", systemImage: "play.fill") {
                        model.playButtonTapped(project)
                    }
                    .disabled(!project.hasAudio)
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        model.projectTapped(project)
                        model.cloneProjectButtonTapped()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        model.projectTapped(project)
                        model.deleteProjectButtonTapped()
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Latarnia")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .overlay {
            if model.projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "music.note.list",
                    description: Text("Start a draft. Generate when it feels ready.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Project", systemImage: "square.and.pencil") {
                    model.newProjectButtonTapped()
                }
                .help("New Project")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let project = model.selectedProject {
            ProjectEditor(project: project, model: model)
                .id(project.id)
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "music.note",
                description: Text("Or create one from the sidebar.")
            )
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

struct ProjectRow: View {
    var project: Project

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayTitle)
                    .lineLimit(1)
                Text(project.hasAudio ? "\(Int(project.duration)) s" : "Draft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: project.symbol)
                .foregroundStyle(Theme.ultramarine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct ProjectEditor: View {
    @Bindable var project: Project
    var model: ComposerModel
    @FocusState private var field: Field?

    private enum Field: Hashable {
        case title, lyrics, caption, seed
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $project.title)
                .font(.largeTitle.weight(.semibold))
                .textFieldStyle(.plain)
                .focused($field, equals: .title)
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 8)
            TextEditor(text: $project.lyrics)
                .font(.system(.title3, design: .serif))
                .scrollContentBackground(.hidden)
                .lineSpacing(6)
                .focused($field, equals: .lyrics)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .topLeading) {
                    if project.lyrics.isEmpty && field != .lyrics {
                        Text("Write the song here")
                            .font(.system(.title3, design: .serif))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 25)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 6) {
                Label("Caption", systemImage: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $project.caption)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($field, equals: .caption)
                    .frame(minHeight: 72, maxHeight: 120)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            generateBar
        }
        .navigationTitle(project.title == "Untitled" ? "Untitled" : project.displayTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    Button("Play", systemImage: "play.fill") {
                        model.playButtonTapped(project)
                    }
                    .disabled(!project.hasAudio)
                    if let url = project.fileURL, project.hasAudio {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Share", systemImage: "square.and.arrow.up") {}
                            .disabled(true)
                    }
                }
                Menu("Symbol", systemImage: project.symbol) {
                    ForEach(Project.symbols, id: \.self) { symbol in
                        Button(symbol, systemImage: symbol) {
                            model.symbolPicked(symbol)
                        }
                    }
                }
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    model.cloneProjectButtonTapped()
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    model.deleteProjectButtonTapped()
                }
            }
        }
        .defaultFocus($field, .lyrics)
        .task {
            try? await Task.sleep(for: .milliseconds(80))
            field = .lyrics
        }
        .onChange(of: project.title) { model.schedulePersist() }
        .onChange(of: project.lyrics) { model.schedulePersist() }
        .onChange(of: project.caption) { model.schedulePersist() }
        .onChange(of: project.duration) { model.schedulePersist() }
        .onChange(of: project.seed) { model.schedulePersist() }
    }

    private var generateBar: some View {
        VStack(spacing: 10) {
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
            HStack(spacing: 16) {
                Label {
                    Slider(value: $project.duration, in: 4...90, step: 1)
                        .frame(maxWidth: 180)
                    Text("\(Int(project.duration)) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                } icon: {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                }
                Label {
                    TextField("Seed", value: $project.seed, format: .number)
                        .textFieldStyle(.plain)
                        .focused($field, equals: .seed)
                        .frame(width: 72)
                } icon: {
                    Image(systemName: "dice")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.generateButtonTapped() }
                } label: {
                    Label(
                        project.hasAudio ? "Regenerate" : "Generate",
                        systemImage: project.hasAudio ? "arrow.clockwise" : "waveform"
                    )
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.ultramarine)
                .disabled(model.isWorking || !model.engineReady)
            }
            HStack {
                Image(systemName: model.engineReady ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(model.engineReady ? Theme.ultramarine : .secondary)
                Text(model.status)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .font(.caption)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
        .padding(12)
    }

    private func labeledBar(_ title: String, value: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(detail)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            ProgressView(value: min(max(value, 0), 1))
                .tint(Theme.ultramarine)
        }
    }
}

extension Optional {
    var isPresented: Bool {
        get { self != nil }
        set {
            guard !newValue else { return }
            self = nil
        }
    }
}
