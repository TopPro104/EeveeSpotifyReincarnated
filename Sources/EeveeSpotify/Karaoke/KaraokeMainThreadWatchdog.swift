import Foundation

/// Diagnostic: logs whenever the main thread doesn't answer a ping for
/// more than `threshold`, so UI lag (e.g. Spotify's play/pause button
/// updating late) can be traced to what was running at the time instead
/// of guessed at. Pings from a background thread every 100ms; costs one
/// empty main-queue block per ping.
final class KaraokeMainThreadWatchdog {
    static let shared = KaraokeMainThreadWatchdog()

    private let threshold: TimeInterval = 0.25
    private let queue = DispatchQueue(label: "com.eevee.karaoke.watchdog", qos: .utility)
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        ping()
    }

    private func ping() {
        let sent = DispatchTime.now()
        DispatchQueue.main.async {
            let blocked = Double(DispatchTime.now().uptimeNanoseconds - sent.uptimeNanoseconds) / 1_000_000_000
            if blocked > self.threshold {
                let overlay = KaraokeOverlayPresenter.isPresented ? "overlay open" : "overlay closed"
                writeDebugLog("[Stall] main thread blocked \(Int(blocked * 1000))ms (\(overlay), nativeRichSync=\(UserDefaults.nativeRichSync))")
            }
        }
        queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.ping()
        }
    }
}
