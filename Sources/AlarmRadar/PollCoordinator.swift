import Foundation

@MainActor
final class PollCoordinator {
    private let client: GrafanaWebClient
    private var timer: Timer?
    private var isRefreshing = false

    var didStart: (() -> Void)?
    var didUpdate: ((PollSnapshot) -> Void)?
    var didFail: ((Error) -> Void)?

    init(client: GrafanaWebClient) {
        self.client = client
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: Config.shared.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func restart() {
        start()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        guard let baseURL = Config.shared.grafanaURL else {
            didFail?(RadarError.notConfigured)
            return
        }
        isRefreshing = true
        didStart?()
        defer { isRefreshing = false }
        do {
            let alerts = try await client.fetchAlerts(baseURL: baseURL)
            didUpdate?(PollSnapshot(alerts: alerts, fetchedAt: Date()))
        } catch {
            didFail?(error)
        }
    }
}
