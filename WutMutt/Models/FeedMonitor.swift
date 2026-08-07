import Network
import Foundation

/// Watches the network path so the off-air cards' retry can skip the whole
/// analyzing performance when the device is clearly offline — the viewer
/// shouldn't sit through eight seconds of teaser theater to be told what the
/// radio already knows.
///
/// Fail-open by design: only a definite `.unsatisfied` path counts as offline.
/// Anything ambiguous lets the retry run for real — the precheck exists to
/// skip theater, never to block an attempt that might succeed, and certainly
/// never to invent a verdict.
final class FeedMonitor {
    static let shared = FeedMonitor()

    private let monitor = NWPathMonitor()
    /// Written on the monitor's queue, read from the main thread — a torn read
    /// here costs one unnecessary retry attempt, not correctness.
    private(set) var isClearlyOffline = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isClearlyOffline = (path.status == .unsatisfied)
        }
        monitor.start(queue: DispatchQueue(label: "wm-feed-monitor"))
    }

    /// The answer the precheck acts on, with a DEBUG override so the offline
    /// beat can be comped in the simulator (whose network is the Mac's):
    /// `SIMCTL_CHILD_WM_FORCE_OFFLINE=1 simctl launch …`
    var retryWouldFail: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WM_FORCE_OFFLINE"] != nil { return true }
        #endif
        return isClearlyOffline
    }
}
