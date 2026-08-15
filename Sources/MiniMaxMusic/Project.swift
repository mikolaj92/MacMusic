import Foundation

struct Project: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var lyrics: String
    var caption: String
    var duration: Double
    var seed: Int
    var symbol: String
    var createdAt: Date
    var updatedAt: Date
    var fileName: String?

    var fileURL: URL? {
        fileName.map { ProjectLibrary.root.appending(path: $0) }
    }

    var hasAudio: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != "Untitled" { return trimmed }
        return ProjectLibrary.title(from: lyrics)
    }

    static func blank() -> Project {
        let now = Date()
        return Project(
            id: UUID(),
            title: "Untitled",
            lyrics: "",
            caption: "",
            duration: 30,
            seed: Int.random(in: 1...999_999),
            symbol: Project.symbols[0],
            createdAt: now,
            updatedAt: now,
            fileName: nil
        )
    }

    func cloned() -> Project {
        var copy = self
        copy.id = UUID()
        copy.title = "\(displayTitle) copy"
        copy.createdAt = Date()
        copy.updatedAt = copy.createdAt
        if let fileName, hasAudio {
            let newName = "\(copy.id.uuidString).wav"
            let dest = ProjectLibrary.root.appending(path: newName)
            try? FileManager.default.copyItem(at: ProjectLibrary.root.appending(path: fileName), to: dest)
            copy.fileName = newName
        } else {
            copy.fileName = nil
        }
        return copy
    }

    static let symbols = [
        "music.note",
        "music.note.list",
        "waveform",
        "mic.fill",
        "headphones",
        "hifispeaker.fill",
        "metronome.fill",
        "pianokeys",
        "guitars.fill",
        "music.quarternote.3",
        "sparkles",
        "lighthouse.fill",
    ]
}

enum ProjectLibrary {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MiniMaxMusic/library")
    }

    static var indexURL: URL {
        root.appending(path: "library.json")
    }

    static func load() -> [Project] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        if let projects = try? JSONDecoder().decode([Project].self, from: data) {
            return projects
        }
        if let songs = try? JSONDecoder().decode([LegacySong].self, from: data) {
            return songs.map(\.project)
        }
        return []
    }

    static func save(_ projects: [Project]) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(projects)
        try? data?.write(to: indexURL, options: .atomic)
    }

    static func attach(wav: URL, to project: inout Project) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileName = "\(project.id.uuidString).wav"
        let dest = root.appending(path: fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: wav, to: dest)
        project.fileName = fileName
        project.updatedAt = Date()
    }

    static func deleteFiles(for project: Project) {
        if let fileURL = project.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    static func title(from lyrics: String) -> String {
        let line = lyrics.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !($0.hasPrefix("[") && $0.hasSuffix("]")) }
        return line.map { String($0) } ?? "Untitled"
    }
}

private struct LegacySong: Codable {
    var id: UUID
    var title: String
    var lyrics: String
    var caption: String
    var duration: Double
    var seed: Int
    var createdAt: Date
    var fileName: String

    var project: Project {
        Project(
            id: id,
            title: title,
            lyrics: lyrics,
            caption: caption,
            duration: duration,
            seed: seed,
            symbol: "music.note",
            createdAt: createdAt,
            updatedAt: createdAt,
            fileName: fileName
        )
    }
}

extension Array where Element: Identifiable {
    subscript(id id: Element.ID) -> Element? {
        get { first { $0.id == id } }
        set {
            guard let index = firstIndex(where: { $0.id == id }) else { return }
            if let newValue {
                self[index] = newValue
            }
        }
    }
}
