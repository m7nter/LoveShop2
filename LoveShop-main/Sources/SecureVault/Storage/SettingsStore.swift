import SwiftUI

class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var avatarImage: UIImage? {
        didSet { saveAvatar() }
    }

    @Published var showCrosshair: Bool {
        didSet { UserDefaults.standard.set(showCrosshair, forKey: "showCrosshair") }
    }

    @Published var crosshairColor: String {
        didSet { UserDefaults.standard.set(crosshairColor, forKey: "crosshairColor") }
    }

    @Published var crosshairOnPhoto: Bool {
        didSet { UserDefaults.standard.set(crosshairOnPhoto, forKey: "crosshairOnPhoto") }
    }

    @Published var autoLockTimeout: Int {
        didSet { UserDefaults.standard.set(autoLockTimeout, forKey: "autoLockTimeout") }
    }

    @Published var lockOnBackground: Bool {
        didSet { UserDefaults.standard.set(lockOnBackground, forKey: "lockOnBackground") }
    }

    @Published var accuracyProtectionEnabled: Bool {
        didSet { UserDefaults.standard.set(accuracyProtectionEnabled, forKey: "accuracyProtectionEnabled") }
    }

    @Published var accuracyThreshold: Int {
        didSet { UserDefaults.standard.set(accuracyThreshold, forKey: "accuracyThreshold") }
    }

    @Published var distanceTrackingEnabled: Bool {
        didSet { UserDefaults.standard.set(distanceTrackingEnabled, forKey: "distanceTrackingEnabled") }
    }

    @Published var minDistanceThreshold: Int {
        didSet { UserDefaults.standard.set(minDistanceThreshold, forKey: "minDistanceThreshold") }
    }

    @Published var volumeButtonCaptureEnabled: Bool {
        didSet { UserDefaults.standard.set(volumeButtonCaptureEnabled, forKey: "volumeButtonCaptureEnabled") }
    }

    @Published var exportAsZip: Bool {
        didSet { UserDefaults.standard.set(exportAsZip, forKey: "exportAsZip") }
    }

    @Published var clusterMapPins: Bool {
        didSet { UserDefaults.standard.set(clusterMapPins, forKey: "clusterMapPins") }
    }

    @Published var actionButtonCameraEnabled: Bool {
        didSet { UserDefaults.standard.set(actionButtonCameraEnabled, forKey: "actionButtonCameraEnabled") }
    }

    private let avatarKey = "userAvatar"

    init() {
        showCrosshair = UserDefaults.standard.bool(forKey: "showCrosshair")
        crosshairColor = UserDefaults.standard.string(forKey: "crosshairColor") ?? "white"
        crosshairOnPhoto = UserDefaults.standard.bool(forKey: "crosshairOnPhoto")
        autoLockTimeout = UserDefaults.standard.integer(forKey: "autoLockTimeout")
        lockOnBackground = UserDefaults.standard.object(forKey: "lockOnBackground") as? Bool ?? true
        accuracyProtectionEnabled = UserDefaults.standard.bool(forKey: "accuracyProtectionEnabled")
        accuracyThreshold = UserDefaults.standard.object(forKey: "accuracyThreshold") as? Int ?? 20
        distanceTrackingEnabled = UserDefaults.standard.bool(forKey: "distanceTrackingEnabled")
        minDistanceThreshold = UserDefaults.standard.object(forKey: "minDistanceThreshold") as? Int ?? 10
        volumeButtonCaptureEnabled = UserDefaults.standard.bool(forKey: "volumeButtonCaptureEnabled")
        exportAsZip = UserDefaults.standard.object(forKey: "exportAsZip") as? Bool ?? true
        clusterMapPins = UserDefaults.standard.object(forKey: "clusterMapPins") as? Bool ?? true
        actionButtonCameraEnabled = UserDefaults.standard.bool(forKey: "actionButtonCameraEnabled")
        loadAvatar()
    }

    var mainCode: String {
        get { UserDefaults.standard.string(forKey: "mainCode") ?? "2026" }
        set { UserDefaults.standard.set(newValue, forKey: "mainCode") }
    }

    var vaultCode: String {
        get { UserDefaults.standard.string(forKey: "vaultCode") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "vaultCode") }
    }

    var kamikazeCode: String {
        get { UserDefaults.standard.string(forKey: "kamikazeCode") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "kamikazeCode") }
    }

    var vaultCodeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vaultCodeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vaultCodeEnabled") }
    }

    var kamikazeCodeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "kamikazeCodeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "kamikazeCodeEnabled") }
    }

    private func saveAvatar() {
        guard let img = avatarImage,
              let data = img.jpegData(compressionQuality: 0.8) else { return }
        UserDefaults.standard.set(data, forKey: avatarKey)
    }

    private func loadAvatar() {
        guard let data = UserDefaults.standard.data(forKey: avatarKey),
              let img = UIImage(data: data) else { return }
        avatarImage = img
    }
}
