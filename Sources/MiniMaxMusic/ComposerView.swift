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
        List(selection: $model.selectedID) {
            ForEach(model.projects) { project in
                NavigationLink(value: project.id) {
                    projectRow(project)
                }
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

    private var detail: some View {
        Group {
            if let id = model.selectedID, model.projects[id: id] != nil {
                ProjectEditor(projectID: id, model: model)
                    .id(id)
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "music.note",
                    description: Text("Or create one from the sidebar.")
                )
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
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

struct ProjectEditor: View {
    let projectID: Project.ID
    @Bindable var model: ComposerModel

    var body: some View {
        if let index = model.projects.firstIndex(where: { $0.id == projectID }) {
            editor($model.projects[index])
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "music.note",
                description: Text("Or create one from the sidebar.")
            )
        }
    }

    private func editor(_ project: Binding<Project>) -> some View {
        VStack(spacing: 0) {
            TextField("Title", text: project.title)
                .font(.largeTitle.weight(.semibold))
                .textFieldStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 8)
            TextEditor(text: project.lyrics)
                .font(.system(.title3, design: .serif))
                .scrollContentBackground(.hidden)
                .lineSpacing(6)
                .padding(.horizontal, 20)
            Divider().opacity(0.4)
            VStack(alignment: .leading, spacing: 6) {
                Label("Caption", systemImage: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: project.caption)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 120)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            generateBar(project)
        }
        .navigationTitle(project.wrappedValue.displayTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    Button("Play", systemImage: "play.fill") {
                        model.playButtonTapped()
                    }
                    .disabled(!project.wrappedValue.hasAudio)
                    if let url = project.wrappedValue.fileURL, project.wrappedValue.hasAudio {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Share", systemImage: "square.and.arrow.up") {}
                            .disabled(true)
                    }
                }
                Menu("Symbol", systemImage: project.wrappedValue.symbol) {
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
    }

    private func generateBar(_ project: Binding<Project>) -> some View {
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
                    Slider(value: project.duration, in: 4...90, step: 1)
                        .frame(maxWidth: 180)
                    Text("\(Int(project.wrappedValue.duration)) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                } icon: {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                }
                Label {
                    TextField("Seed", value: project.seed, format: .number)
                        .textFieldStyle(.plain)
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
                        project.wrappedValue.hasAudio ? "Regenerate" : "Generate",
                        systemImage: project.wrappedValue.hasAudio ? "arrow.clockwise" : "waveform"
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
