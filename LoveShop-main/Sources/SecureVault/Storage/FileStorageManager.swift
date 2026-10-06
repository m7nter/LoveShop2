import UIKit
import CoreLocation

struct PhotoMeta: Codable {
    let latitude: Double
    let longitude: Double
    let date: Date
    var note: String? = nil

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, date, note
    }

    init(latitude: Double, longitude: Double, date: Date, note: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

final class FileStorageManager {
    static let shared = FileStorageManager()
    private let folderName = "VaultPhotos"

    private var vaultDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(folderName)
    }

    private init() {
        try? FileManager.default.createDirectory(at: vaultDirectory,
                                                  withIntermediateDirectories: true)
    }

    /// Сохраняет фото в зашифрованном виде (AES-256-GCM). На диске лежит
    /// не валидный JPEG, а шифротекст — открыть файл напрямую (например,
    /// через сторонний файловый менеджер) без ключа из Keychain невозможно.
    func save(image: UIImage, location: CLLocation? = nil) -> URL? {
        guard let jpeg = image.jpegData(compressionQuality: 0.92),
              let encrypted = CryptoManager.encrypt(jpeg) else { return nil }
        let name = UUID().uuidString
        let url = vaultDirectory.appendingPathComponent("\(name).jpg")
        try? encrypted.write(to: url)

        if let loc = location {
            let meta = PhotoMeta(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                date: Date()
            )
            saveMeta(meta, for: url)
        }

        return url
    }

    func loadAll() -> [URL] {
        let files = try? FileManager.default.contentsOfDirectory(
            at: vaultDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        return (files ?? [])
            .filter { $0.pathExtension == "jpg" }
            .sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 > d2
            }
    }

    /// Возвращает расшифрованное изображение по URL зашифрованного файла.
    func loadImage(at url: URL) -> UIImage? {
        guard let data = decryptedData(for: url) else { return nil }
        return UIImage(data: data)
    }

    /// Возвращает расшифрованные сырые байты JPEG (используется при экспорте).
    /// Если файл был сохранён ДО включения шифрования (старые данные),
    /// расшифровка не удастся — в этом случае пробуем прочитать
    /// файл как обычный незашифрованный JPEG, чтобы не потерять
    /// уже снятые фото.
    func decryptedData(for url: URL) -> Data? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        if let decrypted = CryptoManager.decrypt(raw) {
            return decrypted
        }
        // Старый незашифрованный файл — отдаём как есть.
        return raw
    }

    func loadMeta(for url: URL) -> PhotoMeta? {
        let name = url.deletingPathExtension().lastPathComponent
        let metaURL = vaultDirectory.appendingPathComponent("\(name).json")
        guard let raw = try? Data(contentsOf: metaURL) else { return nil }
        let plain = CryptoManager.decrypt(raw) ?? raw
        return try? JSONDecoder().decode(PhotoMeta.self, from: plain)
    }

    private func saveMeta(_ meta: PhotoMeta, for url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let metaURL = vaultDirectory.appendingPathComponent("\(name).json")
        guard let data = try? JSONEncoder().encode(meta),
              let encrypted = CryptoManager.encrypt(data) else { return }
        try? encrypted.write(to: metaURL)
    }

    func loadAllWithMeta() -> [(URL, PhotoMeta?)] {
        return loadAll().map { ($0, loadMeta(for: $0)) }
    }

    func lastPhotoLocation() -> CLLocation? {
        guard let (_, meta) = loadAllWithMeta().first, let m = meta else { return nil }
        return CLLocation(latitude: m.latitude, longitude: m.longitude)
    }

    /// Перезаписывает уже отредактированное фото (та же шифрованная схема).
    func overwrite(image: UIImage, at url: URL) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85),
              let encrypted = CryptoManager.encrypt(jpeg) else { return }
        try? encrypted.write(to: url)
    }

    func updateNote(for url: URL, note: String) {
        var meta = loadMeta(for: url) ?? PhotoMeta(latitude: 0, longitude: 0, date: Date())
        meta.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        saveMeta(meta, for: url)
    }

    func delete(url: URL) {
        try? FileManager.default.removeItem(at: url)
        let name = url.deletingPathExtension().lastPathComponent
        let metaURL = vaultDirectory.appendingPathComponent("\(name).json")
        try? FileManager.default.removeItem(at: metaURL)
    }
}
