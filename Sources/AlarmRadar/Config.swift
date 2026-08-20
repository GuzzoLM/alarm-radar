import Foundation

final class Config {
    static let shared = Config()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let grafanaURL = "grafanaURL"
        static let pollInterval = "pollInterval"
        static let alertFilter = "alertFilter"
        static let mutedAlertIDs = "mutedAlertIDs"
        static let seenAlertIDs = "seenAlertIDs"
    }

    var grafanaURL: URL? {
        get {
            guard let value = defaults.string(forKey: Key.grafanaURL), !value.isEmpty else { return nil }
            return URL(string: value)
        }
        set { defaults.set(newValue?.absoluteString, forKey: Key.grafanaURL) }
    }

    var pollInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Key.pollInterval)
            return value > 0 ? value : 60
        }
        set { defaults.set(max(15, newValue), forKey: Key.pollInterval) }
    }

    var alertFilter: String {
        get { defaults.string(forKey: Key.alertFilter) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.alertFilter) }
    }

    var mutedAlertIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.mutedAlertIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.mutedAlertIDs) }
    }

    var seenAlertIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.seenAlertIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.seenAlertIDs) }
    }

    func toggleMuted(_ id: String) {
        var ids = mutedAlertIDs
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        mutedAlertIDs = ids
    }

    func markSeen(_ id: String) {
        var ids = seenAlertIDs
        ids.insert(id)
        seenAlertIDs = ids
    }
}
