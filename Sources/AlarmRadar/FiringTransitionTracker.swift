import Foundation

struct FiringTransitionTracker {
    private var previousFiringIDs: Set<String>?

    mutating func newlyFiringIDs(in alerts: [MonitoredAlert], excluding excludedIDs: Set<String> = []) -> Set<String> {
        let current = Set(
            alerts.lazy
                .filter { $0.state == .firing && !excludedIDs.contains($0.id) }
                .map(\.id)
        )
        defer { previousFiringIDs = current }

        // The first snapshot is a baseline, not a flood of new notifications.
        guard let previousFiringIDs else { return [] }
        return current.subtracting(previousFiringIDs)
    }

    mutating func reset() {
        previousFiringIDs = nil
    }
}
