import Foundation

struct Note: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var isPinned: Bool = false
}

final class NotesManager {
    static let shared = NotesManager()
    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("VaultNotes")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("notes.json")
    }

    /// Заметки (в том числе пароли) хранятся на диске в зашифрованном виде.
    /// Если файл был создан ДО включения шифрования, пробуем прочитать
    /// его как обычный JSON, чтобы не потерять старые заметки.
    func loadAll() -> [Note] {
        guard let raw = try? Data(contentsOf: fileURL) else { return [] }
        let plain = CryptoManager.decrypt(raw) ?? raw
        return (try? JSONDecoder().decode([Note].self, from: plain)) ?? []
    }

    private func saveAll(_ notes: [Note]) {
        guard let data = try? JSONEncoder().encode(notes),
              let encrypted = CryptoManager.encrypt(data) else { return }
        try? encrypted.write(to: fileURL)
    }

    func add(title: String, content: String) {
        var notes = loadAll()
        let note = Note(id: UUID(), title: title, content: content,
                         createdDate: Date(), modifiedDate: Date())
        notes.insert(note, at: 0)
        saveAll(notes)
    }

    func update(_ note: Note) {
        var notes = loadAll()
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            var updated = note
            updated.modifiedDate = Date()
            notes[idx] = updated
            saveAll(notes)
        }
    }

    func togglePin(_ note: Note) {
        var notes = loadAll()
        if let idx = notes.firstIndex(where: { $0.id == note.id }) {
            notes[idx].isPinned.toggle()
            saveAll(notes)
        }
    }

    func delete(_ note: Note) {
        var notes = loadAll()
        notes.removeAll { $0.id == note.id }
        saveAll(notes)
    }
}
