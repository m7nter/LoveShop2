import SwiftUI
import AVFoundation
import CoreLocation

struct VaultView: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var capturedLocation: CLLocation?
    @State private var capturedHeading: CLHeading?
    @State private var showEditor = false
    @State private var showGallery = false
    @State private var showVaultLock = false
    @State private var showMap = false
    @State private var showNotes = false
    @State private var pendingDestination: VaultDestination?
    @StateObject private var cameraVM = CameraViewModel()
    @State private var openedViaURL = false

    var onLock: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1C1C1E").ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)

                    Text("Хранилище")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    HStack(spacing: 16) {
                        VaultActionButton(icon: "camera.fill", label: "Камера") {
                            showCamera = true
                        }
                        VaultActionButton(icon: "photo.on.rectangle", label: "Галерея") {
                            requestAccess(to: .gallery)
                        }
                    }

                    HStack(spacing: 16) {
                        VaultActionButton(icon: "map.fill", label: "Карта меток") {
                            showMap = true
                        }
                        VaultActionButton(icon: "note.text", label: "Дневник") {
                            requestAccess(to: .notes)
                        }
                    }

                    Button {
                        onLock()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Калькулятор")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            locationManager.requestAndStart()
            cameraVM.startSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCameraFromURL)) { _ in
            openedViaURL = true
            showCamera = true
        }
        .onDisappear { cameraVM.stopSession() }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if openedViaURL {
                openedViaURL = false
                onLock()
            }
        }) {
            CameraScreen(cameraVM: cameraVM) { img, loc, hdg in
                showCamera = false
                if cameraVM.quickMode {
                    let label = UserDefaults.standard.string(forKey: "selectedTemplate")
                        .flatMap { $0.isEmpty ? nil : $0 }
                    let watermarked = WatermarkRenderer.apply(
                        to: img, location: loc, heading: hdg, labelText: label
                    )
                    _ = FileStorageManager.shared.save(image: watermarked, location: loc)
                } else {
                    capturedImage = img
                    capturedLocation = loc
                    capturedHeading = hdg
                    showEditor = true
                }
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let img = capturedImage {
                PhotoEditorView(image: img, location: capturedLocation, heading: capturedHeading) { edited in
                    _ = FileStorageManager.shared.save(
                        image: edited,
                        location: capturedLocation
                    )
                    showEditor = false
                } onDiscard: {
                    showEditor = false
                }
            }
        }
        .fullScreenCover(isPresented: $showGallery) {
            GalleryView()
        }
        .fullScreenCover(isPresented: $showNotes) {
            NotesListView()
        }
        .fullScreenCover(isPresented: $showVaultLock) {
            VaultLockView {
                showVaultLock = false
                switch pendingDestination {
                case .gallery: showGallery = true
                case .notes: showNotes = true
                case .none: break
                }
                pendingDestination = nil
            } onCancel: {
                showVaultLock = false
                pendingDestination = nil
            }
        }
        .fullScreenCover(isPresented: $showMap) {
            PhotoMapView()
        }
    }

    private enum VaultDestination {
        case gallery
        case notes
    }

    private func requestAccess(to destination: VaultDestination) {
        let store = SettingsStore.shared
        if store.vaultCodeEnabled && !store.vaultCode.isEmpty {
            pendingDestination = destination
            showVaultLock = true
        } else {
            switch destination {
            case .gallery: showGallery = true
            case .notes: showNotes = true
            }
        }
    }
}

struct VaultActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(width: 130, height: 100)
            .background(Color(hex: "#2C2C2E"))
            .cornerRadius(16)
        }
    }
}
