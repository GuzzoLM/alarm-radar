import Foundation
import Testing
@testable import AlarmRadar

struct AlertParserTests {
    @Test func parsesPrometheusRuntimeAlerts() throws {
        let json = #"""
        {
          "status": "success",
          "data": {
            "groups": [{
              "name": "api",
              "file": "Production",
              "rules": [{
                "name": "High error rate",
                "state": "firing",
                "health": "ok",
                "alerts": [{
                  "labels": {"service": "checkout", "severity": "critical"},
                  "annotations": {"summary": "Too many 5xx responses"},
                  "state": "firing",
                  "activeAt": "2026-08-19T12:00:00Z",
                  "value": "0.42",
                  "generatorURL": "/alerting/grafana/abc/view"
                }]
              }]
            }]
          }
        }
        """#

        let alerts = try AlertParser.parse(data: Data(json.utf8), baseURL: URL(string: "https://grafana.example.com")!)

        #expect(alerts.count == 1)
        #expect(alerts[0].ruleName == "High error rate")
        #expect(alerts[0].state == .firing)
        #expect(alerts[0].severity == "critical")
        #expect(alerts[0].labels["grafana_folder"] == "Production")
        #expect(alerts[0].generatorURL?.absoluteString == "https://grafana.example.com/alerting/grafana/abc/view")
    }

    @Test func healthErrorOverridesNormalState() throws {
        let json = #"""
        {"data":{"groups":[{"name":"infra","rules":[{
          "name":"Datasource failure", "state":"inactive", "health":"error", "alerts":[]
        }]}]}}
        """#

        let alerts = try AlertParser.parse(data: Data(json.utf8), baseURL: URL(string: "https://grafana.example.com")!)

        #expect(alerts.count == 1)
        #expect(alerts[0].state == .error)
    }
}
