import SwiftUI

struct PhotoDetailView: View {
    let urls: [URL]
    let initialIndex: Int
    let onDelete: (URL) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var showNoteEditor = false
    @State private var noteText: String = ""
    @State private var refreshToken = UUID()

    init(urls: [URL], initialIndex: Int, onDelete: @escaping (URL) -> Void) {
        self.urls = urls
        self.initialIndex = initialIndex
        self.onDelete = onDelete
        self._currentIndex = State(initialValue: initialIndex)
    }

    private var currentURL: URL {
        urls[min(max(currentIndex, 0), urls.count - 1)]
    }

    private var hasNote: Bool {
        !(FileStorageManager.shared.loadMeta(for: currentURL)?.note ?? "").isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    PhotoPageView(url: url, refreshToken: refreshToken)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    Spacer()
                    if urls.count > 1 {
                        Text("\(currentIndex + 1) из \(urls.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            noteText = FileStorageManager.shared.loadMeta(for: currentURL)?.note ?? ""
                            showNoteEditor = true
                        } label: {
                            Image(systemName: hasNote ? "note.text" : "note")
                                .foregroundColor(hasNote ? .orange : .white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Button { showEditor = true } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                if hasNote {
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(FileStorageManager.shared.loadMeta(for: currentURL)?.note ?? "")
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Spacer()
            }
            .allowsHitTesting(true)
        }
        .sheet(isPresented: $showEditor) {
            if let img = FileStorageManager.shared.loadImage(at: currentURL) {
                GalleryEditorView(image: img, url: currentURL) { _ in
                    refreshToken = UUID()
                }
            }
        }
        .sheet(isPresented: $showNoteEditor) {
            PhotoNoteEditorView(text: noteText) { newText in
                FileStorageManager.shared.updateNote(for: currentURL, note: newText)
            }
        }
        .alert("Удалить фото?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                let deletingURL = currentURL
                onDelete(deletingURL)
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }
}

private struct PhotoPageView: View {
    let url: URL
    let refreshToken: UUID
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.black
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { load() }
        .onChange(of: refreshToken) { _ in load() }
    }

    private func load() {
        image = FileStorageManager.shared.loadImage(at: url)
    }
}

struct PhotoNoteEditorView: View {
    let text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var noteText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Заметка к фото") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        onSave(noteText)
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .onAppear { noteText = text }
    }
}
