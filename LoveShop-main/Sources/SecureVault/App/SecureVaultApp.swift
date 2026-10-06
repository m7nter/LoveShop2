import SwiftUI

@main
struct SecureVaultApp: App {
    @State private var isUnlocked = false
    @State private var backgroundTime: Date? = nil
    @State private var inactivityTimer: Timer? = nil
    @Environment(\.scenePhase) var scenePhase

    init() {
        setupCrashLogging()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                isUnlocked: $isUnlocked,
                onStartTimer: startTimer,
                onStopTimer: stopTimer
            )
            .onOpenURL { url in
                guard url.scheme == "securevault",
                      url.host == "camera",
                      SettingsStore.shared.actionButtonCameraEnabled else { return }
                isUnlocked = true
                startTimer()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .openCameraFromURL, object: nil)
                }
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background, .inactive:
                    backgroundTime = Date()
                    stopTimer()
                    if SettingsStore.shared.lockOnBackground && isUnlocked {
                        isUnlocked = false
                    }
                case .active:
                    if let bg = backgroundTime, !SettingsStore.shared.lockOnBackground {
                        let elapsed = Date().timeIntervalSince(bg)
                        let timeout = SettingsStore.shared.autoLockTimeout
                        if timeout > 0 && elapsed >= Double(timeout) && isUnlocked {
                            isUnlocked = false
                        } else if isUnlocked {
                            startTimer()
                        }
                    }
                    backgroundTime = nil
                default:
                    break
                }
            }
        }
    }

    private func startTimer() {
        stopTimer()
        let timeout = SettingsStore.shared.autoLockTimeout
        guard timeout > 0, !SettingsStore.shared.lockOnBackground else { return }
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: Double(timeout),
                                               repeats: false) { _ in
            DispatchQueue.main.async {
                isUnlocked = false
            }
        }
    }

    private func stopTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    private func setupCrashLogging() {
        NSSetUncaughtExceptionHandler { exception in
            let log = """
            CRASH: \(exception.name.rawValue)
            Reason: \(exception.reason ?? "unknown")
            Stack: \(exception.callStackSymbols.joined(separator: "\n"))
            """
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
            if let cachePath = paths.first {
                let logPath = cachePath + "/crash.log"
                try? log.write(toFile: logPath, atomically: true, encoding: .utf8)
            }
        }
    }
}

struct RootView: View {
    @Binding var isUnlocked: Bool
    let onStartTimer: () -> Void
    let onStopTimer: () -> Void

    var body: some View {
        if isUnlocked {
            VaultView(onLock: {
                isUnlocked = false
                onStopTimer()
            })
        } else {
            CalculatorView(onUnlock: {
                isUnlocked = true
                onStartTimer()
            })
        }
    }
}
