import Foundation

enum AlertParser {
    static func parse(data: Data, baseURL: URL) throws -> [MonitoredAlert] {
        let root = try JSONSerialization.jsonObject(with: data)
        if let dictionary = root as? [String: Any],
           let data = dictionary["data"] as? [String: Any],
           let groups = data["groups"] as? [[String: Any]] {
            return parsePrometheusGroups(groups, baseURL: baseURL)
        }

        if let dictionary = root as? [String: Any],
           let items = dictionary["items"] as? [[String: Any]] {
            return parseResourceItems(items, baseURL: baseURL)
        }

        throw RadarError.invalidResponse
    }

    private static func parsePrometheusGroups(_ groups: [[String: Any]], baseURL: URL) -> [MonitoredAlert] {
        var result: [MonitoredAlert] = []
        for group in groups {
            let folder = group["file"] as? String ?? group["name"] as? String
            for rule in group["rules"] as? [[String: Any]] ?? [] {
                let ruleName = rule["name"] as? String ?? "Unnamed alert"
                let health = rule["health"] as? String
                let ruleState = state(rule["state"] as? String, health: health)
                let ruleURL = url(rule["url"], baseURL: baseURL)
                let instances = rule["alerts"] as? [[String: Any]] ?? []

                if instances.isEmpty {
                    if ruleState != .normal {
                        let labels = withFolder(dictionary(rule["labels"]), folder: folder)
                        result.append(makeAlert(ruleName: ruleName, state: ruleState, health: health,
                                                labels: labels, annotations: dictionary(rule["annotations"]),
                                                activeAt: nil, value: nil, url: ruleURL))
                    }
                    continue
                }

                for instance in instances {
                    let labels = withFolder(dictionary(instance["labels"]), folder: folder)
                    result.append(makeAlert(
                        ruleName: ruleName,
                        state: state(instance["state"] as? String, health: health),
                        health: health,
                        labels: labels,
                        annotations: dictionary(instance["annotations"]),
                        activeAt: date(instance["activeAt"] as? String),
                        value: instance["value"] as? String,
                        url: url(instance["generatorURL"] ?? rule["url"], baseURL: baseURL)
                    ))
                }
            }
        }
        return deduplicated(result)
    }

    private static func parseResourceItems(_ items: [[String: Any]], baseURL: URL) -> [MonitoredAlert] {
        var result: [MonitoredAlert] = []
        for item in items {
            let metadata = item["metadata"] as? [String: Any] ?? [:]
            let spec = item["spec"] as? [String: Any] ?? [:]
            let status = item["status"] as? [String: Any] ?? [:]
            let name = spec["title"] as? String ?? metadata["name"] as? String ?? "Unnamed alert"
            let health = status["health"] as? String
            let instances = status["instances"] as? [[String: Any]] ?? status["alerts"] as? [[String: Any]] ?? []
            let baseLabels = dictionary(spec["labels"])

            if instances.isEmpty {
                let currentState = state(status["state"] as? String, health: health)
                if currentState != .normal {
                    result.append(makeAlert(ruleName: name, state: currentState, health: health,
                                            labels: baseLabels, annotations: dictionary(spec["annotations"]),
                                            activeAt: nil, value: nil, url: nil))
                }
            } else {
                for instance in instances {
                    result.append(makeAlert(
                        ruleName: name,
                        state: state(instance["state"] as? String, health: health),
                        health: health,
                        labels: baseLabels.merging(dictionary(instance["labels"])) { _, new in new },
                        annotations: dictionary(instance["annotations"]),
                        activeAt: date(instance["activeAt"] as? String),
                        value: instance["value"] as? String,
                        url: url(instance["generatorURL"], baseURL: baseURL)
                    ))
                }
            }
        }
        return deduplicated(result)
    }

    private static func makeAlert(ruleName: String, state: AlertState, health: String?, labels: [String: String], annotations: [String: String], activeAt: Date?, value: String?, url: URL?) -> MonitoredAlert {
        let identity = (["rule=\(ruleName)"] + labels.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }).joined(separator: "|")
        return MonitoredAlert(id: identity, ruleName: ruleName, state: state, health: health,
                              labels: labels, annotations: annotations, activeAt: activeAt,
                              value: value, generatorURL: url)
    }

    private static func state(_ raw: String?, health: String?) -> AlertState {
        let healthValue = health?.lowercased() ?? ""
        if healthValue == "error" || healthValue == "nodata" || healthValue == "no_data" { return .error }
        switch raw?.lowercased() {
        case "alerting", "firing", "active": return .firing
        case "pending": return .pending
        case "error", "nodata", "no_data": return .error
        default: return .normal
        }
    }

    private static func dictionary(_ value: Any?) -> [String: String] {
        guard let dictionary = value as? [String: Any] else { return [:] }
        return dictionary.reduce(into: [:]) { result, pair in result[pair.key] = String(describing: pair.value) }
    }

    private static func withFolder(_ labels: [String: String], folder: String?) -> [String: String] {
        guard let folder, !folder.isEmpty, labels["grafana_folder"] == nil else { return labels }
        var labels = labels
        labels["grafana_folder"] = folder
        return labels
    }

    private static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func url(_ value: Any?, baseURL: URL) -> URL? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return URL(string: string, relativeTo: baseURL)?.absoluteURL
    }

    private static func deduplicated(_ alerts: [MonitoredAlert]) -> [MonitoredAlert] {
        Array(Dictionary(alerts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
            .sorted { ($0.state.priority, $0.ruleName) < ($1.state.priority, $1.ruleName) }
    }
}
