import Foundation
import Observation

struct ProjectRecord: Codable, Sendable {
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
}

@Observable
final class Project: Identifiable {
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

    var record: ProjectRecord {
        ProjectRecord(
            id: id,
            title: title,
            lyrics: lyrics,
            caption: caption,
            duration: duration,
            seed: seed,
            symbol: symbol,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fileName: fileName
        )
    }

    init(record: ProjectRecord) {
        id = record.id
        title = record.title
        lyrics = record.lyrics
        caption = record.caption
        duration = record.duration
        seed = record.seed
        symbol = record.symbol
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        fileName = record.fileName
    }

    static func blank() -> Project {
        let now = Date()
        return Project(
            record: ProjectRecord(
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
        )
    }

    func cloned() -> Project {
        let now = Date()
        let copy = Project(
            record: ProjectRecord(
                id: UUID(),
                title: "\(displayTitle) copy",
                lyrics: lyrics,
                caption: caption,
                duration: duration,
                seed: seed,
                symbol: symbol,
                createdAt: now,
                updatedAt: now,
                fileName: nil
            )
        )
        if let fileName, hasAudio {
            let newName = "\(copy.id.uuidString).wav"
            let dest = ProjectLibrary.root.appending(path: newName)
            try? FileManager.default.copyItem(
                at: ProjectLibrary.root.appending(path: fileName),
                to: dest
            )
            copy.fileName = newName
        }
        return copy
    }

    func attach(wav: URL) throws {
        try FileManager.default.createDirectory(
            at: ProjectLibrary.root,
            withIntermediateDirectories: true
        )
        let name = "\(id.uuidString).wav"
        let dest = ProjectLibrary.root.appending(path: name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: wav, to: dest)
        fileName = name
        updatedAt = Date()
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
        if let records = try? JSONDecoder().decode([ProjectRecord].self, from: data) {
            return records.map(Project.init(record:))
        }
        if let songs = try? JSONDecoder().decode([LegacySong].self, from: data) {
            return songs.map { Project(record: $0.record) }
        }
        return []
    }

    static func save(_ projects: [Project]) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(projects.map(\.record))
        try? data?.write(to: indexURL, options: .atomic)
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

    var record: ProjectRecord {
        ProjectRecord(
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
