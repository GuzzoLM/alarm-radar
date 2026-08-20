import Foundation

enum AlertState: String, CaseIterable {
    case firing = "Firing"
    case pending = "Pending"
    case error = "Error / No Data"
    case normal = "Normal"

    var priority: Int {
        switch self {
        case .firing: return 0
        case .error: return 1
        case .pending: return 2
        case .normal: return 3
        }
    }
}

struct MonitoredAlert: Identifiable, Equatable {
    let id: String
    let ruleName: String
    let state: AlertState
    let health: String?
    let labels: [String: String]
    let annotations: [String: String]
    let activeAt: Date?
    let value: String?
    let generatorURL: URL?

    var severity: String? { labels["severity"] }
    var summary: String? { annotations["summary"] ?? annotations["description"] }

    var detail: String {
        let ignored = Set(["alertname", "grafana_folder"])
        let parts = labels
            .filter { !ignored.contains($0.key) }
            .sorted { $0.key < $1.key }
            .prefix(3)
            .map { "\($0.key)=\($0.value)" }
        return parts.joined(separator: "  ")
    }
}

struct PollSnapshot {
    let alerts: [MonitoredAlert]
    let fetchedAt: Date
}

enum RadarError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case invalidResponse
    case http(Int, String)
    case apiUnavailable([String])
    case invalidFilter(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set a Grafana URL in Settings."
        case .notAuthenticated: return "Sign in to Grafana to continue."
        case .invalidResponse: return "Grafana returned an invalid response."
        case let .http(status, _): return "Grafana returned HTTP \(status)."
        case let .apiUnavailable(errors): return "No supported alert endpoint responded (\(errors.joined(separator: ", ")))."
        case let .invalidFilter(message): return "Invalid alert filter: \(message)."
        }
    }
}
