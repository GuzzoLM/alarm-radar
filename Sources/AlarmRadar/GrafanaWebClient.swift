import Foundation

@MainActor
final class GrafanaWebClient {
    private let session: GrafanaSession

    init(session: GrafanaSession) {
        self.session = session
    }

    func testConnection() async throws {
        _ = try await session.fetch(path: "/api/user")
    }

    func fetchAlerts(baseURL: URL) async throws -> [MonitoredAlert] {
        // Runtime state is currently exposed by Grafana's Prometheus-compatible
        // rules endpoint. Prefer the v13 resource API when its status payload is
        // available, while retaining the runtime endpoint for this POC.
        let paths = [
            "/api/prometheus/grafana/api/v1/rules?type=alert",
            "/apis/rules.alerting.grafana.app/v0alpha1/namespaces/default/alertrules",
        ]
        var errors: [String] = []

        for path in paths {
            do {
                let data = try await session.fetch(path: path)
                let alerts = try AlertParser.parse(data: data, baseURL: baseURL)
                let filter = try AlertFilter(Config.shared.alertFilter)
                return alerts.filter(filter.matches)
            } catch RadarError.notAuthenticated {
                throw RadarError.notAuthenticated
            } catch {
                errors.append("\(path): \(error.localizedDescription)")
            }
        }
        throw RadarError.apiUnavailable(errors)
    }
}
