import SwiftUI

struct GalleryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var groupedPhotos: [(String, [URL])] = []
    @State private var selectedURL: URL?
    @State private var showSettings = false
    @State private var sharingItems: [Any] = []
    @State private var showShareSheet = false
    @State private var isExporting = false
    @State private var isSelecting = false
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirm = false
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    private var totalCount: Int {
        groupedPhotos.reduce(0) { $0 + $1.1.count }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedPhotos, id: \.0) { day, urls in
                            Section {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(urls, id: \.self) { url in
                                        ThumbnailCell(
                                            url: url,
                                            isSelecting: isSelecting,
                                            isSelected: selectedURLs.contains(url)
                                        )
                                        .onTapGesture {
                                            if isSelecting {
                                                toggleSelection(url)
                                            } else {
                                                selectedURL = url
                                            }
                                        }
                                    }
                                }
                                .padding(.bottom, 8)
                            } header: {
                                HStack {
                                    Text("\(day) — \(urls.count) фото")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if !isSelecting {
                                        Button {
                                            shareDay(day: day, urls: urls)
                                        } label: {
                                            if isExporting {
                                                ProgressView()
                                                    .tint(.orange)
                                            } else {
                                                Image(systemName: "square.and.arrow.up")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        .disabled(isExporting)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.85))
                            }
                        }
                    }
                    .padding(.bottom, isSelecting ? 70 : 0)
                }
                .background(Color.black)

                if isSelecting {
                    HStack(spacing: 24) {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Удалить")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(selectedURLs.isEmpty ? .gray : .red)
                        .disabled(selectedURLs.isEmpty)

                        Spacer()

                        Text("\(selectedURLs.count) выбрано")
                            .font(.subheadline)
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            shareSelected()
                        } label: {
                            if isExporting {
                                ProgressView().tint(.orange)
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Поделиться")
                                        .font(.caption)
                                }
                            }
                        }
                        .foregroundColor(selectedURLs.isEmpty ? .gray : .orange)
                        .disabled(selectedURLs.isEmpty || isExporting)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.95))
                }
            }
            .navigationTitle(totalCount > 0 ? "Галерея (\(totalCount))" : "Галерея")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting {
                        Button("Отмена") { exitSelection() }
                            .foregroundColor(.orange)
                    } else {
                        Button("Закрыть") { dismiss() }
                            .foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            if isSelecting {
                                exitSelection()
                            } else {
                                isSelecting = true
                            }
                        } label: {
                            Text(isSelecting ? "Готово" : "Выбрать")
                                .foregroundColor(.orange)
                        }
                        if !isSelecting {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { reload() }
        .sheet(item: $selectedURL) { url in
            let flat = groupedPhotos.flatMap { $0.1 }
            let idx = flat.firstIndex(of: url) ?? 0
            PhotoDetailView(urls: flat, initialIndex: idx) { deletedURL in
                delete(url: deletedURL)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: sharingItems)
        }
        .alert(
            "Удалить \(selectedURLs.count) фото?",
            isPresented: $showDeleteConfirm
        ) {
            Button("Удалить", role: .destructive) { deleteSelected() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func toggleSelection(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    private func exitSelection() {
        isSelecting = false
        selectedURLs.removeAll()
    }

    private func deleteSelected() {
        for url in selectedURLs {
            FileStorageManager.shared.delete(url: url)
        }
        exitSelection()
        reload()
    }

    private func shareSelected() {
        let urls = Array(selectedURLs)
        guard !urls.isEmpty, !isExporting else { return }

        guard SettingsStore.shared.exportAsZip else {
            isExporting = true
            DispatchQueue.global(qos: .userInitiated).async {
                let plainURLs = decryptedTempCopies(of: urls)
                DispatchQueue.main.async {
                    isExporting = false
                    guard !plainURLs.isEmpty else { return }
                    sharingItems = plainURLs
                    showShareSheet = true
                }
            }
            return
        }

        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let zipURL = ZipExporter.exportDay(label: "Выбранные фото", urls: urls)
            DispatchQueue.main.async {
                isExporting = false
                if let zipURL = zipURL {
                    sharingItems = [zipURL]
                    showShareSheet = true
                }
            }
        }
    }

    private func shareDay(day: String, urls: [URL]) {
        guard !urls.isEmpty, !isExporting else { return }

        guard SettingsStore.shared.exportAsZip else {
            isExporting = true
            DispatchQueue.global(qos: .userInitiated).async {
                let plainURLs = decryptedTempCopies(of: urls)
                DispatchQueue.main.async {
                    isExporting = false
                    guard !plainURLs.isEmpty else { return }
                    sharingItems = plainURLs
                    showShareSheet = true
                }
            }
            return
        }

        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let zipURL = ZipExporter.exportDay(label: day, urls: urls)
            DispatchQueue.main.async {
                isExporting = false
                if let zipURL = zipURL {
                    sharingItems = [zipURL]
                    showShareSheet = true
                }
            }
        }
    }

    /// Файлы в хранилище зашифрованы — для "отдельными файлами" шарим
    /// заранее расшифрованные временные копии, иначе получатель увидит
    /// нечитаемый шифротекст вместо фото.
    private func decryptedTempCopies(of urls: [URL]) -> [URL] {
        let tmpDir = FileManager.default.temporaryDirectory
        var result: [URL] = []
        for url in urls {
            guard let data = FileStorageManager.shared.decryptedData(for: url) else { continue }
            let dest = tmpDir.appendingPathComponent(url.lastPathComponent)
            try? data.write(to: dest)
            result.append(dest)
        }
        return result
    }

    private func reload() {
        let urls = FileStorageManager.shared.loadAll()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"

        var dict: [String: [URL]] = [:]
        var order: [String] = []

        for url in urls {
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            let key = formatter.string(from: date)
            if dict[key] == nil {
                dict[key] = []
                order.append(key)
            }
            dict[key]?.append(url)
        }

        groupedPhotos = order.map { ($0, dict[$0] ?? []) }
    }

    private func delete(url: URL) {
        FileStorageManager.shared.delete(url: url)
        reload()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable { public var id: String { absoluteString } }

struct ThumbnailCell: View {
    let url: URL
    var isSelecting: Bool = false
    var isSelected: Bool = false
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .clipped()
                    .opacity(isSelecting && !isSelected ? 0.55 : 1.0)
            } else {
                Color.gray.opacity(0.15)
                    .frame(width: 110, height: 110)
            }
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .orange : .white)
                    .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 22, height: 22))
                    .padding(6)
            }
        }
        .onAppear {
            if image == nil {
                image = FileStorageManager.shared.loadImage(at: url)
            }
        }
    }
}
