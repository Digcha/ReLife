import Foundation

struct LeafyArchiveService {
    private let fileManager = FileManager.default
    private let directoryName = "LeafyArchive"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    func saveChat(for date: Date, messages: [LeafyMessage]) {
        guard let url = fileURL(for: date) else { return }
        createDirectoryIfNeeded()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    func loadChat(for date: Date) -> [LeafyMessage] {
        guard let url = fileURL(for: date), fileManager.fileExists(atPath: url.path) else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([LeafyMessage].self, from: data)) ?? []
    }

    func listArchivedDates() -> [Date] {
        guard let folder = archiveDirectoryURL() else { return [] }
        guard let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }

        return contents.compactMap { url -> Date? in
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("Leafy_") else { return nil }
            let dateString = name.replacingOccurrences(of: "Leafy_", with: "")
            return formatter.date(from: dateString)
        }
        .sorted(by: { $0 > $1 })
    }

    /// Clears the stored chat for a given date (used for "heute löschen").
    func clearChat(for date: Date) {
        guard let url = fileURL(for: date) else { return }
        createDirectoryIfNeeded()
        if let data = try? encoder.encode([LeafyMessage]()) {
            try? data.write(to: url, options: [.atomic])
        } else {
            try? fileManager.removeItem(at: url)
        }
    }

    private func fileURL(for date: Date) -> URL? {
        guard let directory = archiveDirectoryURL() else { return nil }
        let filename = "Leafy_\(formatter.string(from: date)).json"
        return directory.appendingPathComponent(filename)
    }

    private func archiveDirectoryURL() -> URL? {
        guard let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    private func createDirectoryIfNeeded() {
        guard let directory = archiveDirectoryURL() else { return }
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
