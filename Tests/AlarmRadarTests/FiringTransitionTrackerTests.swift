import Testing
@testable import AlarmRadar

struct FiringTransitionTrackerTests {
    private func alert(_ id: String, state: AlertState) -> MonitoredAlert {
        MonitoredAlert(id: id, ruleName: id, state: state, health: nil, labels: [:], annotations: [:], activeAt: nil, value: nil, generatorURL: nil)
    }

    @Test func firstSnapshotIsSilentBaseline() {
        var tracker = FiringTransitionTracker()
        #expect(tracker.newlyFiringIDs(in: [alert("one", state: .firing)]).isEmpty)
    }

    @Test func detectsNewAndTransitionedFiringAlerts() {
        var tracker = FiringTransitionTracker()
        _ = tracker.newlyFiringIDs(in: [alert("one", state: .firing), alert("two", state: .pending)])

        let newIDs = tracker.newlyFiringIDs(in: [alert("one", state: .firing), alert("two", state: .firing), alert("three", state: .firing)])

        #expect(newIDs == Set(["two", "three"]))
    }

    @Test func ignoresMutedAlertsAndNotifiesAfterRefire() {
        var tracker = FiringTransitionTracker()
        _ = tracker.newlyFiringIDs(in: [])
        #expect(tracker.newlyFiringIDs(in: [alert("muted", state: .firing)], excluding: ["muted"]).isEmpty)
        #expect(tracker.newlyFiringIDs(in: [alert("one", state: .firing)]) == ["one"])
        _ = tracker.newlyFiringIDs(in: [alert("one", state: .normal)])
        #expect(tracker.newlyFiringIDs(in: [alert("one", state: .firing)]) == ["one"])
    }

    @Test func resetMakesNextSnapshotSilent() {
        var tracker = FiringTransitionTracker()
        _ = tracker.newlyFiringIDs(in: [])
        tracker.reset()
        #expect(tracker.newlyFiringIDs(in: [alert("one", state: .firing)]).isEmpty)
    }
}
