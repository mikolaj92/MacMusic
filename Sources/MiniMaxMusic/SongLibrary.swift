import Foundation

struct GeneratedSong: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var lyrics: String
    var caption: String
    var duration: Double
    var seed: Int
    var createdAt: Date
    var fileName: String

    var fileURL: URL {
        SongLibrary.root.appending(path: fileName)
    }
}

enum SongLibrary {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MiniMaxMusic/library")
    }

    static var indexURL: URL {
        root.appending(path: "library.json")
    }

    static func load() -> [GeneratedSong] {
        guard let data = try? Data(contentsOf: indexURL),
            let songs = try? JSONDecoder().decode([GeneratedSong].self, from: data)
        else { return [] }
        return songs.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    static func save(_ songs: [GeneratedSong]) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(songs)
        try? data?.write(to: indexURL, options: .atomic)
    }

    static func add(
        wav: URL,
        lyrics: String,
        caption: String,
        duration: Double,
        seed: Int
    ) throws -> GeneratedSong {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let id = UUID()
        let fileName = "\(id.uuidString).wav"
        let dest = root.appending(path: fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: wav, to: dest)
        let song = GeneratedSong(
            id: id,
            title: title(from: lyrics),
            lyrics: lyrics,
            caption: caption,
            duration: duration,
            seed: seed,
            createdAt: Date(),
            fileName: fileName
        )
        var songs = load()
        songs.insert(song, at: 0)
        save(songs)
        return song
    }

    static func delete(_ song: GeneratedSong) {
        try? FileManager.default.removeItem(at: song.fileURL)
        save(load().filter { $0.id != song.id })
    }

    static func title(from lyrics: String) -> String {
        let line = lyrics.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !($0.hasPrefix("[") && $0.hasSuffix("]")) }
        return line.map { String($0) } ?? "Untitled"
    }
}
