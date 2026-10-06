import Foundation
import ZIPFoundation

struct ZipExporter {
    static func exportDay(label: String, urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }

        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

            var metadataLines: [String] = []
            metadataLines.append("Экспорт фото — \(label)")
            metadataLines.append("Всего снимков: \(urls.count)")
            metadataLines.append("")

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ru_RU")
            dateFormatter.dateFormat = "d MMMM yyyy, HH:mm:ss"

            for url in urls {
                let destURL = workDir.appendingPathComponent(url.lastPathComponent)
                if let decrypted = FileStorageManager.shared.decryptedData(for: url) {
                    try? decrypted.write(to: destURL)
                }

                if let meta = FileStorageManager.shared.loadMeta(for: url) {
                    let dateStr = dateFormatter.string(from: meta.date)
                    metadataLines.append("""
                    Файл: \(url.lastPathComponent)
                    Координаты: \(String(format: "%.6f, %.6f", meta.latitude, meta.longitude))
                    Карта: https://maps.google.com/?q=\(meta.latitude),\(meta.longitude)
                    Дата съёмки: \(dateStr)

                    """)
                } else {
                    metadataLines.append("""
                    Файл: \(url.lastPathComponent)
                    Координаты: нет данных

                    """)
                }
            }

            let metaFileURL = workDir.appendingPathComponent("metadata.txt")
            try metadataLines.joined(separator: "\n")
                .write(to: metaFileURL, atomically: true, encoding: .utf8)

            let safeLabel = label.replacingOccurrences(of: "/", with: "-")
            let zipURL = fm.temporaryDirectory.appendingPathComponent("\(safeLabel).zip")
            if fm.fileExists(atPath: zipURL.path) {
                try fm.removeItem(at: zipURL)
            }

            let archive = try Archive(url: zipURL, accessMode: .create)
            let contents = try fm.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try archive.addEntry(with: fileURL.lastPathComponent, relativeTo: workDir)
            }

            try? fm.removeItem(at: workDir)
            return zipURL
        } catch {
            try? fm.removeItem(at: workDir)
            return nil
        }
    }
}
