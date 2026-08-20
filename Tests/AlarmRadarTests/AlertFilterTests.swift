import Foundation
import Testing
@testable import AlarmRadar

struct AlertFilterTests {
    private let alert = MonitoredAlert(
        id: "checkout",
        ruleName: "Checkout error rate",
        state: .firing,
        health: "ok",
        labels: ["team": "payments", "environment": "production", "severity": "critical"],
        annotations: [:],
        activeAt: nil,
        value: nil,
        generatorURL: nil
    )

    @Test func emptyFilterMatchesEverything() throws {
        #expect(try AlertFilter("").matches(alert))
    }

    @Test func matchesLabelSelectors() throws {
        #expect(try AlertFilter(#"{team="payments", severity=~"critical|warning"}"#).matches(alert))
        #expect(try !AlertFilter(#"{team="platform"}"#).matches(alert))
        #expect(try AlertFilter(#"{team!="platform", environment!~"staging|dev"}"#).matches(alert))
    }

    @Test func freeTextSearchesNamesAndLabels() throws {
        #expect(try AlertFilter("checkout").matches(alert))
        #expect(try AlertFilter("payments").matches(alert))
        #expect(try !AlertFilter("inventory").matches(alert))
    }

    @Test func invalidMatcherIsRejected() {
        #expect(throws: RadarError.self) {
            try AlertFilter(#"{team=payments}"#)
        }
    }
}
